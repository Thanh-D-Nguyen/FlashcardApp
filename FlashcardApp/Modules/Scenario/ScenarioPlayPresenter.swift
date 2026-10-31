//
//  ScenarioPlayPresenter.swift
//  FlashcardApp
//
//  One everyday situation: what is happening, two or more things the learner could say, and whether the one they chose is the
//  natural one. Asking the server about a choice stores nothing, so the learner may choose again. When the last step is answered the
//  run is recorded on the account once, in the background: the summary does not wait for it, and a failed recording is retried only
//  when the learner asks, because every successful recording adds an attempt.
//

import Foundation
import RxSwift

struct ScenarioChoiceState: Equatable {
    enum Mark: Equatable { case none, natural, other }

    let key: String
    let title: String
    let subtitle: String?
    var mark: Mark = .none
    var isEnabled = true
}

struct ScenarioFeedbackState: Equatable {
    let isNatural: Bool
    let title: String
    let detail: String?
    /// The Japanese phrase that was chosen, to hear it.
    let spokenText: String?
}

struct ScenarioRecapRow: Equatable {
    let step: String
    let phrase: String
    let meaning: String?
    let isNatural: Bool
    let spokenText: String?
}

struct ScenarioSummaryState: Equatable {
    enum Save: Equatable {
        case saving
        case saved
        case failed(message: String)
    }

    let headline: String
    let rows: [ScenarioRecapRow]
    var save: Save
    let nextTitle: String?
}

struct ScenarioPlayState: Equatable {
    enum Screen: Equatable {
        case loading
        case step
        case summary
        case failed(message: String, canRetry: Bool)
    }

    var screen: Screen = .loading
    var title = ""
    var subtitle: String?
    var progressText = ""
    var progress: Float = 0
    var situation = ""
    var situationGloss: String?
    var speaker: String?
    var choices: [ScenarioChoiceState] = []
    var feedback: ScenarioFeedbackState?
    /// A check that failed; the learner taps a phrase again to retry it.
    var error: String?
    var isBusy = false
    var canChooseAgain = false
    var continueTitle = ""
    var summary: ScenarioSummaryState?
}

protocol ScenarioPlayViewInterface: AnyObject {
    func render(_ state: ScenarioPlayState)
}

protocol ScenarioPlayPresenterInterface: AnyObject {
    func viewDidLoad()
    func viewWillDisappear()
    func choose(key: String)
    func chooseAgain()
    func advance()
    func retryLoad()
    func retrySave()
    func speak(_ text: String)
    func replay()
    func openNext()
    func close()
}

final class ScenarioPlayPresenter {
    private struct Pick {
        let key: String
        let isNatural: Bool
        let note: String?
    }

    private let summary: ScenarioSummary
    private let next: ScenarioSummary?
    private let interactor: ScenarioInteractorInterface
    private let wireframe: ScenarioPlayWireframeInterface
    private let speech: SpeechServiceInterface
    private let language: () -> AppLanguage
    weak var view: ScenarioPlayViewInterface?

    private var lesson: ScenarioLesson?
    private var stepIndex = 0
    private var picks: [Int: Pick] = [:]
    private var state = ScenarioPlayState()
    private var save: ScenarioSummaryState.Save = .saving
    private var saveStarted = false
    private let loading = SerialDisposable()
    private let checking = SerialDisposable()
    private let saving = SerialDisposable()

    init(summary: ScenarioSummary, next: ScenarioSummary?, interactor: ScenarioInteractorInterface, wireframe: ScenarioPlayWireframeInterface,
         speech: SpeechServiceInterface = SystemSpeechService.shared, language: @escaping () -> AppLanguage = { .current }) {
        self.summary = summary
        self.next = next
        self.interactor = interactor
        self.wireframe = wireframe
        self.speech = speech
        self.language = language
        state.title = summary.title.primary
        state.subtitle = summary.title.secondary
    }

    deinit {
        loading.dispose()
        checking.dispose()
        saving.dispose()
    }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func publish() { view?.render(state) }

    // MARK: Steps

    private var currentStep: ScenarioStep? {
        guard let lesson, lesson.steps.indices.contains(stepIndex) else { return nil }
        return lesson.steps[stepIndex]
    }

