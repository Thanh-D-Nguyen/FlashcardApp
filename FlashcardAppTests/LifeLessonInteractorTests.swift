import RealmSwift
import XCTest
@testable import FlashcardApp

/// Saving lesson words into the learner's decks, against a real (in-memory) Realm: what ends up stored, and what never does.
final class LifeLessonInteractorTests: XCTestCase {
    private var realm: Realm!
    private var decks: DeskManagement!
    private var interactor: LifeLessonInteractor!
    private var lesson: LifeLesson!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "life-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        decks = DeskManagement()
        interactor = LifeLessonInteractor(decks: decks, cards: CardManagement.shared)
        lesson = try LifeLessonFixtures.lesson()
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
        realm = nil
    }

    private func words(_ ids: String...) -> [LifeLesson.Vocabulary] { lesson.vocabulary.filter { ids.contains($0.id) } }

    private func makeDeck(id: String = "deck-1", cards: [(String, String)] = []) throws {
        let deck = DeskEntity()
        deck.id = id
        deck.name = "My words"
        deck.cards = cards.map { front, back in
            let card = CardEntity()
            card.id = UUID().uuidString
            card.frontText = front
            card.backText = back
            return card
        }
        try decks.add(deck)
    }

    func test_theFirstSaveCreatesTheLearnFromLifeDeckWithTheWordsAsCards() throws {
        let outcome = try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .newLifeDeck, language: .vietnamese)

        XCTAssertEqual(outcome.deckID, "life-learning")
        XCTAssertEqual(outcome.added, ["weather:rain", "weather:umbrella"])
        XCTAssertTrue(outcome.alreadyPresent.isEmpty)
        let deck = try XCTUnwrap(decks.desk(withId: "life-learning"))
        XCTAssertEqual(deck.name, NSLocalizedString("Learn from Life", comment: ""))
        XCTAssertEqual(deck.cards.map(\.id), ["life:life-learning:weather:rain", "life:life-learning:weather:umbrella"])
        let rain = try XCTUnwrap(deck.cards.first)
        XCTAssertEqual(rain.frontText, "雨")
        XCTAssertEqual(rain.frontExtraText, "あめ", "The reading goes under the Japanese side")
        XCTAssertEqual(rain.backText, "mưa")
        XCTAssertEqual(rain.backExtraText, "今日の東京の天気は雨です。", "The sentence the word came from")
        XCTAssertEqual(outcome.cardIDs, deck.cards.map(\.id))
    }

    func test_theMeaningFollowsTheLanguageTheLearnerUses() throws {
        _ = try interactor.saveVocabulary(words("weather:rain"), target: .newLifeDeck, language: .english)
        XCTAssertEqual(decks.desk(withId: "life-learning")?.cards.first?.backText, "rain")
        _ = try interactor.saveVocabulary(words("weather:umbrella"), target: .newLifeDeck, language: .japanese)
        XCTAssertEqual(decks.desk(withId: "life-learning")?.cards.last?.backText, "umbrella", "The Japanese UI shows English meanings")
    }

    func test_savingTheSameWordsAgainWritesNothing() throws {
        let first = try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .newLifeDeck, language: .vietnamese)
        let second = try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .newLifeDeck, language: .vietnamese)

        XCTAssertTrue(second.added.isEmpty)
        XCTAssertEqual(second.alreadyPresent, ["weather:rain", "weather:umbrella"])
        XCTAssertEqual(second.cardIDs, first.cardIDs, "The existing cards are still what 'study these cards' opens")
        XCTAssertEqual(decks.desk(withId: "life-learning")?.cards.count, 2)
        XCTAssertEqual(realm.objects(RCard.self).count, 2)
    }

    func test_aRepeatedWordInOneSaveBecomesOneCard() throws {
        let outcome = try interactor.saveVocabulary(words("weather:rain") + words("weather:rain"), target: .newLifeDeck, language: .vietnamese)
        XCTAssertEqual(outcome.added, ["weather:rain"])
        XCTAssertEqual(realm.objects(RCard.self).count, 1)
    }

    func test_aWordAlreadyTypedByHandIsNotDuplicated() throws {
        try makeDeck(cards: [("雨", "mưa (tự thêm)")])
        let outcome = try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .existing(deckID: "deck-1"), language: .vietnamese)

        XCTAssertEqual(outcome.added, ["weather:umbrella"])
        XCTAssertEqual(outcome.alreadyPresent, ["weather:rain"])
        let deck = try XCTUnwrap(decks.desk(withId: "deck-1"))
        XCTAssertEqual(deck.cards.map(\.frontText), ["雨", "傘"], "The learner's own card is kept as it was")
        XCTAssertEqual(deck.cards.first?.backText, "mưa (tự thêm)")
        XCTAssertEqual(outcome.cardIDs.count, 2)
    }

    func test_wordsJoinAnExistingDeckWithoutTouchingItsCards() throws {
        try makeDeck(cards: [("犬", "chó"), ("猫", "mèo")])
        let outcome = try interactor.saveVocabulary(words("weather:max-temperature"), target: .existing(deckID: "deck-1"), language: .vietnamese)
        let deck = try XCTUnwrap(decks.desk(withId: "deck-1"))
        XCTAssertEqual(deck.cards.map(\.frontText), ["犬", "猫", "最高気温"])
        XCTAssertEqual(deck.cards.last?.id, "life:deck-1:weather:max-temperature")
        XCTAssertEqual(outcome.deckName, "My words")
    }

    func test_theLifeDeckIsReusedOnceItExists() throws {
        _ = try interactor.saveVocabulary(words("weather:rain"), target: .newLifeDeck, language: .vietnamese)
        XCTAssertTrue(interactor.lifeDeckExists())
        let outcome = try interactor.saveVocabulary(words("weather:umbrella"), target: .newLifeDeck, language: .vietnamese)
        XCTAssertEqual(outcome.added, ["weather:umbrella"])
        XCTAssertEqual(realm.objects(RDesk.self).count, 1, "No second Learn from Life deck")
        XCTAssertEqual(decks.desk(withId: "life-learning")?.cards.count, 2)
    }

    func test_aDeckThatNoLongerExistsFailsWithoutCreatingAnything() {
        XCTAssertThrowsError(try interactor.saveVocabulary(words("weather:rain"), target: .existing(deckID: "gone"), language: .vietnamese))
        XCTAssertEqual(realm.objects(RDesk.self).count, 0)
        XCTAssertEqual(realm.objects(RCard.self).count, 0)
    }

    func test_theCardsOfOneSaveAreStoredAllOrNone() throws {
        try makeDeck()
        // A card id that is already used elsewhere makes the whole batch fail, with the others not written.
        let taken = CardEntity()
        taken.id = "life:deck-1:weather:umbrella"
        taken.frontText = "x"
        taken.backText = "y"
        let other = DeskEntity()
        other.id = "deck-2"
        other.name = "Other"
        other.cards = [taken]
        try decks.add(other)

        XCTAssertThrowsError(try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .existing(deckID: "deck-1"), language: .vietnamese))
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.count, 0, "'rain' was not stored when 'umbrella' could not be")
    }

    func test_aFailureOfTheDeviceStoreIsReportedAndNothingIsClaimed() throws {
        final class FailingCards: CardRepositoryInterface {
            func add(_ card: CardEntity, toDesk desk: DeskEntity) throws { throw AppError.databaseWriteFailed("disk full") }
            func add(_ cards: [CardEntity], toDesk desk: DeskEntity) throws { throw AppError.databaseWriteFailed("disk full") }
        }
        try makeDeck()
        let failing = LifeLessonInteractor(decks: decks, cards: FailingCards())
        XCTAssertThrowsError(try failing.saveVocabulary(words("weather:rain"), target: .existing(deckID: "deck-1"), language: .vietnamese)) {
            guard let error = $0 as? FlashcardApp.AppError, case .databaseWriteFailed = error else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.count, 0)
    }

    func test_savedCardsAreStudiedLikeAnyOther() throws {
        let outcome = try interactor.saveVocabulary(words("weather:rain", "weather:umbrella"), target: .newLifeDeck, language: .vietnamese)
        let choices = interactor.deckChoices()
        XCTAssertEqual(choices.map(\.id), ["life-learning"])
        XCTAssertEqual(choices.first?.cardCount, 2)
        // The review planner sees them: a deck with unseen cards is offered for practice, listing exactly these cards.
        let studyCards = StudyCard.self
        let entity = try XCTUnwrap(decks.desk(withId: "life-learning"))
        XCTAssertEqual(entity.cards.map { studyCards.init(entity: $0).id }, outcome.cardIDs)
    }
}
