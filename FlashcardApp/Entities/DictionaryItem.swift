//
//  DictionaryItem.swift
//  FlashcardApp
//
//  A dictionary entry as the search list, the history and the saved list refer to it. `id` is the backend UUID and is
//  never derived or truncated; the text fields are what the search row showed, kept so a history row can be drawn
//  without a request.
//

import Foundation

enum DictionaryItemKind: String, Codable, CaseIterable {
    case vocabulary, kanji, grammar, sentence

    /// The backend's `kind` in search results.
    init?(serverKind: String) {
        switch serverKind {
        case "lexeme": self = .vocabulary
        case "kanji": self = .kanji
        case "grammar": self = .grammar
        case "example": self = .sentence
        default: return nil
        }
    }

    /// The type segment of `/bookmarks/{type}/{id}`. Sentences cannot be bookmarked on the server.
    var bookmarkType: String? {
        switch self {
        case .vocabulary: return "lexeme"
        case .kanji: return "kanji"
        case .grammar: return "grammar"
        case .sentence: return nil
        }
    }

    var searchType: DictionarySearchType {
        switch self {
        case .vocabulary: return .vocabulary
        case .kanji: return .kanji
        case .grammar: return .grammar
        case .sentence: return .sentence
        }
    }
}

struct DictionaryItem: Equatable, Codable, Hashable {
    let kind: DictionaryItemKind
    let id: String
    /// Headword, kanji, grammar pattern or the Japanese sentence.
    let title: String
    let reading: String?
    /// Short Vietnamese meaning or translation.
    let meaning: String?
    /// "N5"… when the backend knows it.
    let level: String?

    init(kind: DictionaryItemKind, id: String, title: String, reading: String? = nil, meaning: String? = nil, level: String? = nil) {
        self.kind = kind
        self.id = id
        self.title = title
        self.reading = reading
        self.meaning = meaning
        self.level = level
    }

    /// `nil` for a row of a kind the dictionary has no screen for (lessons) or without an id/title.
    init?(_ result: BJTSearchResultDTO) {
        guard let kind = DictionaryItemKind(serverKind: result.kind), !result.id.isEmpty, !result.title.isEmpty else { return nil }
        func clean(_ text: String?) -> String? {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        self.init(kind: kind, id: result.id, title: result.title, reading: clean(result.reading),
                  meaning: clean(result.description), level: clean(result.jlptLevel))
    }

    /// Text that goes to the pasteboard or a share sheet: the word, then its reading and meaning.
    var summary: String {
        var line = title
        if let reading, reading != title { line += "（\(reading)）" }
        if let meaning { line += " — \(meaning)" }
        return line
    }
}
