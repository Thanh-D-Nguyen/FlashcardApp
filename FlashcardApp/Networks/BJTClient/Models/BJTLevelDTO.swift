import Foundation

struct BJTLevelDTO: Decodable {
    let code: String
    let nameVi: String
    let descriptionVi: String
    let vocabCount: Int
    let kanjiCount: Int
    let grammarCount: Int
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
