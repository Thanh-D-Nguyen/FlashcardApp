import Foundation

/// `GET /api/scenarios`, `GET /api/scenarios/{id}`, `POST /api/scenarios/steps/{id}/answer` and
/// `POST /api/scenarios/{id}/complete` (backend `internal/scenario`, `handler_scenario.go`). The key names are the ones the Go handlers send.
struct BJTScenarioSummaryDTO: Decodable, Equatable {
    struct Counts: Decodable, Equatable {
        let steps: Int
        /// Every learner's attempts, not the caller's: never shown as personal progress.
        let attempts: Int
    }

    let id: String
    let slug: String
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let difficulty: String
    let category: String
    let iconEmoji: String?
    let estimatedMin: Int
    let count: Counts

    private enum CodingKeys: String, CodingKey {
        case id, slug, titleVi, titleJa, descriptionVi, difficulty, category, iconEmoji, estimatedMin
        case count = "_count"
    }
}

struct BJTScenarioDetailDTO: Decodable, Equatable {
    struct Choice: Decodable, Equatable {
        let id: String
        let choiceKey: String
        let textVi: String
        let textJa: String?
    }

    struct Step: Decodable, Equatable {
        let id: String
        let stepOrder: Int
        let situationVi: String
        let situationJa: String?
        let speakerName: String?
        let speakerRole: String?
        let choices: [Choice]
    }

    let id: String
    let slug: String
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let difficulty: String
    let category: String
    let estimatedMin: Int
    let steps: [Step]
}

struct BJTScenarioAnswerDTO: Decodable, Equatable {
    let choiceKey: String
    let isOptimal: Bool
    let pointsAwarded: Int
    let feedbackVi: String?
}

struct BJTScenarioAttemptDTO: Decodable, Equatable {
    let id: String
    let totalPoints: Int
    let maxPoints: Int
}
