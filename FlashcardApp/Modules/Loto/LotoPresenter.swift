import Foundation
import RxSwift

// MARK: View state

struct LotoViewState: Equatable {
    enum Phase: Equatable {
        case loading
        case failed(String)
        /// The server has no Loto article at the moment.
        case empty
        case ready
    }

    let phase: Phase
    /// The games that have a draw to show, in tab order.
    let games: [LotoGame]
    let selected: LotoGame?
    /// The next draw of the selected game.
    let draw: LotoDraw?
}

protocol LotoViewInterface: AnyObject {
    func render(_ state: LotoViewState)
    /// Ends the pull-to-refresh spinner.
    func endRefreshing()
}

protocol LotoPresenterInterface: AnyObject {
    func viewDidLoad()
    func select(_ game: LotoGame)
    func refresh()
    func retry()
    func openOfficialSite()
    /// What the "copy" button puts on the pasteboard for a set of the shown draw.
    func copyText(for set: LotoSet) -> String?
    /// The weight of every number of the shown game at this randomness (0…1), for the lab's chart.
    func labWeights(randomness: Double) -> [Double]
    /// One spin of the chaos system: the factors the view collected, plus the draw and the weather the presenter knows.
    /// nil when no draw is shown.
    func spin(randomness: Double, local: [LotoChaosFactor]) -> LotoChaosResult?
    /// What the "copy" button puts on the pasteboard for a lab set.
    func labCopyText(for numbers: [Int]) -> String?
}

// MARK: Presenter

final class LotoPresenter: LotoPresenterInterface {
    private let interactor: LotoInteractorInterface
    private let wireframe: LotoWireframeInterface
    private let scheduler: ImmediateSchedulerType
    private var disposeBag = DisposeBag()
    private var overview: LotoOverview?
    private var selected: LotoGame?
    private var phase: LotoViewState.Phase = .loading
    private let environment: LotoEnvironmentInteractorInterface
    private var weather: [LotoChaosFactor] = []
    weak var view: LotoViewInterface?

    init(interactor: LotoInteractorInterface, wireframe: LotoWireframeInterface, scheduler: ImmediateSchedulerType = MainScheduler.instance,
         environment: LotoEnvironmentInteractorInterface = LotoEnvironmentInteractor()) {
        self.environment = environment
        self.interactor = interactor
        self.wireframe = wireframe
        self.scheduler = scheduler
    }

    func viewDidLoad() { load(showSpinner: true) }

    func retry() { load(showSpinner: true) }

    func refresh() { load(showSpinner: false) }

    func select(_ game: LotoGame) {
        guard let overview, overview.draws.contains(where: { $0.game == game }) else { return }
        selected = game
        publish()
    }

    func openOfficialSite() {
        guard let url = currentDraw?.officialURL else { return }
        wireframe.showOfficialSite(url)
    }

    func copyText(for set: LotoSet) -> String? {
        guard let draw = currentDraw, draw.sets.contains(set) else { return nil }
        return Self.copyText(draw: draw, set: set)
    }

    func labWeights(randomness: Double) -> [Double] {
        guard let draw = currentDraw else { return [] }
        return LotoRandomizer.weights(game: draw.game, signals: draw.signals, randomness: randomness)
    }

    func spin(randomness: Double, local: [LotoChaosFactor]) -> LotoChaosResult? {
        guard let draw = currentDraw else { return nil }
        var factors = local + weather
        let number = draw.drawNumber.map(String.init) ?? "-"
        factors.append(LotoChaosFactor(kind: .draw, key: "draw", value: "game=\(draw.game.rawValue);slug=\(draw.slug);number=\(number)",
                                       display: "\(draw.game.title) · \(draw.day.formatted(.short))" + (draw.drawNumber.map { " · #\($0)" } ?? "")))
        return LotoChaosEngine.run(factors: factors, game: draw.game, signals: draw.signals, randomness: randomness)
    }

    func labCopyText(for numbers: [Int]) -> String? {
        guard let draw = currentDraw, numbers.count == draw.game.pickCount else { return nil }
        return "\(draw.game.title) · \(draw.day.formatted(.short)): " + numbers.map { String(format: "%02d", $0) }.joined(separator: " ")
    }

    static func copyText(draw: LotoDraw, set: LotoSet) -> String {
        var numbers = set.main.map { String(format: "%02d", $0) }.joined(separator: " ")
        if !set.bonus.isEmpty { numbers += " + " + set.bonus.map { String(format: "%02d", $0) }.joined(separator: " ") }
        return "\(draw.game.title) · \(draw.day.formatted(.short)): \(numbers)"
    }

    // MARK: Private

    private var currentDraw: LotoDraw? {
        overview?.draws.first { $0.game == selected }
    }

    private func load(showSpinner: Bool) {
        if showSpinner || overview == nil {
            phase = .loading
            publish()
        }
        disposeBag = DisposeBag()
        // Best effort and silent: without weather the chaos system simply has fewer factors.
        environment.weatherFactors().observe(on: scheduler).subscribe(onSuccess: { [weak self] factors in self?.weather = factors })
            .disposed(by: disposeBag)
        interactor.load().observe(on: scheduler).subscribe(onSuccess: { [weak self] overview in
            guard let self else { return }
            self.overview = overview
            if !overview.draws.contains(where: { $0.game == self.selected }) { self.selected = overview.draws.first?.game }
            self.phase = overview.draws.isEmpty ? .empty : .ready
            self.view?.endRefreshing()
            self.publish()
        }, onFailure: { [weak self] error in
            guard let self else { return }
            self.view?.endRefreshing()
            // A refresh that fails keeps the draws that are already on screen.
            if self.overview != nil, !showSpinner { return }
            self.overview = nil
            self.phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            self.publish()
        }).disposed(by: disposeBag)
    }

    private func publish() {
        let games = overview?.draws.map(\.game) ?? []
        view?.render(LotoViewState(phase: phase, games: games, selected: selected, draw: phase == .ready ? currentDraw : nil))
    }
}

// MARK: Countdown

/// Time left until a draw, split for the four tiles of the countdown.
struct LotoCountdown: Equatable {
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int

    /// nil once the draw time has come.
    static func until(_ target: Date, now: Date) -> LotoCountdown? {
        let total = Int(target.timeIntervalSince(now).rounded(.down))
        guard total > 0 else { return nil }
        return LotoCountdown(days: total / 86_400, hours: total % 86_400 / 3_600, minutes: total % 3_600 / 60, seconds: total % 60)
    }
}
