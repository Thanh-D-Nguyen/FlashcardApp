import RealmSwift
import XCTest
@testable import FlashcardApp

/// Saving a dictionary entry as a flashcard, against a real in-memory Realm.
final class DictionaryDeckWriterTests: XCTestCase {
    private var realm: Realm!
    private var decks: DeskManagement!
    private var writer: DictionaryDeckWriter!

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "dict-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        decks = DeskManagement()
        writer = DictionaryDeckWriter(decks: decks, cards: CardManagement.shared)
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
        realm = nil
    }

    private let eat = EntryDetail.vocabulary(VocabularyDetail(
        id: "9adc769d-2d6f-48a1-a9ca-5fe729033518", headword: "食べる", reading: "たべる", hanViet: "THỰC", level: "N5",
        meanings: [.init(text: "ăn", partOfSpeech: nil, note: nil)], pitch: []))

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

    func testVocabularyBecomesAJapaneseFrontCardWithReadingAndMeaning() throws {
        let card = try XCTUnwrap(DictionaryCard(eat))
        XCTAssertEqual(card.front, "食べる")
        XCTAssertEqual(card.frontExtra, "たべる")
        XCTAssertEqual(card.back, "ăn")
        XCTAssertEqual(card.backExtra, "THỰC")
    }

    func testKanjiGrammarAndSentenceCardsUseTheirOwnFields() throws {
        let kanji = EntryDetail.kanji(KanjiDetail(id: "k", character: "食", meaning: "THỰC, TỰ", onyomi: ["ショク"], kunyomi: ["た.べる"], strokeCount: 9,
                                                  level: "N5", frequency: nil, explanation: [], mnemonic: [], words: [], components: [], strokeHash: nil))
        let card = try XCTUnwrap(DictionaryCard(kanji))
        XCTAssertEqual([card.front, card.frontExtra, card.back], ["食", "ショク / た.べる", "THỰC, TỰ"])

        let grammar = EntryDetail.grammar(GrammarDetail(id: "g", pattern: "ても", meaning: "Dù...cũng...", level: "N4", category: nil,
                                                       sections: [.init(formation: "Nghi vấn từ + ても", meaning: nil, explanation: nil, note: nil)]))
        let grammarCard = try XCTUnwrap(DictionaryCard(grammar))
        XCTAssertEqual([grammarCard.front, grammarCard.back, grammarCard.backExtra], ["ても", "Dù...cũng...", "Nghi vấn từ + ても"])

        let sentence = EntryDetail.sentence(SentenceDetail(id: "s", japanese: "食べるな。", reading: "たべるな。", translation: "Cấm ăn."))
        XCTAssertEqual(DictionaryCard(sentence)?.back, "Cấm ăn.")
    }

    func testAnEntryWithoutAMeaningCannotBecomeACard() {
        let nothing = EntryDetail.vocabulary(VocabularyDetail(id: "x", headword: "謎", reading: nil, hanViet: nil, level: nil, meanings: [], pitch: []))
        XCTAssertNil(DictionaryCard(nothing))
    }

    func testSavingToAnExistingDeckAddsOneCardWithAStableIdentity() throws {
        try makeDeck(cards: [("猫", "mèo")])
        let outcome = try writer.save(try XCTUnwrap(DictionaryCard(eat)), to: .existing(deckID: "deck-1"))
        XCTAssertEqual(outcome, DictionarySaveOutcome(deckID: "deck-1", deckName: "My words", wasAlreadyThere: false))
        let deck = try XCTUnwrap(decks.desk(withId: "deck-1"))
        XCTAssertEqual(deck.cards.map(\.frontText), ["猫", "食べる"])
        XCTAssertEqual(deck.cards.last?.id, "dict:deck-1:vocabulary:9adc769d-2d6f-48a1-a9ca-5fe729033518")
    }

    func testSavingTheSameEntryAgainWritesNothing() throws {
        try makeDeck()
        let card = try XCTUnwrap(DictionaryCard(eat))
        _ = try writer.save(card, to: .existing(deckID: "deck-1"))
        let second = try writer.save(card, to: .existing(deckID: "deck-1"))
        XCTAssertTrue(second.wasAlreadyThere)
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.count, 1)
    }

    func testAWordTheDeckAlreadyHoldsIsNotAddedTwiceEvenIfTypedByHand() throws {
        try makeDeck(cards: [("食べる", "ăn (tự gõ)")])
        let outcome = try writer.save(try XCTUnwrap(DictionaryCard(eat)), to: .existing(deckID: "deck-1"))
        XCTAssertTrue(outcome.wasAlreadyThere)
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.count, 1)
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.first?.backText, "ăn (tự gõ)", "The learner's own card is left as it was")
    }

    func testAnotherDictionaryEntryThatSharesTheTextIsADifferentCard() throws {
        try makeDeck()
        let word = EntryDetail.vocabulary(VocabularyDetail(id: "w", headword: "日", reading: "ひ", hanViet: nil, level: nil,
                                                           meanings: [.init(text: "ngày", partOfSpeech: nil, note: nil)], pitch: []))
        let kanji = EntryDetail.kanji(KanjiDetail(id: "k", character: "日", meaning: "NHẬT", onyomi: [], kunyomi: [], strokeCount: 4, level: nil, frequency: nil,
                                                  explanation: [], mnemonic: [], words: [], components: [], strokeHash: nil))
        _ = try writer.save(try XCTUnwrap(DictionaryCard(word)), to: .existing(deckID: "deck-1"))
        let second = try writer.save(try XCTUnwrap(DictionaryCard(kanji)), to: .existing(deckID: "deck-1"))
        XCTAssertFalse(second.wasAlreadyThere, "The kanji 日 is not the word 日")
        XCTAssertEqual(decks.desk(withId: "deck-1")?.cards.count, 2)
    }

    func testTheDictionaryDeckIsCreatedOnlyWhenTheLearnerAsksForIt() throws {
        XCTAssertFalse(writer.dictionaryDeckExists())
        XCTAssertTrue(decks.getAll().isEmpty, "Nothing is created by looking")
        let outcome = try writer.save(try XCTUnwrap(DictionaryCard(eat)), to: .newDictionaryDeck)
        XCTAssertEqual(outcome.deckID, DictionaryDeckWriter.dictionaryDeckID)
        XCTAssertTrue(writer.dictionaryDeckExists())
        XCTAssertEqual(decks.desk(withId: DictionaryDeckWriter.dictionaryDeckID)?.cards.count, 1)
        // Saving into it again reuses it.
        let kanji = EntryDetail.sentence(SentenceDetail(id: "s", japanese: "食べるな。", reading: nil, translation: "Cấm ăn."))
        _ = try writer.save(try XCTUnwrap(DictionaryCard(kanji)), to: .newDictionaryDeck)
        XCTAssertEqual(decks.desk(withId: DictionaryDeckWriter.dictionaryDeckID)?.cards.count, 2)
    }

    func testAMissingDeckIsAnErrorNotASilentNewDeck() throws {
        XCTAssertThrowsError(try writer.save(try XCTUnwrap(DictionaryCard(eat)), to: .existing(deckID: "gone")))
        XCTAssertTrue(decks.getAll().isEmpty)
    }

    func testChoicesListEveryDeckWithItsCardCount() throws {
        try makeDeck(id: "a", cards: [("猫", "mèo"), ("犬", "chó")])
        XCTAssertEqual(writer.choices(), [TodayDeckChoice(id: "a", name: "My words", cardCount: 2)])
    }
}
