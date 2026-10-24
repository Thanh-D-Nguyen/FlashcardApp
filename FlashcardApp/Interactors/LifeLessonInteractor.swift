//
//  LifeLessonInteractor.swift
//
//  "Learn from Life": loads today's weather lesson from the API and saves its vocabulary into the learner's own decks.
//
//  Saving is idempotent. A card made from a lesson word has a fixed id, `life:<deck id>:<word id>`, and a word whose
//  Japanese is already on a card of the deck is never added twice, so repeating the action (a double tap, a retry after
//  an error, the next day's lesson with the same word) cannot create a duplicate. All new cards of one save are written
//  in one Realm transaction: either every card is stored or none, and only then is the save reported as done.
//

import Foundation
import RxSwift

enum LifeSaveTarget: Equatable {
    case existing(deckID: String)
    /// The learner's "Learn from Life" deck: created on the first save, then reused.
    case newLifeDeck
}

struct LifeSaveOutcome: Equatable {
    let deckID: String
    let deckName: String
    /// Words that became new cards.
    let added: [String]
    /// Words that were already in the deck, so nothing was written for them.
    let alreadyPresent: [String]
    /// The cards of this lesson's words in the deck (new and existing): what "review these cards" studies.
    let cardIDs: [String]
}

protocol LifeLessonInteractorInterface: AnyObject {
    func loadWeather(cityID: String) -> Single<LifeLesson>
    func selectedCityID(ownerKey: String) -> String
    func setSelectedCityID(_ id: String, ownerKey: String)
    func deckChoices() -> [TodayDeckChoice]
    func lifeDeckExists() -> Bool
    /// Writes the words as cards. Throws without storing anything when the data on the device cannot be written.
    func saveVocabulary(_ words: [LifeLesson.Vocabulary], target: LifeSaveTarget, language: AppLanguage) throws -> LifeSaveOutcome
}

final class LifeLessonInteractor: LifeLessonInteractorInterface {
    static let lifeDeckID = "life-learning"

    private let api: BJTLifeLessonAPIInterface
    private let decks: DeskRepositoryInterface
    private let cards: CardRepositoryInterface
    private let preferences: LifeLessonPreferencesInterface
    private let now: () -> Date

    init(api: BJTLifeLessonAPIInterface = BJTLifeLessonAPI.shared,
         decks: DeskRepositoryInterface = DeskManagement.shared,
         cards: CardRepositoryInterface = CardManagement.shared,
         preferences: LifeLessonPreferencesInterface = UserDefaultsLifeLessonPreferences.shared,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.decks = decks
        self.cards = cards
        self.preferences = preferences
        self.now = now
    }

    // MARK: Loading

    func loadWeather(cityID: String) -> Single<LifeLesson> {
        api.weatherLesson(cityID: cityID).map { try Self.lesson(from: $0, requestedCityID: cityID) }
    }

    func selectedCityID(ownerKey: String) -> String { preferences.selectedCityID(ownerKey: ownerKey) }

    func setSelectedCityID(_ id: String, ownerKey: String) { preferences.setSelectedCityID(id, ownerKey: ownerKey) }

    // MARK: Saving

    func deckChoices() -> [TodayDeckChoice] {
        decks.getAll().map { TodayDeckChoice(id: $0.id, name: $0.name, cardCount: $0.cards.count) }
    }

    func lifeDeckExists() -> Bool { decks.desk(withId: Self.lifeDeckID) != nil }

