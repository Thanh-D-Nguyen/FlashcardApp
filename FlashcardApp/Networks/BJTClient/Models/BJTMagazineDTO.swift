import Foundation

/// `GET /api/magazine` and `GET /api/magazine/{slug}` (backend `handler_career_content_gamification_misc.go`, public, no token).
/// Field names are the JSON keys the Go handler sends, checked against the running API on 2026-10-29.
///
/// The article body (`contentJson`) differs per kind and is written by a generator, so everything in it is optional and a
/// field of the wrong type is dropped instead of failing the whole article. Lists inside an article drop only the broken element.

struct BJTMagazineListDTO: Decodable, Equatable {
    let data: [BJTMagazineSummaryDTO]
    let limit: Int
    let page: Int
    let total: Int
}

struct BJTMagazineSummaryDTO: Decodable, Equatable {
    struct Word: Decodable, Equatable {
        let word: String
        let reading: String?
        let meaning: String?
    }

    let id: String
    let slug: String
    let widgetKind: String
    let titleJp: String
    let titleVi: String
    let summaryVi: String?
    let jlptLevel: String?
    /// A calendar day in Japan, `yyyy-MM-dd`.
    let publishDate: String
    let vocabWords: [Word]

    private enum CodingKeys: String, CodingKey {
        case id, slug, widgetKind, titleJp, titleVi, summaryVi, jlptLevel, publishDate, vocabWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        widgetKind = try container.decode(String.self, forKey: .widgetKind)
        titleJp = try container.decode(String.self, forKey: .titleJp)
        titleVi = try container.decode(String.self, forKey: .titleVi)
        summaryVi = try? container.decodeIfPresent(String.self, forKey: .summaryVi)
        jlptLevel = try? container.decodeIfPresent(String.self, forKey: .jlptLevel)
        publishDate = try container.decode(String.self, forKey: .publishDate)
        vocabWords = (try? container.decodeIfPresent(LossyArray<Word>.self, forKey: .vocabWords))?.elements ?? []
    }
}

struct BJTMagazineArticleDTO: Decodable, Equatable {
    struct Vocabulary: Decodable, Equatable {
        let id: String?
        let wordJp: String
        let reading: String?
        let meaningVi: String?
        let jlptLevel: String?
        let exampleJp: String?
        let exampleVi: String?
    }

    struct Quiz: Decodable, Equatable {
        struct Option: Decodable, Equatable {
            let label: String
            let isCorrect: Bool
        }

        let questionJp: String
        let questionVi: String?
        let options: [Option]
        let explanationJp: String?
        let explanationVi: String?

        private enum CodingKeys: String, CodingKey { case questionJp, questionVi, options, explanationJp, explanationVi }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            questionJp = try container.decode(String.self, forKey: .questionJp)
            questionVi = try? container.decodeIfPresent(String.self, forKey: .questionVi)
            options = try container.decode(LossyArray<Option>.self, forKey: .options).elements
            explanationJp = try? container.decodeIfPresent(String.self, forKey: .explanationJp)
            explanationVi = try? container.decodeIfPresent(String.self, forKey: .explanationVi)
        }
    }

    let id: String
    let slug: String
    let widgetKind: String
    let titleJp: String
    let titleVi: String
    let summaryJp: String?
    let summaryVi: String?
    let jlptLevel: String?
    /// An instant (`2026-10-26T00:00:00Z`); its date part is the publishing day in Japan.
    let publishedAt: String?
    let content: BJTMagazineContentDTO?
    let vocabItems: [Vocabulary]
    let quizzes: [Quiz]

    private enum CodingKeys: String, CodingKey {
        case id, slug, widgetKind, titleJp, titleVi, summaryJp, summaryVi, jlptLevel, publishedAt, contentJson, vocabItems, quizzes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        widgetKind = try container.decode(String.self, forKey: .widgetKind)
        titleJp = try container.decode(String.self, forKey: .titleJp)
        titleVi = try container.decode(String.self, forKey: .titleVi)
        summaryJp = try? container.decodeIfPresent(String.self, forKey: .summaryJp)
        summaryVi = try? container.decodeIfPresent(String.self, forKey: .summaryVi)
        jlptLevel = try? container.decodeIfPresent(String.self, forKey: .jlptLevel)
        publishedAt = try? container.decodeIfPresent(String.self, forKey: .publishedAt)
        content = try? container.decodeIfPresent(BJTMagazineContentDTO.self, forKey: .contentJson)
        vocabItems = (try? container.decodeIfPresent(LossyArray<Vocabulary>.self, forKey: .vocabItems))?.elements ?? []
        quizzes = (try? container.decodeIfPresent(LossyArray<Quiz>.self, forKey: .quizzes))?.elements ?? []
    }
}

