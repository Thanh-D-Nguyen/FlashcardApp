import RealmSwift
import XCTest
@testable import FlashcardApp

/// The learner's own example sentences against a real (in-memory) Realm: what is stored, for whom, and what goes with a card.
final class CardExampleStoreTests: XCTestCase {
    private var store: RealmCardExampleStore!
    private var realm: Realm!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "examples-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        store = RealmCardExampleStore()
    }

    override func tearDownWithError() throws {
        store = nil
        realm = nil
        RealmService.shared.realm = nil
    }

    private func server(_ id: String = "s1", _ text: String = "犬が好きです。") -> ExampleItem {
        ExampleItem(example: CardExample(id: id, japanese: text, reading: "いぬがすきです。", translation: "Tôi thích chó."), origin: .server)
    }

    private var rows: Int { realm.objects(RCardExample.self).count }

    // MARK: Sentences the learner writes

    func test_aSentenceTheLearnerWritesIsStoredTrimmedAndComesBack() throws {
        try store.addCustom(CardExampleDraft(japanese: "  犬を飼っています。 ", reading: " いぬをかっています。", translation: "Tôi nuôi chó. "), cardId: "c1", ownerKey: owner)
        let custom = store.overlay(cardId: "c1", ownerKey: owner).custom
        XCTAssertEqual(custom.count, 1)
        XCTAssertEqual(custom[0].japanese, "犬を飼っています。")
        XCTAssertEqual(custom[0].reading, "いぬをかっています。")
        XCTAssertEqual(custom[0].translation, "Tôi nuôi chó.")
    }

    func test_theSentenceIsRequiredAndTheTextsAreBounded() {
        XCTAssertThrowsError(try store.addCustom(CardExampleDraft(japanese: "   "), cardId: "c1", ownerKey: owner)) {
            XCTAssertEqual($0 as? CardExampleError, .sentenceMissing)
        }
        let long = String(repeating: "あ", count: CardExampleDraft.maximumJapaneseLength + 1)
        XCTAssertThrowsError(try store.addCustom(CardExampleDraft(japanese: long), cardId: "c1", ownerKey: owner)) {
            XCTAssertEqual($0 as? CardExampleError, .tooLong(CardExampleDraft.maximumJapaneseLength))
        }
        XCTAssertThrowsError(try store.addCustom(CardExampleDraft(japanese: "犬", translation: String(repeating: "a", count: CardExampleDraft.maximumTranslationLength + 1)),
                                                 cardId: "c1", ownerKey: owner))
        XCTAssertEqual(rows, 0, "A refused sentence leaves nothing behind")
    }

    func test_aCardHoldsAtMostTwentyOfTheLearnersSentences() throws {
        for index in 0..<CardExampleDraft.maximumCustomPerCard {
            try store.addCustom(CardExampleDraft(japanese: "文\(index)"), cardId: "c1", ownerKey: owner)
        }
        XCTAssertThrowsError(try store.addCustom(CardExampleDraft(japanese: "もう一つ"), cardId: "c1", ownerKey: owner)) {
            XCTAssertEqual($0 as? CardExampleError, .limitReached(CardExampleDraft.maximumCustomPerCard))
        }
        try store.addCustom(CardExampleDraft(japanese: "別のカード"), cardId: "c2", ownerKey: owner)
        try store.addCustom(CardExampleDraft(japanese: "別の人"), cardId: "c1", ownerKey: other)
    }

    func test_theLearnersSentencesKeepTheOrderTheyWereAdded() throws {
        for text in ["一", "二", "三"] { try store.addCustom(CardExampleDraft(japanese: text), cardId: "c1", ownerKey: owner) }
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: owner).custom.map(\.japanese), ["一", "二", "三"])
    }

    func test_editingTheLearnersSentenceChangesItInPlace() throws {
        try store.addCustom(CardExampleDraft(japanese: "旧"), cardId: "c1", ownerKey: owner)
        let item = ExampleItem(example: store.overlay(cardId: "c1", ownerKey: owner).custom[0], origin: .custom)
        try store.update(item, with: CardExampleDraft(japanese: "新", translation: "mới"), cardId: "c1", ownerKey: owner)
        let custom = store.overlay(cardId: "c1", ownerKey: owner).custom
        XCTAssertEqual(custom.map(\.japanese), ["新"])
        XCTAssertEqual(custom.first?.translation, "mới")
        XCTAssertEqual(custom.first?.id, item.id, "The sentence keeps its identity")
        XCTAssertEqual(rows, 1)
    }

    func test_deletingTheLearnersSentenceRemovesIt() throws {
        try store.addCustom(CardExampleDraft(japanese: "消す"), cardId: "c1", ownerKey: owner)
        let item = ExampleItem(example: store.overlay(cardId: "c1", ownerKey: owner).custom[0], origin: .custom)
        try store.remove(item, cardId: "c1", ownerKey: owner)
        XCTAssertEqual(rows, 0)
    }

    func test_aSentenceOfAnotherAccountOrCardCannotBeChangedOrDeleted() throws {
        try store.addCustom(CardExampleDraft(japanese: "私の文"), cardId: "c1", ownerKey: owner)
        let item = ExampleItem(example: store.overlay(cardId: "c1", ownerKey: owner).custom[0], origin: .custom)
        for (card, who) in [("c1", other), ("c2", owner)] {
            XCTAssertThrowsError(try store.update(item, with: CardExampleDraft(japanese: "乗っ取り"), cardId: card, ownerKey: who)) {
                XCTAssertEqual($0 as? CardExampleError, .notFound)
            }
            XCTAssertThrowsError(try store.remove(item, cardId: card, ownerKey: who))
        }
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: owner).custom.map(\.japanese), ["私の文"])
    }

    // MARK: The server's sentences

    func test_editingAServerSentenceStoresTheLearnersVersionOnce() throws {
        try store.update(server(), with: CardExampleDraft(japanese: "犬が大好きです。", translation: "Tôi rất thích chó."), cardId: "c1", ownerKey: owner)
        try store.update(ExampleItem(example: CardExample(id: "s1", japanese: "", reading: "", translation: ""), origin: .edited),
                         with: CardExampleDraft(japanese: "犬がとても好きです。"), cardId: "c1", ownerKey: owner)
        let overlay = store.overlay(cardId: "c1", ownerKey: owner)
        XCTAssertEqual(overlay.edited["s1"]?.japanese, "犬がとても好きです。")
        XCTAssertEqual(overlay.edited["s1"]?.id, "s1", "The edit is tied to the server sentence")
        XCTAssertEqual(rows, 1, "Editing the same sentence again updates one row")
    }

    func test_removingAServerSentenceOnlyHidesItForThisAccount() throws {
        try store.remove(server(), cardId: "c1", ownerKey: owner)
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: owner).hidden, ["s1"])
        XCTAssertTrue(store.overlay(cardId: "c1", ownerKey: other).hidden.isEmpty, "Another account still sees it")
        XCTAssertTrue(store.overlay(cardId: "c1", ownerKey: "").hidden.isEmpty, "So does a signed-out learner")
        XCTAssertTrue(store.overlay(cardId: "c2", ownerKey: owner).hidden.isEmpty, "Another card is unaffected")
    }

    func test_removingAnEditedSentenceDropsTheLearnersTextAndKeepsItHidden() throws {
        try store.update(server(), with: CardExampleDraft(japanese: "編集"), cardId: "c1", ownerKey: owner)
        try store.remove(ExampleItem(example: CardExample(id: "s1", japanese: "編集", reading: "", translation: ""), origin: .edited), cardId: "c1", ownerKey: owner)
        let overlay = store.overlay(cardId: "c1", ownerKey: owner)
        XCTAssertEqual(overlay.hidden, ["s1"])
        XCTAssertTrue(overlay.edited.isEmpty)
        XCTAssertEqual(rows, 1)
        XCTAssertEqual(realm.objects(RCardExample.self).first?.japanese, "", "No text is kept for a removed sentence")
    }

    func test_restoringTheOriginalDropsOnlyTheEdit() throws {
        try store.update(server(), with: CardExampleDraft(japanese: "編集"), cardId: "c1", ownerKey: owner)
        try store.addCustom(CardExampleDraft(japanese: "残る"), cardId: "c1", ownerKey: owner)
        let edited = ExampleItem(example: CardExample(id: "s1", japanese: "編集", reading: "", translation: ""), origin: .edited)
        try store.restoreOriginal(of: edited, cardId: "c1", ownerKey: owner)
        let overlay = store.overlay(cardId: "c1", ownerKey: owner)
        XCTAssertTrue(overlay.edited.isEmpty)
        XCTAssertEqual(overlay.custom.map(\.japanese), ["残る"])
        try store.restoreOriginal(of: server(), cardId: "c1", ownerKey: owner)   // nothing to restore: no effect
        XCTAssertEqual(rows, 1)
    }

    func test_restoringRemovedSentencesBringsBackOnlyThisCardsAndThisAccounts() throws {
        try store.remove(server("s1"), cardId: "c1", ownerKey: owner)
        try store.remove(server("s2"), cardId: "c1", ownerKey: owner)
        try store.remove(server("s1"), cardId: "c2", ownerKey: owner)
        try store.remove(server("s1"), cardId: "c1", ownerKey: other)
        try store.update(server("s3"), with: CardExampleDraft(japanese: "編集"), cardId: "c1", ownerKey: owner)
        try store.restoreRemoved(cardId: "c1", ownerKey: owner)
        XCTAssertTrue(store.overlay(cardId: "c1", ownerKey: owner).hidden.isEmpty)
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: owner).edited.count, 1, "Edits are not undone by restoring removed ones")
        XCTAssertEqual(store.overlay(cardId: "c2", ownerKey: owner).hidden, ["s1"])
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: other).hidden, ["s1"])
    }

    func test_accountsAndTheSignedOutLearnerKeepSeparateSentences() throws {
        try store.addCustom(CardExampleDraft(japanese: "A"), cardId: "c1", ownerKey: owner)
        try store.addCustom(CardExampleDraft(japanese: "B"), cardId: "c1", ownerKey: other)
        try store.addCustom(CardExampleDraft(japanese: "G"), cardId: "c1", ownerKey: "")
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: owner).custom.map(\.japanese), ["A"])
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: other).custom.map(\.japanese), ["B"])
        XCTAssertEqual(store.overlay(cardId: "c1", ownerKey: "").custom.map(\.japanese), ["G"])
    }

    // MARK: Deleting cards

    private func deck(id: String = "d1", cards: [String]) -> DeskEntity {
        let desk = DeskEntity()
        desk.id = id
        desk.name = "Deck"
        desk.cards = cards.map { cardId in
            let card = CardEntity()
            card.id = cardId
            card.frontText = "犬"
            card.backText = "chó"
            return card
        }
        return desk
    }

    func test_deletingADeckDeletesItsCardsSentencesForEveryAccount() throws {
        let repository = DeskManagement()
        let desk = deck(cards: ["a", "b"])
        try repository.add(desk)
        try repository.add(deck(id: "d2", cards: ["z"]))
        for (card, who) in [("a", owner), ("a", other), ("b", owner), ("z", owner)] {
            try store.addCustom(CardExampleDraft(japanese: "文"), cardId: card, ownerKey: who)
        }
        try store.remove(server(), cardId: "b", ownerKey: owner)

        try repository.delete(desk)

        XCTAssertEqual(realm.objects(RCardExample.self).map(\.cardId), ["z"], "Only the other deck's card keeps its sentence")
    }

    func test_removingACardFromADeckDeletesOnlyThatCardsSentences() throws {
        let repository = DeskManagement()
        let desk = deck(cards: ["a", "b"])
        try repository.add(desk)
        try store.addCustom(CardExampleDraft(japanese: "a の文"), cardId: "a", ownerKey: owner)
        try store.addCustom(CardExampleDraft(japanese: "b の文"), cardId: "b", ownerKey: owner)

        desk.cards = desk.cards.filter { $0.id == "b" }
        try repository.update(desk)

        XCTAssertEqual(store.overlay(cardId: "a", ownerKey: owner).custom.count, 0)
        XCTAssertEqual(store.overlay(cardId: "b", ownerKey: owner).custom.map(\.japanese), ["b の文"])
    }

    func test_savingADeckKeepsTheSentencesOfItsCards() throws {
        let repository = DeskManagement()
        let desk = deck(cards: ["a"])
        try repository.add(desk)
        try store.addCustom(CardExampleDraft(japanese: "残る"), cardId: "a", ownerKey: owner)
        desk.name = "Renamed"
        desk.cards[0].backText = "con chó"
        try repository.update(desk)
        XCTAssertEqual(store.overlay(cardId: "a", ownerKey: owner).custom.map(\.japanese), ["残る"], "Editing a card keeps its identity and its sentences")
    }
}
