import Foundation

/// A city the learner can choose by hand. The ids are the server's fixed list; the app never sends a place name
/// or a location. Names are the same in Vietnamese and English for these cities.
struct LifeCity: Equatable {
    let id: String
    let nameJa: String
    let nameLatin: String

    static let defaultID = "tokyo"
    static let all: [LifeCity] = [
        LifeCity(id: "tokyo", nameJa: "東京", nameLatin: "Tokyo"),
        LifeCity(id: "yokohama", nameJa: "横浜", nameLatin: "Yokohama"),
        LifeCity(id: "osaka", nameJa: "大阪", nameLatin: "Osaka"),
        LifeCity(id: "nagoya", nameJa: "名古屋", nameLatin: "Nagoya"),
        LifeCity(id: "kyoto", nameJa: "京都", nameLatin: "Kyoto"),
        LifeCity(id: "sapporo", nameJa: "札幌", nameLatin: "Sapporo"),
        LifeCity(id: "sendai", nameJa: "仙台", nameLatin: "Sendai"),
        LifeCity(id: "hiroshima", nameJa: "広島", nameLatin: "Hiroshima"),
        LifeCity(id: "fukuoka", nameJa: "福岡", nameLatin: "Fukuoka"),
        LifeCity(id: "naha", nameJa: "那覇", nameLatin: "Naha")
    ]

    static func city(id: String) -> LifeCity? { all.first { $0.id == id } }

    func displayName(_ language: AppLanguage) -> String { language == .japanese ? nameJa : nameLatin }
}

/// Text the server sends in Vietnamese and English. The Japanese UI shows English: the backend has no third language.
struct LifeText: Equatable {
    let vi: String
    let en: String

    func resolved(_ language: AppLanguage) -> String { language == .vietnamese ? vi : en }
}

/// A validated weather lesson. Provider facts (`facts`, `source`) are separate from the template text (`sentences`...).
struct LifeLesson: Equatable {
    enum Freshness: String, Equatable { case live, stale }
    enum LicenseStatus: String, Equatable {
        case commercial, nonCommercialDevOnly = "non_commercial_dev_only"
        /// Computed on the device or written as an example: no provider licence is involved.
        case notApplicable = "not_applicable"
    }

    struct Source: Equatable {
        let providerName: String
        /// The provider's own page (the attribution link its licence asks for); `nil` for on-device and sample lessons.
        let url: URL?
        let attributionText: String?
        let licenseName: String
        let licenseStatus: LicenseStatus
        let observedAt: Date
        let fetchedAt: Date
        let expiresAt: Date
        let freshness: Freshness
    }

    /// The provider's weather values; only weather lessons have them.
    struct Facts: Equatable {
        /// The Japan calendar day the values describe, `yyyy-MM-dd`.
        let date: String
        let weatherCode: Int
        let temperatureMaxC: Int
        let temperatureMinC: Int
        let precipitationProbabilityPercent: Int?
    }

    struct Sentence: Equatable {
        let id: String
        /// True for a rule of the lesson template (an umbrella reminder), not for something the provider reported.
        let isAdvice: Bool
        let japanese: String
        let reading: String
        let translation: LifeText
        let explanation: LifeText
    }

    struct Vocabulary: Equatable {
        let id: String
        let japanese: String
        let reading: String
        let meaning: LifeText
        let example: String
    }

    struct Choice: Equatable {
        let id: String
        let text: String
    }

    enum Exercise: Equatable {
        /// Type the missing word. A recall exercise: nothing on screen contains the answer.
        case recall(id: String, promptJapanese: String, prompt: LifeText, acceptedAnswers: [String], explanation: LifeText)
        /// Pick one reading. Recognition, not recall.
        case choice(id: String, promptJapanese: String, prompt: LifeText, choices: [Choice], correctChoiceID: String, explanation: LifeText)

        var id: String {
            switch self {
            case .recall(let id, _, _, _, _), .choice(let id, _, _, _, _, _): return id
            }
        }
    }

    let id: String
    let topic: LifeTopic
    let provenance: LifeProvenance
    let level: String
    let cityID: String
    let titleJapanese: String
    let titleReading: String
    let title: LifeText
    let source: Source
    let facts: Facts?
    /// The facts in short, for the story and the card.
    let chips: [LifeChip]
    /// The picture for topics that choose their own; weather derives it from the weather code.
    let scene: LifeScene?
    let sentences: [Sentence]
    let vocabulary: [Vocabulary]
    let exercises: [Exercise]
    let estimatedMinutes: Int
    let cityName: LifeText
    let cityNameJapanese: String
}

/// How a typed answer is compared: exactly, after trimming, folding width/case and dropping a closing 。
enum LifeAnswerChecker {
    static func isCorrect(_ answer: String, accepted: [String]) -> Bool {
        let given = normalize(answer)
        guard !given.isEmpty else { return false }
        return accepted.contains { normalize($0) == given }
    }

    static func normalize(_ text: String) -> String {
        var folded = text.precomposedStringWithCompatibilityMapping.lowercased()
        folded = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = folded.last, last == "。" || last == "." { folded.removeLast() }
        return folded.replacingOccurrences(of: " ", with: "")
    }
}
