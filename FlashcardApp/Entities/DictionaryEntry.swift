//
//  DictionaryEntry.swift
//  FlashcardApp
//
//  What an entry detail screen shows, mapped from the backend payloads. Missing fields stay missing: the screen omits a
//  section instead of printing a placeholder, and nothing here is invented (no senses, readings, levels or sentences
//  beyond what the API returned).
//

import Foundation

enum Loadable<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// A run of text, bold or not: the backend's mnemonic marks its key word with `<b>…</b>`.
struct TextSegment: Equatable {
    let text: String
    let isEmphasised: Bool

    /// Splits `<b>…</b>` markup. Any other tag is dropped as text, so server markup can never style or link anything.
    static func parse(_ markup: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var emphasised = false
        var buffer = ""
        var index = markup.startIndex
        func flush() {
            if !buffer.isEmpty { segments.append(TextSegment(text: buffer, isEmphasised: emphasised)); buffer = "" }
        }
        while index < markup.endIndex {
            if markup[index] == "<", let close = markup[index...].firstIndex(of: ">") {
                let tag = markup[markup.index(after: index)..<close].lowercased().trimmingCharacters(in: .whitespaces)
                if tag == "b" || tag == "strong" { flush(); emphasised = true }
                else if tag == "/b" || tag == "/strong" { flush(); emphasised = false }
                index = markup.index(after: close)
                continue
            }
            buffer.append(markup[index])
            index = markup.index(after: index)
        }
        flush()
        return segments
    }
}

struct VocabularyDetail: Equatable {
    struct Meaning: Equatable {
        let text: String
        let partOfSpeech: String?
        let note: String?
    }

    let id: String
    let headword: String
    let reading: String?
    /// Sino-Vietnamese reading of the kanji in the headword.
    let hanViet: String?
    let level: String?
    let meanings: [Meaning]
    let pitch: [PitchPattern]

    var item: DictionaryItem {
        DictionaryItem(kind: .vocabulary, id: id, title: headword, reading: reading, meaning: meanings.first?.text, level: level)
    }
}

struct KanjiReference: Equatable {
    let id: String
    let character: String
    let meaning: String?
}

struct KanjiDetail: Equatable {
    struct Word: Equatable {
        let word: String
        let reading: String?
        let meaning: String?
        let hanViet: String?
    }

    struct Component: Equatable {
        let character: String
        let hanViet: String?
    }

    let id: String
    let character: String
    /// Sino-Vietnamese reading(s) ("THỰC, TỰ"): the kanji's meaning in this dictionary.
    let meaning: String?
    let onyomi: [String]
    let kunyomi: [String]
    let strokeCount: Int?
    let level: String?
    let frequency: Int?
    /// Paragraphs of the long explanation.
    let explanation: [String]
    let mnemonic: [TextSegment]
    let words: [Word]
    let components: [Component]
    let strokeHash: String?

    var item: DictionaryItem {
        DictionaryItem(kind: .kanji, id: id, title: character, reading: nil, meaning: meaning, level: level)
    }
}

struct GrammarDetail: Equatable {
    struct Section: Equatable {
        /// How the pattern is built ("Nghi vấn từ + ても").
        let formation: String?
        let meaning: String?
        let explanation: String?
        let note: String?
    }

    let id: String
    let pattern: String
    let meaning: String
    let level: String?
    let category: String?
    let sections: [Section]

    var item: DictionaryItem {
        DictionaryItem(kind: .grammar, id: id, title: pattern, reading: nil, meaning: meaning, level: level)
    }

    /// The part of the pattern worth searching sentences for: "〜ても", "... ても" and "Nに（は）" lose their placeholder marks.
    /// `nil` when fewer than two Japanese characters remain: that is too little to find meaningful sentences with.
    var exampleTerm: String? {
        let first = pattern.split(whereSeparator: { "/／;；".contains($0) }).first.map(String.init) ?? pattern
        let marks = CharacterSet(charactersIn: "~〜～…・.。、,()（）[]「」 　")
        let cleaned = first.unicodeScalars.filter { !marks.contains($0) }.map(String.init).joined()
        guard cleaned.count <= CardExampleLookup.maximumTermLength, cleaned.filter({ JapaneseText.containsJapanese(String($0)) }).count >= 2 else { return nil }
        return cleaned
    }
}

