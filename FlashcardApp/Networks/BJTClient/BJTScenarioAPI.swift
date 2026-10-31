import Alamofire
import Foundation
import RxSwift

/// The everyday-situation lessons of the website ("Tình huống"): the catalogue, one situation, the check of one answer and the record
/// of a finished run. All need the learner's session.
protocol BJTScenarioAPIInterface: AnyObject {
    /// Only situations the server can play (active, with steps and choices). Read-only; safe to repeat.
    func scenarios() -> Single<[BJTScenarioSummaryDTO]>
    /// Read-only; safe to repeat. The answers are not in it.
    func scenario(id: String) -> Single<BJTScenarioDetailDTO>
    /// Says whether a choice is the natural one. Stores nothing, so it is safe to repeat.
    func answer(stepID: String, choiceKey: String) -> Single<BJTScenarioAnswerDTO>
    /// Records a finished run. NOT idempotent: every successful call adds an attempt, so a caller never repeats it by itself.
    func complete(scenarioID: String, choices: [BJTScenarioChoiceInput]) -> Single<BJTScenarioAttemptDTO>
}

struct BJTScenarioChoiceInput: Encodable, Equatable {
    let stepOrder: Int
    let choiceKey: String
}

extension BJTLearnerAPI: BJTScenarioAPIInterface {
    private struct AnswerBody: Encodable { let choiceKey: String }
    private struct CompleteBody: Encodable { let choices: [BJTScenarioChoiceInput] }

    func scenarios() -> Single<[BJTScenarioSummaryDTO]> {
        // `null` means the same as an empty catalogue.
        let response: Single<[BJTScenarioSummaryDTO]?> = perform(["scenarios"], method: .get, body: Optional<AnswerBody>.none)
        return response.map { $0 ?? [] }
    }

    func scenario(id: String) -> Single<BJTScenarioDetailDTO> {
        // The id becomes a path segment, and the server answers 500 to anything but a UUID.
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["scenarios", id], method: .get, body: Optional<AnswerBody>.none)
    }

    func answer(stepID: String, choiceKey: String) -> Single<BJTScenarioAnswerDTO> {
        guard UUID(uuidString: stepID) != nil, !choiceKey.isEmpty, choiceKey.count <= 16 else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["scenarios", "steps", stepID, "answer"], method: .post, body: AnswerBody(choiceKey: choiceKey))
    }

    func complete(scenarioID: String, choices: [BJTScenarioChoiceInput]) -> Single<BJTScenarioAttemptDTO> {
        guard UUID(uuidString: scenarioID) != nil, !choices.isEmpty else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["scenarios", scenarioID, "complete"], method: .post, body: CompleteBody(choices: choices))
    }
}