    private func showStep() {
        guard let lesson, let step = currentStep else { return }
        let pick = picks[step.order]
        state.screen = .step
        state.situation = step.situation.primary
        state.situationGloss = step.situation.secondary
        state.speaker = step.speaker
        state.progressText = String(format: Self.text("Step %1$lld of %2$lld"), stepIndex + 1, lesson.steps.count)
        state.progress = Float(stepIndex + (pick == nil ? 0 : 1)) / Float(lesson.steps.count)
        state.error = nil
        state.isBusy = false
        state.choices = step.choices.map { choice in
            var choiceState = ScenarioChoiceState(key: choice.key, title: choice.phrase.primary, subtitle: choice.phrase.secondary)
            if let pick {
                choiceState.isEnabled = false
                if pick.key == choice.key { choiceState.mark = pick.isNatural ? .natural : .other }
            }
            return choiceState
        }
        if let pick, let chosen = step.choices.first(where: { $0.key == pick.key }) {
            state.feedback = ScenarioFeedbackState(
                isNatural: pick.isNatural,
                title: pick.isNatural ? Self.text("That sounds natural") : Self.text("Another phrase fits better here"),
                detail: language() == .vietnamese ? pick.note : nil,
                spokenText: chosen.japanese)
            state.canChooseAgain = !pick.isNatural
            state.continueTitle = stepIndex == lesson.steps.count - 1 ? Self.text("See result") : Self.text("Continue")
        } else {
            state.feedback = nil
            state.canChooseAgain = false
            state.continueTitle = ""
        }
        publish()
    }

    // MARK: Summary

    private func showSummary() {
        guard let lesson else { return }
        speech.stop()
        let rows = lesson.steps.compactMap { step -> ScenarioRecapRow? in
            guard let pick = picks[step.order], let choice = step.choices.first(where: { $0.key == pick.key }) else { return nil }
            return ScenarioRecapRow(step: step.situation.primary, phrase: choice.phrase.primary, meaning: choice.phrase.secondary,
                                    isNatural: pick.isNatural, spokenText: choice.japanese)
        }
        let natural = rows.filter(\.isNatural).count
        state.screen = .summary
        state.progress = 1
        state.progressText = ""
        state.summary = ScenarioSummaryState(
            headline: String(format: Self.text("%1$lld of %2$lld natural phrases"), natural, rows.count),
            rows: rows, save: save,
            nextTitle: next.map { $0.title.primary })
        publish()
        startSaving()
    }

    private func startSaving() {
        guard !saveStarted, let lesson else { return }
        saveStarted = true
        record(lesson)
    }

    private func record(_ lesson: ScenarioLesson) {
        save = .saving
        state.summary?.save = .saving
        publish()
        let choices = lesson.steps.compactMap { step in picks[step.order].map { (stepOrder: step.order, choiceKey: $0.key) } }
        saving.disposable = interactor.complete(lessonID: lesson.id, choices: choices)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                self?.save = .saved
                self?.state.summary?.save = .saved
                self?.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.staleSession = error { return }
                var message = Self.message(for: error)
                if case LearnerAPIError.interrupted = error {
                    message += " " + Self.text("It may or may not have been saved.")
                }
                self.save = .failed(message: message)
                self.state.summary?.save = self.save
                self.publish()
            })
    }
}

extension ScenarioPlayPresenter: ScenarioPlayPresenterInterface {
    func viewDidLoad() {
        state.screen = .loading
        publish()
        loading.disposable = interactor.lesson(id: summary.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] lesson in
                guard let self else { return }
                self.lesson = lesson
                self.stepIndex = 0
                self.picks = [:]
                self.showStep()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.staleSession = error { return }
                var canRetry = true
                if case LearnerAPIError.signInRequired = error { canRetry = false }
                if case LearnerAPIError.notFound = error { canRetry = false }
                self.state.screen = .failed(message: Self.message(for: error), canRetry: canRetry)
                self.publish()
            })
    }

    func viewWillDisappear() { speech.stop() }

    func choose(key: String) {
        guard state.screen == .step, !state.isBusy, let step = currentStep, picks[step.order] == nil,
              step.choices.contains(where: { $0.key == key }) else { return }
        state.isBusy = true
        state.error = nil
        publish()
        checking.disposable = interactor.answer(stepID: step.id, choiceKey: key)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] answer in
                guard let self, self.currentStep?.id == step.id else { return }
                self.picks[step.order] = Pick(key: key, isNatural: answer.isNatural, note: answer.noteVietnamese)
                self.showStep()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.staleSession = error { return }
                self.state.isBusy = false
                self.state.error = Self.message(for: error)
                self.publish()
            })
    }

    func chooseAgain() {
        guard state.screen == .step, let step = currentStep, let pick = picks[step.order], !pick.isNatural else { return }
        picks[step.order] = nil
        showStep()
    }

    func advance() {
        guard let lesson, let step = currentStep, picks[step.order] != nil else { return }
        if stepIndex >= lesson.steps.count - 1 {
            showSummary()
        } else {
            stepIndex += 1
            showStep()
        }
    }

    func retryLoad() { viewDidLoad() }

    func retrySave() {
        guard let lesson, case .failed = save else { return }
        record(lesson)
    }

    func speak(_ text: String) { speech.speak(text, languageCode: "ja-JP") }

    /// A new run of the same situation. It is recorded as its own attempt when it ends.
    func replay() {
        guard lesson != nil else { return }
        saving.disposable = Disposables.create()
        speech.stop()
        stepIndex = 0
        picks = [:]
        save = .saving
        saveStarted = false
        state.summary = nil
        showStep()
    }

    func openNext() {
        guard let next else { return }
        wireframe.showNext(next)
    }

    func close() { wireframe.leave() }
}
