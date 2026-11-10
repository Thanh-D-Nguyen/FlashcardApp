//
//  MagazineInteractor.swift
//
//  Magazine: loads the article list and one article from the public API, and saves an article's vocabulary into the
//  learner's own decks.
//
//  Saving is idempotent like the life lessons': a card made from an article word has a fixed id,
//  `magazine:<deck id>:<word id>`, and a word whose Japanese is already on a card of the deck is never added twice, so a
//  double tap or a retry cannot create a duplicate. All new cards of one save are written in one Realm transaction.
//

import Foundation
import RxSwift

enum MagazineSaveTarget: Equatable {
    case existing(deckID: String)
    /// The learner's "Magazine" deck: created on the first save, then reused.
    case newMagazineDeck
}

struct MagazineSaveOutcome: Equatable {
    let deckID: String
    let deckName: String
    /// Words that became new cards.
    let added: [String]
    /// Words that were already in the deck, so nothing was written for them.
    let alreadyPresent: [String]
    /// The cards of these words in the deck (new and existing): what "review these cards" studies.
    let cardIDs: [String]
}

protocol MagazineInteractorInterface: AnyObject {
    func loadPage(kind: MagazineKind?, page: Int) -> Single<MagazinePage>
    func loadArticle(slug: String) -> Single<MagazineArticle>
    func deckChoices() -> [TodayDeckChoice]
    func magazineDeckExists() -> Bool
    /// Writes the words as cards. Throws without storing anything when the data on the device cannot be written.
    func saveVocabulary(_ words: [MagazineArticle.Vocabulary], target: MagazineSaveTarget) throws -> MagazineSaveOutcome
}

final class MagazineInteractor: MagazineInteractorInterface {
    static let magazineDeckID = "magazine"
    static let pageSize = 20

    private let api: BJTMagazineAPIInterface
    private let decks: DeskRepositoryInterface
    private let cards: CardRepositoryInterface
    private let now: () -> Date

    init(api: BJTMagazineAPIInterface = BJTMagazineAPI.shared,
         decks: DeskRepositoryInterface = DeskManagement.shared,
         cards: CardRepositoryInterface = CardManagement.shared,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.decks = decks
        self.cards = cards
        self.now = now
    }

    // MARK: Loading

    func loadPage(kind: MagazineKind?, page: Int) -> Single<MagazinePage> {
        api.articles(kind: kind, page: page, limit: Self.pageSize).map { Self.page(from: $0, requestedPage: page) }
    }

    func loadArticle(slug: String) -> Single<MagazineArticle> {
        api.article(slug: slug).map { try Self.article(from: $0) }
    }

    // MARK: Saving

    func deckChoices() -> [TodayDeckChoice] {
        decks.getAll().map { TodayDeckChoice(id: $0.id, name: $0.name, cardCount: $0.cards.count) }
    }

    func magazineDeckExists() -> Bool { decks.desk(withId: Self.magazineDeckID) != nil }

