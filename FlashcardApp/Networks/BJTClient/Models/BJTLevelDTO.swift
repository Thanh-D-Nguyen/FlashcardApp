import Foundation

struct BJTLevelDTO: Decodable {
    let code: String
    let nameVi: String
    let descriptionVi: String
    let vocabCount: Int
    let kanjiCount: Int
    let grammarCount: Int
    /// The backend also sends the level name and description in English and Japanese.
    var nameEn: String? = nil
    var nameJa: String? = nil
    var descriptionEn: String? = nil
    var descriptionJa: String? = nil

    /// Full name ("J5 — Lower beginner") in the app language; Vietnamese when that translation is missing.
    func localizedName(for language: AppLanguage) -> String {
        Self.nonEmpty(language == .english ? nameEn : language == .japanese ? nameJa : nil) ?? nameVi
    }

    func localizedDescription(for language: AppLanguage) -> String {
        Self.nonEmpty(language == .english ? descriptionEn : language == .japanese ? descriptionJa : nil) ?? descriptionVi
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

struct BJTLevelVocabularyItemDTO: Decodable {
    let id: String
    let headword: String
    let reading: String?
    let shortMeaningVi: String?
    let senses: [Sense]

    struct Sense: Decodable {
        let meaningVi: String?
    }
}

struct BJTLevelKanjiItemDTO: Decodable {
    let id: String
    let character: String
    let meaningVi: String?
    let onyomi: String?
    let kunyomi: String?
}

struct BJTLevelGrammarItemDTO: Decodable {
    let id: String
    let pattern: String
    let meaningVi: String?
    let details: [Detail]

    struct Detail: Decodable {
        let explanationVi: String?
    }
}