    func saveVocabulary(_ words: [LifeLesson.Vocabulary], target: LifeSaveTarget, language: AppLanguage) throws -> LifeSaveOutcome {
        var seen = Set<String>()
        let words = words.filter { seen.insert($0.id).inserted }
        let deckID: String
        switch target {
        case .existing(let id): deckID = id
        case .newLifeDeck: deckID = Self.lifeDeckID
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
            card.backText = word.meaning.resolved(language)
            card.backExtraText = word.example
            newCards.append(card)
            added.append(word.id)
            cardIDs.append(cardID)
        }

        var deckName = existing?.name ?? NSLocalizedString("Learn from Life", comment: "Name of the deck that collects words saved from life lessons")
        do {
            if let existing {
                if !newCards.isEmpty { try cards.add(newCards, toDesk: existing) }
            } else {
                let deck = DeskEntity()
                deck.id = deckID
                deck.name = deckName
                deck.description = NSLocalizedString("Words saved from Learn from Life lessons.", comment: "Description of the Learn from Life deck")
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
        return LifeSaveOutcome(deckID: deckID, deckName: deckName, added: added, alreadyPresent: present, cardIDs: cardIDs)
    }

    static func cardID(deckID: String, wordID: String) -> String { "life:\(deckID):\(wordID)" }

    // MARK: Mapping

    /// Turns the payload into a lesson, or `invalidResponse` when it breaks the contract: another schema or topic, another
    /// city than asked for, no usable exercise, or a field that cannot be read.
    static func lesson(from dto: BJTLifeLessonDTO, requestedCityID: String) throws -> LifeLesson {
        guard dto.schemaVersion == 1, dto.topic == "weather", dto.city.id == requestedCityID,
              dto.lesson.generatedBy == "deterministic_template", dto.facts.weatherCodeSystem == "WMO",
              let sourceURL = URL(string: dto.source.url), sourceURL.scheme == "https",
              let licenseStatus = LifeLesson.LicenseStatus(rawValue: dto.source.licenseStatus),
              let freshness = LifeLesson.Freshness(rawValue: dto.source.freshness),
              let observedAt = parseDate(dto.source.observedAt), let fetchedAt = parseDate(dto.source.fetchedAt),
              let expiresAt = parseDate(dto.source.expiresAt),
              !dto.lesson.sentences.isEmpty, !dto.lesson.vocabulary.isEmpty, !dto.lesson.exercises.isEmpty,
              // Int(_:) traps on a value out of range: the server bounds these, a broken one must not crash the app.
              [dto.facts.temperatureMaxC, dto.facts.temperatureMinC].allSatisfy({ $0.isFinite && abs($0) <= 150 }) else {
            throw LearnerAPIError.invalidResponse
        }
        let exercises = try dto.lesson.exercises.map { try exercise(from: $0) }
        let text = { (value: BJTLifeTextDTO) in LifeText(vi: value.vi, en: value.en) }
        let maxC = Int(dto.facts.temperatureMaxC.rounded(.toNearestOrAwayFromZero))
        let minC = Int(dto.facts.temperatureMinC.rounded(.toNearestOrAwayFromZero))
        var chips = [LifeChip(symbol: "thermometer.medium", text: String(format: NSLocalizedString("High %1$lld° · low %2$lld°", comment: ""), maxC, minC))]
        if let chance = dto.facts.precipitationProbabilityMaxPercent {
            chips.append(LifeChip(symbol: "umbrella.fill", text: String(format: NSLocalizedString("%lld%% chance of rain or snow", comment: ""), chance)))
        }
        return LifeLesson(
            id: dto.id, topic: .weather, provenance: .live, level: dto.level, cityID: dto.city.id,
            titleJapanese: dto.lesson.title.japanese, titleReading: dto.lesson.title.reading,
            title: LifeText(vi: dto.lesson.title.vi, en: dto.lesson.title.en),
            source: LifeLesson.Source(providerName: dto.source.providerName, url: sourceURL, attributionText: dto.source.attributionText,
                                      licenseName: dto.source.licenseName, licenseStatus: licenseStatus,
                                      observedAt: observedAt, fetchedAt: fetchedAt, expiresAt: expiresAt, freshness: freshness),
            facts: LifeLesson.Facts(date: dto.facts.date, weatherCode: dto.facts.weatherCode, temperatureMaxC: maxC, temperatureMinC: minC,
                                    precipitationProbabilityPercent: dto.facts.precipitationProbabilityMaxPercent),
            chips: chips, scene: nil,
            sentences: dto.lesson.sentences.map {
                LifeLesson.Sentence(id: $0.id, isAdvice: $0.basis == "advice", japanese: $0.japanese, reading: $0.reading,
                                    translation: text($0.translations), explanation: text($0.explanation))
            },
            vocabulary: dto.lesson.vocabulary.map {
                LifeLesson.Vocabulary(id: $0.id, japanese: $0.japanese, reading: $0.reading, meaning: text($0.meanings), example: $0.exampleJapanese)
            },
            exercises: exercises, estimatedMinutes: max(dto.lesson.estimatedMinutes, 1),
            cityName: LifeText(vi: dto.city.nameVi, en: dto.city.nameEn), cityNameJapanese: dto.city.nameJa)
    }

    static func exercise(from dto: BJTLifeLessonDTO.Exercise) throws -> LifeLesson.Exercise {
        let prompt = LifeText(vi: dto.prompt.vi, en: dto.prompt.en)
        let explanation = LifeText(vi: dto.explanation.vi, en: dto.explanation.en)
        switch dto.kind {
        case "recall_text":
            let accepted = (dto.acceptedAnswers ?? []).filter { !LifeAnswerChecker.normalize($0).isEmpty }
            guard !accepted.isEmpty else { throw LearnerAPIError.invalidResponse }
            return .recall(id: dto.id, promptJapanese: dto.promptJapanese, prompt: prompt, acceptedAnswers: accepted, explanation: explanation)
        case "choice":
            let choices = (dto.choices ?? []).map { LifeLesson.Choice(id: $0.id, text: $0.text) }
            guard choices.count >= 2, Set(choices.map(\.id)).count == choices.count,
                  let correct = dto.correctChoiceId, choices.contains(where: { $0.id == correct }) else { throw LearnerAPIError.invalidResponse }
            return .choice(id: dto.id, promptJapanese: dto.promptJapanese, prompt: prompt, choices: choices, correctChoiceID: correct, explanation: explanation)
        default:
            throw LearnerAPIError.invalidResponse
        }
    }

    /// The server sends RFC 3339 with an offset, with or without fractional seconds.
    static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: text) ?? fractional.date(from: text)
    }
}
