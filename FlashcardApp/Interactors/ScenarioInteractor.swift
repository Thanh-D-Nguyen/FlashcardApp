//
//  ScenarioInteractor.swift
//  FlashcardApp
//
//  Use cases of the everyday-situation lessons. The catalogue and the checking of answers live on the server and need the
//  learner's session. Checking an answer stores nothing; recording a finished run adds an attempt every time it succeeds, so
//  this layer never repeats it.
//

import Foundation
import RxSwift

protocol ScenarioInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    func catalogue() -> Single<[ScenarioSummary]>
    func lesson(id: String) -> Single<ScenarioLesson>
    func answer(stepID: String, choiceKey: String) -> Single<ScenarioAnswer>
    /// One entry per step, in step order. Never call it twice for one finished run unless the learner asks.
    func complete(lessonID: String, choices: [(stepOrder: Int, choiceKey: String)]) -> Single<Void>
}

final class ScenarioInteractor: ScenarioInteractorInterface {
    private let api: BJTScenarioAPIInterface
    private let auth: AuthSession
    private let language: () -> AppLanguage

    init(api: BJTScenarioAPIInterface = BJTLearnerAPI.shared, auth: AuthSession = .shared, language: @escaping () -> AppLanguage = { .current }) {
        self.api = api
        self.auth = auth
        self.language = language
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func catalogue() -> Single<[ScenarioSummary]> {
        let language = language()
        return api.scenarios().map { list in
            // A situation without steps would open an empty screen; the server already withholds those, this keeps the rule here too.
            list.filter { $0.count.steps > 0 }.map { ScenarioSummary(dto: $0, language: language) }
        }
    }

    func lesson(id: String) -> Single<ScenarioLesson> {
        let language = language()
        return api.scenario(id: id).map { dto in
            guard let lesson = ScenarioLesson(dto: dto, language: language) else { throw LearnerAPIError.invalidResponse }
            return lesson
        }
    }

    func answer(stepID: String, choiceKey: String) -> Single<ScenarioAnswer> {
        api.answer(stepID: stepID, choiceKey: choiceKey).map(ScenarioAnswer.init(dto:))
    }

    func complete(lessonID: String, choices: [(stepOrder: Int, choiceKey: String)]) -> Single<Void> {
        let inputs = choices.map { BJTScenarioChoiceInput(stepOrder: $0.stepOrder, choiceKey: $0.choiceKey) }
        return api.complete(scenarioID: lessonID, choices: inputs).map { _ in () }
    }
}
