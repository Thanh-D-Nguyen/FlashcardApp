import Foundation
import RxSwift

enum PracticeOptionOutcome: Equatable {
    case none
    /// The learner's choice, and it is right.
    case correct
    /// The learner's choice, and it is wrong.
    case incorrect
    /// Not chosen, but it is the right answer.
    case correctAnswer
}

struct PracticeOptionState: Equatable {
    let key: String
    let text: String
    let outcome: PracticeOptionOutcome
    /// Why this option is right or wrong; only shown for the learner's choice and the right answer, after answering.
    let rationale: String?
}

struct PracticeQuestionState: Equatable {
    let index: Int
    let total: Int
    let activityId: String
    let questionType: String
    let stimulus: String?
    let scenario: String?
    let prompt: String
    let promptTranslation: String?
    let options: [PracticeOptionState]
    let isAnswered: Bool
    let isCorrect: Bool?
    let explanation: String?
    let isLast: Bool
}

enum LessonServerSync: Equatable {
    /// Nobody is signed in: progress stays on this device.
    case notApplicable
    /// Signed in, completed here, not sent yet (reopened later): the learner chooses to send it.
    case notSent
    case sending
    case confirmed
    case failed(String)
    /// The connection broke after the request may have been sent.
    case unknown(String)
}

struct PracticeSummary: Equatable {
    let total: Int
    let correct: Int
    let server: LessonServerSync
}

enum LessonPracticeScreen: Equatable {
    case question(PracticeQuestionState)
    case summary(PracticeSummary)
}

protocol LessonPracticePresenterInterface: AnyObject {
    var title: String { get }
    var screen: LessonPracticeScreen { get }
    /// Set when the last action could not be saved on this device.
    var errorMessage: String? { get }
    var onChange: (() -> Void)? { get set }
    func viewDidLoad()
    func selectOption(at index: Int)
    func next()
    func retrySync()
    func cancelLoading()
}

/// Walks a lesson's activities one at a time. The choice is final once made and is saved on this device before anything is
/// revealed; finishing marks the lesson done here and, for a signed-in learner, sends one progress write whose outcome is
/// kept apart from the local fact. Nothing is resent on its own.
final class LessonPracticePresenter: LessonPracticePresenterInterface {
    private let lesson: BJTLessonDetailDTO
    private let store: LessonProgressStoreInterface
    private let api: BJTLessonProgressAPIInterface
    private let ownerKey: () -> String
    private let language: () -> AppLanguage
    private let now: () -> Date
    private let request = SerialDisposable()
    private let subject: LessonProgressSubject
    private let analytics: AnalyticsTracking

    private var index = 0
    private var finished = false
    private var sync: LessonServerSync = .notApplicable
    /// The account `sync` describes.
    private var syncOwner: String?

    private(set) var title: String
    private(set) var screen: LessonPracticeScreen = .summary(PracticeSummary(total: 0, correct: 0, server: .notApplicable))
    private(set) var errorMessage: String?
    var onChange: (() -> Void)?

    private var activities: [BJTLessonActivityDTO] { lesson.lessonContent.activities }

    init(lesson: BJTLessonDetailDTO, store: LessonProgressStoreInterface, api: BJTLessonProgressAPIInterface,
         ownerKey: @escaping () -> String, language: @escaping () -> AppLanguage = { .current }, now: @escaping () -> Date = Date.init,
         analytics: AnalyticsTracking = AnalyticsService.shared) {
        self.analytics = analytics
        self.lesson = lesson
        self.store = store
        self.api = api
        self.ownerKey = ownerKey
        self.language = language
        self.now = now
        self.title = lesson.titleVi
        self.subject = LessonProgressSubject(slug: lesson.slug, lessonId: lesson.id, levelCode: lesson.levelCode, sortOrder: lesson.sortOrder,
                                             contentVersion: lesson.contentVersion ?? "", activityIds: lesson.lessonContent.activities.map(\.id))
    }

    deinit { request.dispose() }

    /// Starts at the first question the learner has not answered; a finished lesson opens on its summary.
    func viewDidLoad() {
        title = language() == .japanese && !lesson.titleJa.isEmpty ? lesson.titleJa : lesson.titleVi
        let progress = store.progress(slug: lesson.slug, ownerKey: ownerKey())
        let answered = Set(progress?.answers.map(\.activityId) ?? [])
        let owner = ownerKey()
        if let first = activities.firstIndex(where: { !answered.contains($0.id) }) {
            index = first
            finished = false
        } else if progress?.completedAt == nil, !activities.isEmpty {
            // Every answer is saved but the learner left before Finish: reopen on the last question so finishing marks it done.
            index = activities.count - 1
            finished = false
        } else {
            // Appearing again keeps what is known about the account write (unknown, failed) unless the store says it is confirmed.
            let stored = initialSync(for: progress)
            if !finished || syncOwner != owner || stored == .confirmed { sync = stored }
            finished = true
        }
        syncOwner = owner
        render()
    }

