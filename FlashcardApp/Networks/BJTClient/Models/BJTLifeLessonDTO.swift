import Foundation

/// `GET /api/life/lessons/weather` (backend `internal/lifelesson`, schema `LifeWeatherLesson` in docs/openapi.json).
/// Field names are the JSON keys the Go handler sends; nothing here is inferred from the route name.
struct BJTLifeTextDTO: Decodable, Equatable {
    let vi: String
    let en: String
}

struct BJTLifeLessonDTO: Decodable, Equatable {
    struct City: Decodable, Equatable {
        let id: String
        let nameJa: String
        let readingJa: String
        let nameEn: String
        let nameVi: String
    }

    struct Source: Decodable, Equatable {
        let provider: String
        let providerName: String
        let url: String
        let attributionText: String
        let licenseName: String
        let licenseUrl: String
        let licenseStatus: String
        let observedAt: String
        let fetchedAt: String
        let expiresAt: String
        let freshness: String
    }

    struct Facts: Decodable, Equatable {
        let date: String
        let weatherCode: Int
        let weatherCodeSystem: String
        let temperatureMaxC: Double
        let temperatureMinC: Double
        let currentTemperatureC: Double
        let precipitationProbabilityMaxPercent: Int?
        let precipitationSumMm: Double?
    }

    struct Sentence: Decodable, Equatable {
        let id: String
        let basis: String
        let japanese: String
        let reading: String
        let translations: BJTLifeTextDTO
        let explanation: BJTLifeTextDTO
    }

    struct Vocabulary: Decodable, Equatable {
        let id: String
        let japanese: String
        let reading: String
        let meanings: BJTLifeTextDTO
        let exampleJapanese: String
    }

    struct Choice: Decodable, Equatable {
        let id: String
        let text: String
    }

    struct Exercise: Decodable, Equatable {
        let id: String
        let kind: String
        let skillType: String
        let promptJapanese: String
        let prompt: BJTLifeTextDTO
        let acceptedAnswers: [String]?
        let choices: [Choice]?
        let correctChoiceId: String?
        let explanation: BJTLifeTextDTO
    }

    struct Title: Decodable, Equatable {
        let japanese: String
        let reading: String
        let vi: String
        let en: String
    }

    struct Content: Decodable, Equatable {
        let generatedBy: String
        let templateVersion: String
        let title: Title
        let sentences: [Sentence]
        let vocabulary: [Vocabulary]
        let exercises: [Exercise]
        let estimatedMinutes: Int
    }

    let schemaVersion: Int
    let id: String
    let topic: String
    let level: String
    let city: City
    let source: Source
    let facts: Facts
    let lesson: Content
}
