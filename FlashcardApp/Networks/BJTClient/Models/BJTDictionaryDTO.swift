import Foundation

// Payloads of the public dictionary detail endpoints (`/content/lexemes/{id}`, `/content/grammar/{id}`, `/kanji/{id}`,
// `/kanji/words/{id}`, `/kanji/by-word/{id}`). Verified against the Go handlers and a redacted live response on 2026-10-26.
// Everything the backend marks `omitempty` is optional here; an absent field is shown as absent, never filled in.

/// `GET /content/lexemes/{id}`.
struct BJTLexemeDetailDTO: Decodable, Equatable {
    let id: String
    let headword: String
    let reading: String?
    /// Sino-Vietnamese reading of the headword's kanji ("THỰC").
    let kanjiMeaningVi: String?
    let jlptLevel: String?
    let shortMeaningVi: String?
    /// Empty for most of the current content: the short meaning is then the only gloss.
    let senses: [Sense]
    let pronunciation: [Pronunciation]

    struct Sense: Decodable, Equatable {
        let glossVi: String
        let posTag: String?
        let note: String?
    }

    struct Pronunciation: Decodable, Equatable {
        let kana: String?
        /// H/L pitch per mora, a dash before the pitch of a following particle ("LHL-L").
        let accent: String?
        let morae: [String]

        private enum CodingKeys: String, CodingKey { case kana, accent, tokenizedKana }
        private struct Token: Decodable { let type: String?; let value: String? }

        init(kana: String?, accent: String?, morae: [String]) {
            self.kana = kana
            self.accent = accent
            self.morae = morae
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kana = try container.decodeIfPresent(String.self, forKey: .kana)
            accent = try container.decodeIfPresent(String.self, forKey: .accent)
            let tokens = (try? container.decodeIfPresent([Token].self, forKey: .tokenizedKana)) ?? nil
            morae = (tokens ?? []).compactMap { $0.type == "mora" ? $0.value : nil }.filter { !$0.isEmpty }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, headword, reading, kanjiMeaningVi, jlptLevel, shortMeaningVi, senses, pronunciation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        headword = try container.decode(String.self, forKey: .headword)
        reading = try container.decodeIfPresent(String.self, forKey: .reading)
        kanjiMeaningVi = try container.decodeIfPresent(String.self, forKey: .kanjiMeaningVi)
        jlptLevel = try container.decodeIfPresent(String.self, forKey: .jlptLevel)
        shortMeaningVi = try container.decodeIfPresent(String.self, forKey: .shortMeaningVi)
        senses = (try? container.decodeIfPresent([Sense].self, forKey: .senses)) ?? []
        // The backend stores pronunciation as free JSON: an unexpected shape means "no pitch data", not a failed lookup.
        pronunciation = (try? container.decodeIfPresent([Pronunciation].self, forKey: .pronunciation)) ?? []
    }

    init(id: String, headword: String, reading: String? = nil, kanjiMeaningVi: String? = nil, jlptLevel: String? = nil,
         shortMeaningVi: String? = nil, senses: [Sense] = [], pronunciation: [Pronunciation] = []) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.kanjiMeaningVi = kanjiMeaningVi
        self.jlptLevel = jlptLevel
        self.shortMeaningVi = shortMeaningVi
        self.senses = senses
        self.pronunciation = pronunciation
    }
}

/// `GET /content/grammar/{id}`.
struct BJTGrammarDetailDTO: Decodable, Equatable {
    let id: String
    let pattern: String
    let meaningVi: String
    let jlptLevel: String?
    let category: String?
    let details: [Detail]

    struct Detail: Decodable, Equatable {
        let position: Int
        let meaningVi: String?
        let explanation: String?
        let note: String?
        let synopsis: String?
    }

