import Foundation
import RxSwift

enum HomeContentKind: Int, CaseIterable {
    case vocabulary, kanji, grammar
    var title: String { ["Từ vựng", "Kanji", "Ngữ pháp"][rawValue] }
}

struct HomeCount: Equatable {
    let value: Int
    let label: String
}

struct HomeRow {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    /// Level rows: short code shown as the row mark ("J5") and the name without that prefix.
    var mark: String?
    var name: String?
    var summary: String?
    var counts: [HomeCount] = []
    /// Content rows: reading and Vietnamese meaning kept apart so each can use its own text role.
    var reading: String?
    var meaning: String?
}

protocol HomePresenterInterface: AnyObject {
    var rows: [HomeRow] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var canLoadMore: Bool { get }
    var isContent: Bool { get }
    var kind: HomeContentKind { get }
    /// Backend item count of the selected kind for the open level.
    var kindTotal: Int? { get }
    var onChange: (() -> Void)? { get set }
    func viewDidLoad()
    func selectRow(at index: Int)
    func selectKind(_ kind: HomeContentKind)
    func loadMore()
    func retry()
    func cancelLoading()
}

final class HomePresenter: HomePresenterInterface {
    private let interactor: HomeInteractorInterface
    private let wireframe: HomeWireframeInterface
    private let level: BJTLevelDTO?
    private let request = SerialDisposable()
    private var levels: [BJTLevelDTO] = []
    private var offset = 0
    private var hasLoaded = false

    private(set) var rows: [HomeRow] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var canLoadMore = false
    private(set) var kind: HomeContentKind = .vocabulary
    var isContent: Bool { level != nil }
    var kindTotal: Int? {
        guard let level else { return nil }
        switch kind {
        case .vocabulary: return level.vocabCount
        case .kanji: return level.kanjiCount
        case .grammar: return level.grammarCount
        }
    }
    var onChange: (() -> Void)?

    init(interactor: HomeInteractorInterface, wireframe: HomeWireframeInterface, level: BJTLevelDTO? = nil) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.level = level
    }

    deinit { request.dispose() }

    func viewDidLoad() {
        guard !hasLoaded, !isLoading, errorMessage == nil else { return }
        load()
    }

    func selectRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        if level == nil {
            guard levels.indices.contains(index) else { return }
            wireframe.showLevel(levels[index])
        } else {
            let row = rows[index]
            wireframe.showMeaning(title: row.title,
                                  message: row.detail.isEmpty ? "Chưa có nghĩa tiếng Việt." : row.detail)
        }
    }

    func selectKind(_ kind: HomeContentKind) {
        guard isContent, kind != self.kind else { return }
        cancelLoading()
        self.kind = kind
        rows = []
        offset = 0
        hasLoaded = false
        canLoadMore = false
        load()
    }

    func loadMore() {
        guard canLoadMore, !isLoading, errorMessage == nil else { return }
        load()
    }

    func retry() {
        guard !isLoading else { return }
        load()
    }

    func cancelLoading() {
        request.disposable = Disposables.create()
        isLoading = false
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        onChange?()
        if let level {
            request.disposable = interactor.content(code: level.code, kind: kind, offset: offset)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] items in
                    guard let self else { return }
                    self.rows = self.rows + items
                    self.offset += items.count
                    self.canLoadMore = items.count == 30
                    self.hasLoaded = true
                    self.finishLoading()
                }, onFailure: { [weak self] _ in self?.failedLoading() })
        } else {
            request.disposable = interactor.listLevels()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] levels in
                    guard let self else { return }
                    self.levels = levels
                    self.rows = levels.map(Self.levelRow)
                    self.hasLoaded = true
                    self.finishLoading()
                }, onFailure: { [weak self] _ in self?.failedLoading() })
        }
    }

    static func levelRow(_ level: BJTLevelDTO) -> HomeRow {
        let counts = [HomeCount(value: level.vocabCount, label: "từ vựng"),
                      HomeCount(value: level.kanjiCount, label: "kanji"),
                      HomeCount(value: level.grammarCount, label: "ngữ pháp")]
        // A level without any item (e.g. J1+ today) states that instead of printing three zeros.
        let hasContent = counts.contains { $0.value > 0 }
        return HomeRow(id: level.code, title: level.nameVi,
                       subtitle: "\(level.descriptionVi)\nTừ vựng: \(level.vocabCount) · Kanji: \(level.kanjiCount) · Ngữ pháp: \(level.grammarCount)",
                       detail: level.descriptionVi,
                       mark: level.code, name: displayName(level), summary: level.descriptionVi,
                       counts: hasContent ? counts : [])
    }

    /// The backend sends "J5 — Sơ cấp"; the code is shown separately as the row mark.
    static func displayName(_ level: BJTLevelDTO) -> String {
        for separator in [" — ", " – ", " - "] where level.nameVi.hasPrefix(level.code + separator) {
            return String(level.nameVi.dropFirst(level.code.count + separator.count))
        }
        return level.nameVi
    }

    private func failedLoading() {
        errorMessage = "Không thể tải dữ liệu. Kiểm tra kết nối và thử lại."
        finishLoading()
    }

    private func finishLoading() {
        isLoading = false
        onChange?()
    }
}