struct SentenceDetail: Equatable {
    let id: String
    let japanese: String
    let reading: String?
    let translation: String?

    var item: DictionaryItem {
        DictionaryItem(kind: .sentence, id: id, title: japanese, reading: reading, meaning: translation)
    }
}

enum EntryDetail: Equatable {
    case vocabulary(VocabularyDetail)
    case kanji(KanjiDetail)
    case grammar(GrammarDetail)
    case sentence(SentenceDetail)

    var item: DictionaryItem {
        switch self {
        case .vocabulary(let detail): return detail.item
        case .kanji(let detail): return detail.item
        case .grammar(let detail): return detail.item
        case .sentence(let detail): return detail.item
        }
    }
}

enum DictionaryEntryMapper {
    static func vocabulary(_ dto: BJTLexemeDetailDTO) -> VocabularyDetail {
        var meanings = dto.senses.compactMap { sense -> VocabularyDetail.Meaning? in
            guard let text = clean(sense.glossVi) else { return nil }
            return VocabularyDetail.Meaning(text: text, partOfSpeech: clean(sense.posTag), note: clean(sense.note))
        }
        // Most current entries carry only the short meaning; it is the one gloss there is.
        if meanings.isEmpty, let short = clean(dto.shortMeaningVi) {
            meanings = [VocabularyDetail.Meaning(text: short, partOfSpeech: nil, note: nil)]
        }
        return VocabularyDetail(id: dto.id, headword: dto.headword, reading: clean(dto.reading), hanViet: clean(dto.kanjiMeaningVi),
                                level: clean(dto.jlptLevel), meanings: meanings, pitch: PitchPattern.patterns(from: dto.pronunciation))
    }

    static func kanji(_ dto: BJTKanjiDetailDTO) -> KanjiDetail {
        KanjiDetail(
            id: dto.id, character: dto.character, meaning: clean(dto.meaningVi),
            onyomi: words(in: dto.onyomi), kunyomi: words(in: dto.kunyomi),
            strokeCount: dto.strokeCount.flatMap { $0 > 0 ? $0 : nil },
            level: dto.level.flatMap { (1...5).contains($0) ? "N\($0)" : nil },
            frequency: dto.frequency.flatMap { $0 > 0 ? $0 : nil },
            explanation: (dto.detail ?? "").components(separatedBy: "##").compactMap(clean),
            mnemonic: clean(dto.tip).map(TextSegment.parse) ?? [],
            words: dto.examples.map { KanjiDetail.Word(word: $0.word, reading: clean($0.reading), meaning: clean($0.meaningVi), hanViet: clean($0.hanViet)) },
            components: dto.components.sorted { $0.position < $1.position }
                .map { KanjiDetail.Component(character: $0.character, hanViet: clean($0.hanViet)) },
            strokeHash: clean(dto.strokeSvgHash))
    }

    static func grammar(_ dto: BJTGrammarDetailDTO) -> GrammarDetail {
        let sections = dto.details.sorted { $0.position < $1.position }.compactMap { detail -> GrammarDetail.Section? in
            let section = GrammarDetail.Section(formation: clean(detail.synopsis), meaning: clean(detail.meaningVi),
                                                explanation: clean(detail.explanation), note: clean(detail.note))
            return section.formation == nil && section.meaning == nil && section.explanation == nil && section.note == nil ? nil : section
        }
        return GrammarDetail(id: dto.id, pattern: dto.pattern, meaning: dto.meaningVi, level: clean(dto.jlptLevel),
                             category: clean(dto.category), sections: sections)
    }

    static func sentence(_ item: DictionaryItem) -> SentenceDetail {
        let reading = item.reading == item.title ? nil : item.reading
        return SentenceDetail(id: item.id, japanese: item.title, reading: reading, translation: item.meaning)
    }

    static func kanjiReferences(_ rows: [BJTKanjiReferenceDTO]) -> [KanjiReference] {
        var seen = Set<String>()
        return rows.filter { seen.insert($0.id).inserted }.map { KanjiReference(id: $0.id, character: $0.character, meaning: clean($0.meaningVi)) }
    }

    private static func clean(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func words(in text: String?) -> [String] {
        (text ?? "").split(whereSeparator: { $0.isWhitespace || $0 == "、" }).map(String.init)
    }
}
