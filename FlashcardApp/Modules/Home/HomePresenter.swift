import Foundation
import RxSwift

enum HomeContentKind: Int, CaseIterable {
    case vocabulary, kanji, grammar
    var title: String {
        switch self {
        case .vocabulary: return NSLocalizedString("Vocabulary", comment: "")
        case .kanji: return NSLocalizedString("Kanji", comment: "")
        case .grammar: return NSLocalizedString("Grammar", comment: "")
        }
    }

    /// Unit written after a count: "574 words", "79 kanji", "194 grammar".
    var unit: String {
        switch self {
        case .vocabulary: return NSLocalizedString("vocabulary words", comment: "")
        case .kanji: return NSLocalizedString("kanji characters", comment: "")
        case .grammar: return NSLocalizedString("grammar points", comment: "")
        }
    }
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
    /// Kanji numeral of the JLPT level (五 for J5); nil when the code is not a known level.
    var numeral: String?
    var name: String?
    var summary: String?
    var counts: [HomeCount] = []
    /// Content rows: reading and Vietnamese meaning kept apart so each can use its own text role.
    var reading: String?
    var meaning: String?
    /// A single kanji: shown as a large glyph beside its meaning and readings.
    var isGlyph = false
    /// Structured fields preserved from the level DTO for the pushed entry detail screen.
    var onyomi: String? = nil
    var kunyomi: String? = nil
    var explanations: [String] = []
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
    /// Level list only: index of the level shown as the primary entry point (first with content).
    var featuredIndex: Int? { get }
    var onChange: (() -> Void)? { get set }
    func viewDidLoad()
    func selectRow(at index: Int)
    /// Level list only: opens the level directly on vocabulary, kanji or grammar.
    func selectRow(at index: Int, kind: HomeContentKind)
    func selectKind(_ kind: HomeContentKind)
    func loadMore()
    func retry()
    func cancelLoading()
    /// Level screen only: whether the level has structured lessons to open.
    var canShowLessons: Bool { get }
    func showLessons()
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
    private(set) var kind: HomeContentKind
    var featuredIndex: Int? {
        guard !isContent else { return nil }
        return rows.firstIndex { !$0.counts.isEmpty }
    }
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
    var canShowLessons: Bool {
        guard let level else { return false }
        return BJTLessonAPI.levelCodes.contains(level.code)
    }

    func showLessons() {
        guard canShowLessons, let level else { return }
        wireframe.showLessons(level: level)
    }

    init(interactor: HomeInteractorInterface, wireframe: HomeWireframeInterface, level: BJTLevelDTO? = nil,
         kind: HomeContentKind = .vocabulary) {
        self.kind = kind
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
        selectRow(at: index, kind: .vocabulary)
    }

    func selectRow(at index: Int, kind: HomeContentKind) {
        guard rows.indices.contains(index) else { return }
        if level == nil {
            guard levels.indices.contains(index) else { return }
            wireframe.showLevel(levels[index], kind: kind)
        } else if let level {
            let row = rows[index]
            let fallbackExplanations: [String]
            if row.explanations.isEmpty, row.meaning == nil, !row.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fallbackExplanations = [row.detail]
            } else {
                fallbackExplanations = row.explanations
            }
            let entry = LevelEntry(
                id: row.id,
                kind: self.kind,
                levelCode: level.code,
                levelName: level.localizedName(for: .current),
                title: row.title,
                reading: row.reading,
                onyomi: row.onyomi,
                kunyomi: row.kunyomi,
                shortMeaning: row.meaning,
                explanations: fallbackExplanations,
                hasLessons: canShowLessons
            )
            wireframe.showEntry(entry, level: level)
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
                    self.rows = levels.map { Self.levelRow($0) }
                    self.hasLoaded = true
                    self.finishLoading()
                }, onFailure: { [weak self] _ in self?.failedLoading() })
        }
    }

    static func levelRow(_ level: BJTLevelDTO, language: AppLanguage = .current) -> HomeRow {
        let counts = [HomeCount(value: level.vocabCount, label: HomeContentKind.vocabulary.unit),
                      HomeCount(value: level.kanjiCount, label: HomeContentKind.kanji.unit),
                      HomeCount(value: level.grammarCount, label: HomeContentKind.grammar.unit)]
        // A level without any item (e.g. J1+ today) states that instead of printing three zeros.
        let hasContent = counts.contains { $0.value > 0 }
        let summary = level.localizedDescription(for: language)
        let countsLine = counts
            .map { "\($0.value.formatted(.number.locale(language.locale))) \($0.label)" }
            .joined(separator: " · ")
        return HomeRow(id: level.code, title: level.localizedName(for: language),
                       subtitle: "\(summary)\n\(countsLine)",
                       detail: summary,
                       mark: level.code, numeral: numerals[level.code], name: displayName(level, language: language),
                       summary: summary, counts: hasContent ? counts : [])
    }

    /// JLPT level → kanji numeral (N5 is 五). Unknown codes get none and keep the plain code mark.
    private static let numerals = ["J5": "五", "J4": "四", "J3": "三", "J2": "二", "J1": "一", "J1+": "一+"]

    /// The backend sends "J5 — Lower beginner"; the code is shown separately as the row mark.
    static func displayName(_ level: BJTLevelDTO, language: AppLanguage = .current) -> String {
        let full = level.localizedName(for: language)
        for separator in [" — ", " – ", " - "] where full.hasPrefix(level.code + separator) {
            return String(full.dropFirst(level.code.count + separator.count))
        }
        return full
    }

    private func failedLoading() {
        errorMessage = NSLocalizedString("Couldn't load data. Check your connection and try again.", comment: "")
        finishLoading()
    }

    private func finishLoading() {
        isLoading = false
        onChange?()
    }
}