    private enum CodingKeys: String, CodingKey { case id, pattern, meaningVi, jlptLevel, category, details }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        pattern = try container.decode(String.self, forKey: .pattern)
        meaningVi = try container.decode(String.self, forKey: .meaningVi)
        jlptLevel = try container.decodeIfPresent(String.self, forKey: .jlptLevel)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        details = try container.decodeIfPresent([Detail].self, forKey: .details) ?? []
    }

    init(id: String, pattern: String, meaningVi: String, jlptLevel: String? = nil, category: String? = nil, details: [Detail] = []) {
        self.id = id
        self.pattern = pattern
        self.meaningVi = meaningVi
        self.jlptLevel = jlptLevel
        self.category = category
        self.details = details
    }
}

/// `GET /kanji/{id}`.
struct BJTKanjiDetailDTO: Decodable, Equatable {
    let id: String
    let character: String
    let meaningVi: String?
    let onyomi: String?
    let kunyomi: String?
    let strokeCount: Int?
    /// 1…5, where 5 is JLPT N5 (the search endpoint maps it the same way).
    let level: Int?
    /// Rank in a frequency list: lower is more common.
    let frequency: Int?
    /// Long Vietnamese explanation; paragraphs are separated by "##".
    let detail: String?
    /// Mnemonic, with `<b>` around the key word.
    let tip: String?
    /// SHA-256 (hex) of the stroke-order SVG the API serves for this kanji.
    let strokeSvgHash: String?
    let examples: [Example]
    let components: [Component]

    /// A word written with the kanji. Its `id` belongs to the kanji's own example table, **not** to a vocabulary entry.
    struct Example: Decodable, Equatable {
        let id: String
        let word: String
        let reading: String?
        let meaningVi: String?
        let hanViet: String?
    }

    struct Component: Decodable, Equatable {
        let id: String
        let character: String
        let hanViet: String?
        let position: Int
    }

    private enum CodingKeys: String, CodingKey {
        case id, character, meaningVi, onyomi, kunyomi, strokeCount, level, frequency, detail, tip, strokeSvgHash, examples, components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        character = try container.decode(String.self, forKey: .character)
        meaningVi = try container.decodeIfPresent(String.self, forKey: .meaningVi)
        onyomi = try container.decodeIfPresent(String.self, forKey: .onyomi)
        kunyomi = try container.decodeIfPresent(String.self, forKey: .kunyomi)
        strokeCount = try container.decodeIfPresent(Int.self, forKey: .strokeCount)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        frequency = try container.decodeIfPresent(Int.self, forKey: .frequency)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        tip = try container.decodeIfPresent(String.self, forKey: .tip)
        strokeSvgHash = try container.decodeIfPresent(String.self, forKey: .strokeSvgHash)
        examples = try container.decodeIfPresent([Example].self, forKey: .examples) ?? []
        components = try container.decodeIfPresent([Component].self, forKey: .components) ?? []
    }

    init(id: String, character: String, meaningVi: String? = nil, onyomi: String? = nil, kunyomi: String? = nil,
         strokeCount: Int? = nil, level: Int? = nil, frequency: Int? = nil, detail: String? = nil, tip: String? = nil,
         strokeSvgHash: String? = nil, examples: [Example] = [], components: [Component] = []) {
        self.id = id
        self.character = character
        self.meaningVi = meaningVi
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.strokeCount = strokeCount
        self.level = level
        self.frequency = frequency
        self.detail = detail
        self.tip = tip
        self.strokeSvgHash = strokeSvgHash
        self.examples = examples
        self.components = components
    }
}

/// `GET /kanji?q=` rows: the kanji list without detail text.
struct BJTKanjiSummaryDTO: Decodable, Equatable {
    let id: String
    let character: String
    let meaningVi: String?
    let onyomi: String?
    let kunyomi: String?
    let strokeCount: Int?
    let level: Int?
    let frequency: Int?
}

/// `GET /kanji/by-word/{lexemeId}`: the kanji a vocabulary headword is written with.
struct BJTKanjiReferenceDTO: Decodable, Equatable {
    let id: String
    let character: String
    let meaningVi: String?
}

/// `GET /kanji/words/{kanjiId}`: vocabulary written with a kanji. Its `id` is a vocabulary entry id.
struct BJTKanjiWordDTO: Decodable, Equatable {
    let id: String
    let text: String
    let reading: String?
    let meaningVi: String?
}
