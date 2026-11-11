import Foundation
import RxSwift

struct LessonRow: Equatable {
    let id: String
    let slug: String
    let title: String
    let summary: String
    let unitType: String
    let minutes: Int?
    let activityCount: Int?
}

struct LessonWeekSection: Equatable {
    let weekNumber: Int
    let rows: [LessonRow]
}

enum LessonListState: Equatable {
    case idle, loading, loaded, empty
    case failed(String)
}

protocol LessonListPresenterInterface: AnyObject {
    var state: LessonListState { get }
    var sections: [LessonWeekSection] { get }
    var onChange: (() -> Void)? { get set }
    func viewDidLoad()
    func retry()
    func cancelLoading()
    func selectRow(section: Int, row: Int)
}

protocol LessonListWireframeInterface: AnyObject {
    func showLesson(slug: String, title: String)
}

/// The lessons of one level, grouped by week. Everything shown comes from `GET /levels/{code}/lessons`; completion is not
/// shown because the anonymous read always answers `false` (progress is a later story).
final class LessonListPresenter: LessonListPresenterInterface {
    private let levelCode: String
    private let interactor: LessonListInteractorInterface
    private let language: () -> AppLanguage
    private let request = SerialDisposable()

    private(set) var state: LessonListState = .idle
    private(set) var sections: [LessonWeekSection] = []
    var onChange: (() -> Void)?
    /// Held strongly: nothing else keeps the wireframe alive once its controller is pushed (it only holds the controller unowned).
    var wireframe: LessonListWireframeInterface?

    init(levelCode: String, interactor: LessonListInteractorInterface, language: @escaping () -> AppLanguage = { .current }) {
        self.levelCode = levelCode
        self.interactor = interactor
        self.language = language
    }

    deinit { request.dispose() }

    /// Called every time the screen appears: loads once, and again only after the request was cancelled by leaving.
    /// A failed list is reloaded by `retry()` only.
    func viewDidLoad() {
        guard state == .idle else { return }
        load()
    }

    func selectRow(section: Int, row: Int) {
        guard sections.indices.contains(section), sections[section].rows.indices.contains(row) else { return }
        let selected = sections[section].rows[row]
        wireframe?.showLesson(slug: selected.slug, title: selected.title)
    }

    func retry() {
        guard state != .loading else { return }
        load()
    }

    func cancelLoading() {
        guard state == .loading else { return }
        request.disposable = Disposables.create()
        state = .idle
    }

    private func load() {
        state = .loading
        onChange?()
        request.disposable = interactor.lessons(levelCode: levelCode)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] lessons in
                guard let self else { return }
                self.sections = Self.sections(from: lessons, language: self.language())
                self.state = self.sections.isEmpty ? .empty : .loaded
                self.onChange?()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.sections = []
                self.state = .failed((error as? LocalizedError)?.errorDescription
                                     ?? NSLocalizedString("Couldn't load data. Check your connection and try again.", comment: ""))
                self.onChange?()
            })
    }

    static func sections(from lessons: [BJTLessonSummaryDTO], language: AppLanguage) -> [LessonWeekSection] {
        let weeks = Dictionary(grouping: lessons, by: \.weekNumber)
        return weeks.keys.sorted().map { week in
            // The server answers in order; `sortOrder` keeps that order after the grouping.
            let rows = (weeks[week] ?? []).sorted { $0.sortOrder < $1.sortOrder }.map { row($0, language: language) }
            return LessonWeekSection(weekNumber: week, rows: rows)
        }
    }

    private static func row(_ lesson: BJTLessonSummaryDTO, language: AppLanguage) -> LessonRow {
        let japanese = language == .japanese
        return LessonRow(id: lesson.id, slug: lesson.slug,
                         title: text(japanese ? lesson.titleJa : lesson.titleVi, fallback: lesson.titleVi, lesson.titleJa),
                         summary: text(japanese ? lesson.descriptionJa : lesson.descriptionVi, fallback: lesson.descriptionVi, lesson.descriptionJa),
                         unitType: lesson.unitType,
                         minutes: lesson.estimatedDurationMin > 0 ? lesson.estimatedDurationMin : nil,
                         activityCount: lesson.activityCount > 0 ? lesson.activityCount : nil)
    }

    /// The preferred text unless it is blank, then the other language's, so a row is never empty because of a missing translation.
    private static func text(_ preferred: String, fallback first: String, _ second: String) -> String {
        [preferred, first, second].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }
}
