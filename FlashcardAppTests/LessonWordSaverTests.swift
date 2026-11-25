import RealmSwift
import XCTest
@testable import FlashcardApp

/// Saving a lesson's words as flashcards, against a real in-memory Realm: the learner's chosen deck only, both sides present,
/// no duplicates, and the backend's lesson id kept in the card id.
final class LessonWordSaverTests: XCTestCase {
    private var realm: Realm!
    private var decks: DeskManagement!
    private var saver: LessonWordSaver!
    private let slug = "j5-01-greetings-intro"
    private let hello = LessonWord(japanese: "初めまして", reading: "はじめまして", meaning: "rất hân hạnh")
    private let colleague = LessonWord(japanese: "同僚", reading: "どうりょう", meaning: "đồng nghiệp")

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "lesson-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        decks = DeskManagement()
        saver = LessonWordSaver(decks: decks, cards: CardManagement.shared)
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
        realm = nil
    }

    private func makeDeck(id: String = "deck-1", cards: [(id: String, front: String, back: String)] = []) throws {
        let deck = DeskEntity()
        deck.id = id
        deck.name = "My words"
        deck.cards = cards.map { item in
            let card = CardEntity()
            card.id = item.id
            card.frontText = item.front
            card.backText = item.back
            return card
        }
        try decks.add(deck)
    }

    private func cards(in id: String) -> [RCard] { Array(realm.object(ofType: RDesk.self, forPrimaryKey: id)?.cards ?? List<RCard>()) }

    func test_aWordBecomesAJapaneseFrontCardWithItsReadingAndMeaningInTheChosenDeck() throws {
        try makeDeck()
        let outcome = try saver.save([hello], fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual(outcome, LessonWordSaveOutcome(deckID: "deck-1", deckName: "My words", added: 1, alreadyThere: 0, skipped: 0))
        let card = try XCTUnwrap(cards(in: "deck-1").first)
        XCTAssertEqual([card.frontText, card.frontExtraText, card.backText], ["初めまして", "はじめまして", "rất hân hạnh"])
        XCTAssertEqual(card.id, "lesson:deck-1:\(slug):初めまして", "Not a made-up UUID: the id names the deck, the lesson and the word")
    }

    func test_savingTheSameWordsAgainChangesNothing() throws {
        try makeDeck()
        _ = try saver.save([hello, colleague], fromLesson: slug, to: .existing(deckID: "deck-1"))
        let again = try saver.save([hello, colleague], fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual([again.added, again.alreadyThere], [0, 2])
        XCTAssertEqual(cards(in: "deck-1").count, 2)
    }

    func test_aWordTheDeckAlreadyHoldsIsNotAddedAgainWhateverItsCardId() throws {
        try makeDeck(cards: [(UUID().uuidString, "初めまして", "hân hạnh"),
                             ("dict:deck-1:vocabulary:9adc769d", "同僚", "bạn đồng nghiệp")])
        let outcome = try saver.save([hello, colleague], fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual([outcome.added, outcome.alreadyThere], [0, 2], "Same Japanese text as a typed card or a dictionary word")
        XCTAssertEqual(cards(in: "deck-1").count, 2)
    }

    func test_aDictionaryKanjiWithTheSameCharacterIsADifferentCard() throws {
        try makeDeck(cards: [("dict:deck-1:kanji:k1", "同僚", "bạn")])
        let outcome = try saver.save([colleague], fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual(outcome.added, 1)
    }

    func test_aWordWithoutBothSidesMakesNoCard() throws {
        try makeDeck()
        let words = [LessonWord(japanese: "挨拶", reading: "あいさつ", meaning: "  "), LessonWord(japanese: " ", reading: "", meaning: "gì đó"), colleague]
        let outcome = try saver.save(words, fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual([outcome.added, outcome.skipped], [1, 2])
        XCTAssertEqual(cards(in: "deck-1").map(\.frontText), ["同僚"])
    }

    func test_aRepeatedWordInOneBatchIsAddedOnce() throws {
        try makeDeck()
        let outcome = try saver.save([hello, hello], fromLesson: slug, to: .existing(deckID: "deck-1"))
        XCTAssertEqual([outcome.added, outcome.alreadyThere], [1, 1])
        XCTAssertEqual(cards(in: "deck-1").count, 1)
    }

    func test_aMissingDeckIsAnErrorAndNothingIsWritten() throws {
        XCTAssertThrowsError(try saver.save([hello], fromLesson: slug, to: .existing(deckID: "gone")))
        XCTAssertEqual(realm.objects(RDesk.self).count, 0, "No deck is created behind the learner's back")
        XCTAssertEqual(realm.objects(RCard.self).count, 0)
    }

    func test_theLessonDeckIsCreatedOnlyWhenAskedForAndReusedAfterwards() throws {
        XCTAssertEqual(realm.objects(RDesk.self).count, 0, "Nothing exists until the learner chooses")
        let first = try saver.save([hello], fromLesson: slug, to: .newDictionaryDeck)
        XCTAssertEqual(first.deckID, "lesson-words")
        XCTAssertEqual(first.added, 1)
        let second = try saver.save([hello, colleague], fromLesson: slug, to: .newDictionaryDeck)
        XCTAssertEqual([second.added, second.alreadyThere], [1, 1])
        XCTAssertEqual(realm.objects(RDesk.self).count, 1)
        XCTAssertEqual(cards(in: "lesson-words").count, 2)
    }

    func test_theSameWordCanLiveInAnotherDeck() throws {
        try makeDeck(id: "a")
        try makeDeck(id: "b")
        _ = try saver.save([hello], fromLesson: slug, to: .existing(deckID: "a"))
        let outcome = try saver.save([hello], fromLesson: slug, to: .existing(deckID: "b"))
        XCTAssertEqual(outcome.added, 1)
        XCTAssertEqual(cards(in: "a").count, 1)
        XCTAssertEqual(cards(in: "b").count, 1)
    }

    func test_choicesListTheLearnersDecks() throws {
        try makeDeck(id: "deck-1", cards: [("c1", "犬", "chó")])
        XCTAssertEqual(saver.choices(), [TodayDeckChoice(id: "deck-1", name: "My words", cardCount: 1)])
    }
}
