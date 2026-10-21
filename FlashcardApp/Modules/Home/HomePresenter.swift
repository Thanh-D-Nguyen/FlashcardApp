import Foundation
import RxSwift

enum HomeContentKind: Int, CaseIterable {
    case vocabulary, kanji, grammar
    var title: String { ["Từ vựng", "Kanji", "Ngữ pháp"][rawValue] }
}

struct HomeRow {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
}

protocol HomePresenterInterface: AnyObject {
    var rows: [HomeRow] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var canLoadMore: Bool { get }
    var isContent: Bool { get }
    var kind: HomeContentKind { get }
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
                    self.rows = levels.map { level in
                        HomeRow(id: level.code, title: level.nameVi,
                                subtitle: "\(level.descriptionVi)\nTừ vựng: \(level.vocabCount) · Kanji: \(level.kanjiCount) · Ngữ pháp: \(level.grammarCount)",
                                detail: level.descriptionVi)
                    }
                    self.hasLoaded = true
                    self.finishLoading()
                }, onFailure: { [weak self] _ in self?.failedLoading() })
        }
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
