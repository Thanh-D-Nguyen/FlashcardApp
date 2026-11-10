import Foundation

/// A Loto article. Every field is optional on the wire: a missing or broken part is left out instead of failing the article.
struct BJTLotoArticleDTO: Decodable, Equatable {
    struct Disclaimer: Decodable, Equatable {
        let en: String?
        let ja: String?
        let vi: String?
    }

    struct Source: Decodable, Equatable {
        let officialVerificationUrl: String?
    }

    struct Shape: Decodable, Equatable {
        let odd: Int?, even: Int?, low: Int?, high: Int?, sum: Int?, consecutivePairs: Int?
    }

    struct Number: Decodable, Equatable {
        let number: Int
        let count: Int?
        let gap: Int?
        let tags: [String]

        private enum CodingKeys: String, CodingKey { case number, count, gap, tags }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            number = try container.decode(Int.self, forKey: .number)
            count = try? container.decodeIfPresent(Int.self, forKey: .count)
            gap = try? container.decodeIfPresent(Int.self, forKey: .gap)
            tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        }
    }

    struct Signals: Decodable, Equatable {
        let hotNumbers: [Int]?
        let coldNumbers: [Int]?
        let overdueNumbers: [Int]?
    }

    struct Explanation: Decodable, Equatable {
        let shape: Shape?
        let numbers: [Number]
        let signals: Signals?
        let historyDraws: Int?

        private enum CodingKeys: String, CodingKey { case shape, numbers, signals, historyDraws }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            shape = try? container.decodeIfPresent(Shape.self, forKey: .shape)
            numbers = (try? container.decodeIfPresent(LossyArray<Number>.self, forKey: .numbers))?.elements ?? []
            signals = try? container.decodeIfPresent(Signals.self, forKey: .signals)
            historyDraws = try? container.decodeIfPresent(Int.self, forKey: .historyDraws)
        }
    }

    struct Set: Decodable, Equatable {
        let rank: Int?
        let score: Double?
        let mainNumbers: [Int]
        let bonusNumbers: [Int]
        let explanation: Explanation?

        private enum CodingKeys: String, CodingKey { case rank, score, mainNumbers, bonusNumbers, explanation }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rank = try? container.decodeIfPresent(Int.self, forKey: .rank)
            score = try? container.decodeIfPresent(Double.self, forKey: .score)
            mainNumbers = try container.decode([Int].self, forKey: .mainNumbers)
            bonusNumbers = (try? container.decodeIfPresent([Int].self, forKey: .bonusNumbers)) ?? []
            explanation = try? container.decodeIfPresent(Explanation.self, forKey: .explanation)
        }
    }

    struct Content: Decodable, Equatable {
        let game: String?
        let sets: [Set]
        let drawTime: String?
        let drawNumber: Int?
        let drawNumberEstimated: Bool?
        let targetDrawDate: String?
        let scheduleVi: String?
        let scheduleJp: String?
        let scheduleEn: String?
        let riskDisclaimer: Disclaimer?
        let source: Source?
        let algorithmWeights: [String: Double]

        private enum CodingKeys: String, CodingKey {
            case game, sets, drawTime, drawNumber, drawNumberEstimated, targetDrawDate, scheduleVi, scheduleJp, scheduleEn
            case riskDisclaimer, source, algorithmWeights
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            game = try? container.decodeIfPresent(String.self, forKey: .game)
            sets = (try? container.decodeIfPresent(LossyArray<Set>.self, forKey: .sets))?.elements ?? []
            drawTime = try? container.decodeIfPresent(String.self, forKey: .drawTime)
            drawNumber = try? container.decodeIfPresent(Int.self, forKey: .drawNumber)
            drawNumberEstimated = try? container.decodeIfPresent(Bool.self, forKey: .drawNumberEstimated)
            targetDrawDate = try? container.decodeIfPresent(String.self, forKey: .targetDrawDate)
            scheduleVi = try? container.decodeIfPresent(String.self, forKey: .scheduleVi)
            scheduleJp = try? container.decodeIfPresent(String.self, forKey: .scheduleJp)
            scheduleEn = try? container.decodeIfPresent(String.self, forKey: .scheduleEn)
            riskDisclaimer = try? container.decodeIfPresent(Disclaimer.self, forKey: .riskDisclaimer)
            source = try? container.decodeIfPresent(Source.self, forKey: .source)
            algorithmWeights = (try? container.decodeIfPresent([String: Double].self, forKey: .algorithmWeights)) ?? [:]
        }
    }

    let id: String
    let slug: String
    let widgetKind: String
    let publishedAt: String?
    let contentJson: Content?

    private enum CodingKeys: String, CodingKey { case id, slug, widgetKind, publishedAt, contentJson }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        widgetKind = try container.decode(String.self, forKey: .widgetKind)
        publishedAt = try? container.decodeIfPresent(String.self, forKey: .publishedAt)
        contentJson = try? container.decodeIfPresent(Content.self, forKey: .contentJson)
    }
}