    func selectOption(at position: Int) {
        guard !finished, activities.indices.contains(index), activities[index].options.indices.contains(position) else { return }
        let activity = activities[index]
        let owner = ownerKey()
        guard store.progress(slug: lesson.slug, ownerKey: owner)?.optionKey(for: activity.id) == nil else { return }
        do {
            try store.recordAnswer(LessonAnswer(activityId: activity.id, optionKey: activity.options[position].key), for: subject, ownerKey: owner, at: now())
            errorMessage = nil
        } catch {
            // Not saved, so not shown as answered.
            errorMessage = NSLocalizedString("Couldn't save your answer on this device. Try again.", comment: "")
        }
        render()
    }

    func next() {
        guard !finished, activities.indices.contains(index),
              store.progress(slug: lesson.slug, ownerKey: ownerKey())?.optionKey(for: activities[index].id) != nil else { return }
        if index + 1 < activities.count {
            index += 1
            render()
        } else {
            finish()
        }
    }

    func retrySync() {
        guard finished, sync != .sending, sync != .confirmed, sync != .notApplicable else { return }
        sendProgress()
    }

    func cancelLoading() {
        guard sync == .sending else { return }
        request.disposable = Disposables.create()
        // The write may already have reached the server.
        sync = .unknown(NSLocalizedString("The connection was interrupted.", comment: ""))
        render()
    }

    // MARK: Finishing and saving to the account

    private func finish() {
        let owner = ownerKey()
        do {
            try store.markCompleted(for: subject, ownerKey: owner, at: now())
            errorMessage = nil
        } catch {
            errorMessage = NSLocalizedString("Couldn't save your answer on this device. Try again.", comment: "")
            render()
            return
        }
        finished = true
        analytics.track(.lessonCompleted(levelCode: lesson.levelCode))
        if owner.isEmpty {
            sync = .notApplicable
            render()
        } else {
            sendProgress()
        }
    }

    private func initialSync(for progress: LessonProgress?) -> LessonServerSync {
        guard !ownerKey().isEmpty else { return .notApplicable }
        return progress?.isServerConfirmed == true ? .confirmed : .notSent
    }

    private func sendProgress() {
        let owner = ownerKey()
        guard !owner.isEmpty else { sync = .notApplicable; render(); return }
        sync = .sending
        render()
        request.disposable = api.markLessonCompleted(slug: lesson.slug)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                // A different account (or none) is signed in now: this answer belongs to the one that asked, so it is dropped.
                guard self.ownerKey() == owner else { self.sync = self.initialSync(for: nil); self.render(); return }
                do {
                    try self.store.markServerConfirmed(slug: self.lesson.slug, ownerKey: owner, at: self.now())
                    self.sync = .confirmed
                } catch {
                    self.sync = .failed(NSLocalizedString("Saved to your account, but not recorded on this device.", comment: ""))
                }
                self.render()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                guard self.ownerKey() == owner else { self.sync = self.initialSync(for: nil); self.render(); return }
                switch error as? LearnerAPIError {
                case .staleSession?: self.sync = self.initialSync(for: nil)
                case .interrupted?: self.sync = .unknown((error as? LocalizedError)?.errorDescription ?? "")
                default: self.sync = .failed((error as? LocalizedError)?.errorDescription ?? NSLocalizedString("Couldn't load data. Check your connection and try again.", comment: ""))
                }
                self.render()
            })
    }

    // MARK: Screen

    private func render() {
        screen = finished ? .summary(summary()) : .question(question(at: index))
        onChange?()
    }

    private func summary() -> PracticeSummary {
        let answers = store.progress(slug: lesson.slug, ownerKey: ownerKey())?.answers ?? []
        let correct = activities.filter { activity in answers.first { $0.activityId == activity.id }?.optionKey == activity.answer }.count
        return PracticeSummary(total: activities.count, correct: correct, server: sync)
    }

    private func question(at position: Int) -> PracticeQuestionState {
        let activity = activities[position]
        let chosen = store.progress(slug: lesson.slug, ownerKey: ownerKey())?.optionKey(for: activity.id)
        let japanese = language() == .japanese
        let options = activity.options.map { option -> PracticeOptionState in
            guard let chosen else { return PracticeOptionState(key: option.key, text: option.text, outcome: .none, rationale: nil) }
            let outcome: PracticeOptionOutcome
            if option.key == chosen { outcome = option.key == activity.answer ? .correct : .incorrect }
            else { outcome = option.key == activity.answer ? .correctAnswer : .none }
            return PracticeOptionState(key: option.key, text: option.text, outcome: outcome, rationale: outcome == .none ? nil : Self.clean(option.rationaleVi))
        }
        let explanation = japanese ? Self.clean(activity.explanationJa) ?? Self.clean(activity.explanationVi) : Self.clean(activity.explanationVi) ?? Self.clean(activity.explanationJa)
        return PracticeQuestionState(
            index: position, total: activities.count, activityId: activity.id, questionType: activity.questionType,
            stimulus: Self.clean(activity.stimulusText), scenario: japanese ? Self.clean(activity.scenarioJa) : Self.clean(activity.scenarioVi),
            prompt: activity.prompt, promptTranslation: japanese ? nil : Self.clean(activity.promptVi), options: options,
            isAnswered: chosen != nil, isCorrect: chosen.map { $0 == activity.answer },
            explanation: chosen == nil ? nil : explanation, isLast: position == activities.count - 1)
    }

    private static func clean(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}