/// The union of the fields the generators write for every kind. A kind simply leaves the others out.
struct BJTMagazineContentDTO: Decodable, Equatable {
    struct DialogueLine: Decodable, Equatable {
        let speaker: String?
        let text: String
        let textVi: String?

        private enum CodingKeys: String, CodingKey { case speaker, text, textJp, textVi }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            speaker = try? container.decodeIfPresent(String.self, forKey: .speaker)
            // The generator writes `text`; the website's reader looks for `textJp`. Accept both.
            if let text = try? container.decodeIfPresent(String.self, forKey: .text) {
                self.text = text
            } else {
                text = try container.decode(String.self, forKey: .textJp)
            }
            textVi = try? container.decodeIfPresent(String.self, forKey: .textVi)
        }
    }

    struct Fortune: Decodable, Equatable {
        let sign: String
        let signVi: String?
        let signReading: String?
        let fortune: String?
        let fortuneVi: String?
        let message: String?
        let messageVi: String?
        let luckyColor: String?
        let luckyNumber: Int?

        private enum CodingKeys: String, CodingKey {
            case sign, signVi, signReading, fortune, fortuneJp, fortuneVi, message, messageVi, luckyColor, luckyNumber
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sign = try container.decode(String.self, forKey: .sign)
            signVi = try? container.decodeIfPresent(String.self, forKey: .signVi)
            signReading = try? container.decodeIfPresent(String.self, forKey: .signReading)
            fortune = (try? container.decodeIfPresent(String.self, forKey: .fortune))
                ?? (try? container.decodeIfPresent(String.self, forKey: .fortuneJp))
            fortuneVi = try? container.decodeIfPresent(String.self, forKey: .fortuneVi)
            message = try? container.decodeIfPresent(String.self, forKey: .message)
            messageVi = try? container.decodeIfPresent(String.self, forKey: .messageVi)
            luckyColor = try? container.decodeIfPresent(String.self, forKey: .luckyColor)
            luckyNumber = try? container.decodeIfPresent(Int.self, forKey: .luckyNumber)
        }
    }

    // Reading passage
    let introduction: String?
    let introductionVi: String?
    let paragraphsJp: [String]
    let paragraphsVi: [String]
    // Business phrase
    let phrase: String?
    let phraseReading: String?
    let literalMeaning: String?
    let formality: String?
    let usageNote: String?
    let usageNoteVi: String?
    let situations: [String]
    let situationsVi: [String]
    let dialogue: [DialogueLine]
    // Weather
    let city: String?
    let description: String?
    let descriptionVi: String?
    let weatherIcon: String?
    let recommendation: String?
    let recommendationVi: String?
    let highTemp: Double?
    let lowTemp: Double?
    let humidity: Double?
    let uvIndex: Double?
    // Horoscope
    let zodiacFortunes: [Fortune]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        func value<T: Decodable>(_ name: String) -> T? { try? container.decodeIfPresent(T.self, forKey: Key(name)) }
        func list<T: Decodable>(_ name: String) -> [T] { (try? container.decodeIfPresent(LossyArray<T>.self, forKey: Key(name)))?.elements ?? [] }
        introduction = value("introduction")
        introductionVi = value("introductionVi")
        paragraphsJp = list("paragraphsJp")
        paragraphsVi = list("paragraphsVi")
        phrase = value("phrase")
        phraseReading = value("phraseReading")
        literalMeaning = value("literalMeaning")
        formality = value("formality")
        usageNote = value("usageNote")
        usageNoteVi = value("usageNoteVi")
        situations = list("situations")
        situationsVi = list("situationsVi")
        dialogue = list("dialogue")
        city = value("city")
        description = value("description")
        descriptionVi = value("descriptionVi")
        weatherIcon = value("weatherIcon")
        recommendation = value("recommendation")
        recommendationVi = value("recommendationVi")
        highTemp = value("highTemp")
        lowTemp = value("lowTemp")
        humidity = value("humidity")
        uvIndex = value("uvIndex")
        zodiacFortunes = list("zodiacFortunes")
    }
}

/// A JSON array whose broken elements are skipped instead of failing the whole array.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    /// Decodes anything without reading it, which is what moves the container past a broken element.
    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                // A failed decode does not advance the container: step over the element.
                _ = try? container.decode(Skip.self)
            }
        }
        elements = result
    }
}
