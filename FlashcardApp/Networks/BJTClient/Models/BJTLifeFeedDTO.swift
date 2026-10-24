import Foundation

/// `GET /api/life/feed?city=<id>`: the cards of the Today life hub, one lesson per topic. This is the contract the app is ready
/// for; the server does not provide it yet (see docs/plans/today-life-hub-server-needs.md). Unknown topics are ignored by the
/// app, so the server can add topics without an app update.
struct BJTLifeFeedDTO: Decodable, Equatable {
    struct Headline: Decodable, Equatable {
        let japanese: String
        let reading: String
    }

    struct Chip: Decodable, Equatable {
        let symbol: String?
        let text: BJTLifeTextDTO
    }

    struct Scene: Decodable, Equatable {
        /// `weather`, `date`, `place`, `transit`, `shopping`, `news`, `food`, `culture`, `money` or `lottery`.
        let kind: String
        let weatherCode: Int?
        let temperatureC: Double?
        let day: Int?
        let weekday: String?
    }

    struct Source: Decodable, Equatable {
        let providerName: String
        let url: String?
        let attributionText: String?
        let licenseStatus: String?
        let observedAt: String
        let fetchedAt: String
        let expiresAt: String
        let freshness: String
    }

    struct Lesson: Decodable, Equatable {
        let id: String
        let level: String
        let title: BJTLifeLessonDTO.Title
        let source: Source
        let chips: [Chip]
        let sentences: [BJTLifeLessonDTO.Sentence]
        let vocabulary: [BJTLifeLessonDTO.Vocabulary]
        let exercises: [BJTLifeLessonDTO.Exercise]
        let estimatedMinutes: Int
    }

    struct Card: Decodable, Equatable {
        let id: String
        let topic: String
        /// `live` (a provider or the editors) or `sample` (example content). Anything else makes the card invalid.
        let provenance: String
        let summary: BJTLifeTextDTO
        let meta: BJTLifeTextDTO?
        let scene: Scene
        let lesson: Lesson
    }

    let schemaVersion: Int
    let generatedAt: String
    let cityId: String
    let cards: [Card]
}