    func saveVocabulary(_ words: [MagazineArticle.Vocabulary], target: MagazineSaveTarget) throws -> MagazineSaveOutcome {
        var seen = Set<String>()
        let words = words.filter { seen.insert($0.id).inserted }
        let deckID: String
        switch target {
        case .existing(let id): deckID = id
        case .newMagazineDeck: deckID = Self.magazineDeckID
        }

        let existing = decks.desk(withId: deckID)
        if existing == nil, case .existing = target { throw AppError.entityNotFound(NSLocalizedString("deck", comment: "")) }

        var added: [String] = [], present: [String] = [], cardIDs: [String] = []
        var newCards: [CardEntity] = []
        for word in words {
            let cardID = Self.cardID(deckID: deckID, wordID: word.id)
            if let match = existing?.cards.first(where: { $0.id == cardID || $0.frontText == word.japanese }) {
                present.append(word.id)
                cardIDs.append(match.id)
                continue
            }
            let card = CardEntity()
            card.id = cardID
            card.frontText = word.japanese
            card.frontExtraText = word.reading
            card.backText = word.meaning
            card.backExtraText = word.example ?? ""
            newCards.append(card)
            added.append(word.id)
            cardIDs.append(cardID)
        }

        var deckName = existing?.name ?? NSLocalizedString("Magazine", comment: "Name of the deck that collects words saved from magazine articles")
        do {
            if let existing {
                if !newCards.isEmpty { try cards.add(newCards, toDesk: existing) }
            } else {
                let deck = DeskEntity()
                deck.id = deckID
                deck.name = deckName
                deck.description = NSLocalizedString("Words saved from Magazine articles.", comment: "Description of the Magazine deck")
                deck.cards = newCards
                deck.date = now()
                try decks.add(deck)
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        deckName = decks.desk(withId: deckID)?.name ?? deckName
        return MagazineSaveOutcome(deckID: deckID, deckName: deckName, added: added, alreadyPresent: present, cardIDs: cardIDs)
    }

    static func cardID(deckID: String, wordID: String) -> String { "magazine:\(deckID):\(wordID)" }

    // MARK: Mapping

    /// Articles of a kind the app shows. The server clamps a page past the end to the last page, so a reply for another page
    /// than the one asked for means there is nothing more (and its items are not repeated).
    static func page(from dto: BJTMagazineListDTO, requestedPage: Int) -> MagazinePage {
        guard dto.page == requestedPage else { return MagazinePage(items: [], page: requestedPage, hasMore: false) }
        var seen = Set<String>()
        let items = dto.data.compactMap { summary(from: $0) }.filter { seen.insert($0.slug).inserted }
        let hasMore = dto.limit > 0 && dto.page * dto.limit < dto.total
        return MagazinePage(items: items, page: dto.page, hasMore: hasMore)
    }

    static func summary(from dto: BJTMagazineSummaryDTO) -> MagazineSummary? {
        guard let kind = MagazineKind(widgetKind: dto.widgetKind), let titleJapanese = clean(dto.titleJp), !dto.slug.isEmpty else { return nil }
        return MagazineSummary(
            id: dto.id, slug: dto.slug, kind: kind,
            titleJapanese: titleJapanese, titleVietnamese: clean(dto.titleVi) ?? "",
            summary: clean(dto.summaryVi), level: clean(dto.jlptLevel), day: MagazineDay(key: dto.publishDate),
            words: dto.vocabWords.compactMap { clean($0.word) })
    }

    /// Turns the payload into an article, or `invalidResponse` when it cannot be shown: a kind the app does not have, or no title.
    static func article(from dto: BJTMagazineArticleDTO) throws -> MagazineArticle {
        guard let kind = MagazineKind(widgetKind: dto.widgetKind), let titleJapanese = clean(dto.titleJp), !dto.slug.isEmpty else {
            throw LearnerAPIError.invalidResponse
        }
        let vocabulary: [MagazineArticle.Vocabulary] = dto.vocabItems.enumerated().compactMap { index, item in
            guard let japanese = clean(item.wordJp), let meaning = clean(item.meaningVi) else { return nil }
            return MagazineArticle.Vocabulary(
                id: clean(item.id) ?? "\(dto.slug)-\(index)", japanese: japanese, reading: clean(item.reading) ?? "", meaning: meaning,
                level: clean(item.jlptLevel), example: clean(item.exampleJp), exampleMeaning: clean(item.exampleVi))
        }
        let questions: [MagazineArticle.Question] = dto.quizzes.compactMap { quiz in
            let options = quiz.options.compactMap { option in clean(option.label).map { MagazineArticle.Option(text: $0, isCorrect: option.isCorrect) } }
            // A question needs a choice to make and exactly one right answer.
            guard let prompt = clean(quiz.questionJp), options.count >= 2, options.filter(\.isCorrect).count == 1 else { return nil }
            return MagazineArticle.Question(promptJapanese: prompt, prompt: clean(quiz.questionVi), options: options,
                                            explanationJapanese: clean(quiz.explanationJp), explanation: clean(quiz.explanationVi))
        }
        return MagazineArticle(
            id: dto.id, slug: dto.slug, kind: kind, titleJapanese: titleJapanese, titleVietnamese: clean(dto.titleVi) ?? "",
            summaryJapanese: clean(dto.summaryJp), summaryVietnamese: clean(dto.summaryVi), level: clean(dto.jlptLevel),
            blocks: dto.content.map(blocks(from:)) ?? [], vocabulary: vocabulary, questions: questions)
    }

    /// The parts of the body that are present, in reading order. A kind never has to be checked: a field that is not there
    /// simply gives no block.
    static func blocks(from content: BJTMagazineContentDTO) -> [MagazineArticle.Block] {
        var blocks: [MagazineArticle.Block] = []
        if let phrase = clean(content.phrase) {
            blocks.append(.phrase(japanese: phrase, reading: clean(content.phraseReading), literalMeaning: clean(content.literalMeaning),
                                  formality: formality(content.formality)))
        }
        if let description = clean(content.description) {
            blocks.append(.weather(MagazineArticle.Weather(
                city: clean(content.city), descriptionJapanese: description, description: clean(content.descriptionVi),
                symbol: weatherSymbol(content.weatherIcon), highC: whole(content.highTemp), lowC: whole(content.lowTemp),
                humidityPercent: whole(content.humidity), uvIndex: whole(content.uvIndex),
                adviceJapanese: clean(content.recommendation), advice: clean(content.recommendationVi))))
        }
        if content.paragraphsJp.contains(where: { clean($0) != nil }) {
            for (index, paragraph) in content.paragraphsJp.enumerated() {
                guard let japanese = clean(paragraph) else { continue }
                blocks.append(.passage(japanese: japanese, meaning: index < content.paragraphsVi.count ? clean(content.paragraphsVi[index]) : nil))
            }
        } else if clean(content.introduction) != nil || clean(content.introductionVi) != nil {
            blocks.append(.passage(japanese: clean(content.introduction), meaning: clean(content.introductionVi)))
        }
        let lines = content.dialogue.compactMap { line in
            clean(line.text).map { MagazineArticle.DialogueLine(speaker: clean(line.speaker), japanese: $0, meaning: clean(line.textVi)) }
        }
        if !lines.isEmpty { blocks.append(.dialogue(lines)) }
        if clean(content.usageNote) != nil || clean(content.usageNoteVi) != nil {
            blocks.append(.usage(japanese: clean(content.usageNote), meaning: clean(content.usageNoteVi)))
        }
        let situations: [MagazineArticle.Situation] = content.situations.enumerated().compactMap { index, text in
            clean(text).map { MagazineArticle.Situation(japanese: $0, meaning: index < content.situationsVi.count ? clean(content.situationsVi[index]) : nil) }
        }
        if !situations.isEmpty { blocks.append(.situations(situations)) }
        let fortunes: [MagazineArticle.Fortune] = content.zodiacFortunes.compactMap { item in
            guard let sign = clean(item.sign) else { return nil }
            return MagazineArticle.Fortune(
                sign: sign, signMeaning: clean(item.signVi), reading: clean(item.signReading), fortune: clean(item.fortune),
                fortuneMeaning: clean(item.fortuneVi), message: clean(item.message), messageMeaning: clean(item.messageVi),
                luckyColor: clean(item.luckyColor), luckyNumber: item.luckyNumber)
        }
        if !fortunes.isEmpty { blocks.append(.horoscope(fortunes)) }
        return blocks
    }

    static func formality(_ value: String?) -> MagazineArticle.Formality? {
        switch value?.lowercased() {
        case "polite": return .polite
        case "casual": return .casual
        case "formal", "honorific": return .formal
        case "humble": return .humble
        default: return nil
        }
    }

    /// SF Symbol for the generator's icon name (`cloudy_rain`, `sunny` …); a general weather symbol when it is not known.
    static func weatherSymbol(_ icon: String?) -> String {
        let name = icon?.lowercased() ?? ""
        switch true {
        case name.contains("thunder"), name.contains("storm"): return "cloud.bolt.rain.fill"
        case name.contains("snow"): return "cloud.snow.fill"
        case name.contains("fog"), name.contains("mist"): return "cloud.fog.fill"
        case name.contains("cloud") && name.contains("rain"): return "cloud.drizzle.fill"
        case name.contains("rain"), name.contains("shower"): return "cloud.rain.fill"
        case name.contains("wind"): return "wind"
        case name.contains("partly"): return "cloud.sun.fill"
        case name.contains("cloud"): return "cloud.fill"
        case name.contains("sun"), name.contains("clear"), name.contains("fine"): return "sun.max.fill"
        default: return "cloud.sun.fill"
        }
    }

    /// A temperature or percentage as a whole number; nil when missing or out of any plausible range (a broken value must not trap `Int(_:)`).
    private static func whole(_ value: Double?) -> Int? {
        guard let value, value.isFinite, abs(value) <= 1000 else { return nil }
        return Int(value.rounded(.toNearestOrAwayFromZero))
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
