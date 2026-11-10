import Foundation
import RxSwift

/// The next Loto draw, for the hub's countdown.
struct DiscoverNextDraw: Equatable {
    let game: LotoGame
    let instant: Date
}

/// One word of today's Magazine, behind the sealed card. Both texts are the server's.
struct DiscoverFind: Equatable {
    let word: String
    let articleJapanese: String
}

protocol DiscoverViewInterface: AnyObject {
    func showNextDraw(_ draw: DiscoverNextDraw?)
    func showFind(_ find: DiscoverFind?)
}

protocol DiscoverPresenterInterface: AnyObject {
    var features: [DiscoverFeature] { get }
    func viewDidLoad()
    func select(_ feature: DiscoverFeature)
}

final class DiscoverPresenter: DiscoverPresenterInterface {
    private let wireframe: DiscoverWireframeInterface
    private let loto: LotoInteractorInterface
    private let magazine: MagazineInteractorInterface
    private let scheduler: ImmediateSchedulerType
    private let now: () -> Date
    private let disposeBag = DisposeBag()
    let features: [DiscoverFeature]
    weak var view: DiscoverViewInterface?

    init(wireframe: DiscoverWireframeInterface, features: [DiscoverFeature] = DiscoverFeature.available,
         loto: LotoInteractorInterface = LotoInteractor(), magazine: MagazineInteractorInterface = MagazineInteractor(),
         scheduler: ImmediateSchedulerType = MainScheduler.instance, now: @escaping () -> Date = Date.init) {
        self.wireframe = wireframe
        self.features = features
        self.loto = loto
        self.magazine = magazine
        self.scheduler = scheduler
        self.now = now
    }

    /// Both extras are best effort: when the server cannot be reached the hub is simply the plain list of features.
    func viewDidLoad() {
        if features.contains(.loto) {
            loto.load().observe(on: scheduler).subscribe(onSuccess: { [weak self] overview in
                guard let self else { return }
                self.view?.showNextDraw(Self.nextDraw(in: overview, now: self.now()))
            }).disposed(by: disposeBag)
        }
        if features.contains(.magazine) {
            magazine.loadPage(kind: nil, page: 1).observe(on: scheduler).subscribe(onSuccess: { [weak self] page in
                guard let self else { return }
                self.view?.showFind(Self.find(in: page, now: self.now()))
            }).disposed(by: disposeBag)
        }
    }

    func select(_ feature: DiscoverFeature) {
        guard features.contains(feature) else { return }
        wireframe.show(feature)
    }

    /// The draw that comes first and has not happened yet.
    static func nextDraw(in overview: LotoOverview, now: Date) -> DiscoverNextDraw? {
        overview.draws.compactMap { draw in draw.drawInstant.map { DiscoverNextDraw(game: draw.game, instant: $0) } }
            .filter { $0.instant > now }
            .min { $0.instant < $1.instant }
    }

    /// One headword of the latest articles. The pick depends only on the Japanese calendar day, so it is the same all day
    /// and changes at midnight in Japan.
    static func find(in page: MagazinePage, now: Date) -> DiscoverFind? {
        let candidates = page.items.flatMap { item in item.words.filter { !$0.isEmpty }.map { DiscoverFind(word: $0, articleJapanese: item.titleJapanese) } }
        guard !candidates.isEmpty else { return nil }
        let day = MagazineDay.today(now: now)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(day.year)-\(day.month)-\(day.day)".utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return candidates[Int(hash % UInt64(candidates.count))]
    }
}
