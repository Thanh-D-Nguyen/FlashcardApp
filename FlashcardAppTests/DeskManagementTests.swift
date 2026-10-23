import XCTest
import RealmSwift
@testable import FlashcardApp

/// Repository behaviour against a real (in-memory) Realm: the persistence contract behind the Cards tab.
final class DeskManagementTests: XCTestCase {
    private var repository: DeskManagement!
    private var realm: Realm!

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "desk-management-\(UUID().uuidString)",
                                                objectTypes: RealmService.storedTypes)
        realm = try Realm(configuration: configuration)
        RealmService.shared.realm = realm
        repository = DeskManagement()
    }

    override func tearDownWithError() throws {
        repository = nil
        realm = nil
        RealmService.shared.realm = nil
    }

    private func makeCard(_ id: String, front: String, back: String) -> CardEntity {
        let card = CardEntity()
        card.id = id
        card.frontText = front
        card.backText = back
        return card
    }

    private func makeDesk(id: String = "desk-1", cards: [CardEntity]) -> DeskEntity {
        let desk = DeskEntity()
        desk.id = id
        desk.name = "JLPT N5"
        desk.description = "Basics"
        desk.cards = cards
        return desk
    }

    func test_addPersistsTheCardDirection() throws {
        let desk = makeDesk(cards: [makeCard("a", front: "犬", back: "chó")])
        desk.sortingLanguage = .opposite
        try repository.add(desk)

        XCTAssertEqual(repository.getAll().first?.sortingLanguage, .opposite)
    }

    func test_addKeepsReadingNoteAndImageReferenceOfEveryCard() throws {
        let card = makeCard("a", front: "会議", back: "cuộc họp")
        card.frontExtraText = "かいぎ"
        card.backExtraText = "formal"
        card.imageUrl = "local-image:abc.jpg"
        try repository.add(makeDesk(cards: [card]))

        let stored = try XCTUnwrap(repository.getAll().first?.cards.first)
        XCTAssertEqual(stored.frontExtraText, "かいぎ")
        XCTAssertEqual(stored.backExtraText, "formal")
        XCTAssertEqual(stored.imageUrl, "local-image:abc.jpg")
    }

    func test_deleteRemovesTheDeckAndItsCards() throws {
        try repository.add(makeDesk(id: "keep", cards: [makeCard("k1", front: "a", back: "b")]))
        try repository.add(makeDesk(id: "gone", cards: [makeCard("g1", front: "c", back: "d"), makeCard("g2", front: "e", back: "f")]))

        try repository.delete(try XCTUnwrap(repository.getAll().first { $0.id == "gone" }))

        XCTAssertEqual(repository.getAll().map(\.id), ["keep"])
        XCTAssertEqual(realm.objects(RCard.self).map(\.id), ["k1"], "Cards of a deleted deck must not stay behind")
    }

    func test_deleteOfAnUnknownDeckThrowsInsteadOfCrashing() {
        XCTAssertThrowsError(try repository.delete(makeDesk(id: "missing", cards: [])))
    }

    func test_updateRemovesCardsDroppedFromTheDeck() throws {
        try repository.add(makeDesk(cards: [makeCard("a", front: "1", back: "1"),
                                            makeCard("b", front: "2", back: "2"),
                                            makeCard("c", front: "3", back: "3")]))
        let edited = try XCTUnwrap(repository.getAll().first)
        edited.cards = edited.cards.filter { $0.id != "b" }
        try repository.update(edited)

        XCTAssertEqual(repository.getAll().first?.cards.map(\.id), ["a", "c"])
        XCTAssertEqual(Set(realm.objects(RCard.self).map(\.id)), ["a", "c"], "A removed card must not remain as an orphan")
    }

    func test_updateKeepsIdentityDateAndPersistsNewOrder() throws {
        try repository.add(makeDesk(cards: [makeCard("a", front: "1", back: "1"), makeCard("b", front: "2", back: "2")]))
        let original = try XCTUnwrap(repository.getAll().first)
        let edited = try XCTUnwrap(repository.getAll().first)   // a separate copy: DeskEntity is a class
        edited.name = "Renamed"
        edited.sortingLanguage = .opposite
        edited.cards = original.cards.reversed()
        try repository.update(edited)

        let stored = try XCTUnwrap(repository.getAll().first)
        XCTAssertEqual(repository.getAll().count, 1)
        XCTAssertEqual(stored.id, original.id)
        XCTAssertEqual(stored.date, original.date)
        XCTAssertEqual(stored.name, "Renamed")
        XCTAssertEqual(stored.sortingLanguage, .opposite)
        XCTAssertEqual(stored.cards.map(\.id), ["b", "a"])
    }

    func test_updateOfADeckDeletedMeanwhileThrowsInsteadOfResurrectingIt() throws {
        let desk = makeDesk(cards: [makeCard("a", front: "1", back: "1")])
        try repository.add(desk)
        try repository.delete(try XCTUnwrap(repository.getAll().first))

        XCTAssertThrowsError(try repository.update(desk))
        XCTAssertTrue(repository.getAll().isEmpty)
    }

    func test_deskLookupByIdReturnsAnIndependentCopy() throws {
        try repository.add(makeDesk(cards: [makeCard("a", front: "1", back: "1")]))
        XCTAssertEqual(repository.desk(withId: "desk-1")?.cards.map(\.id), ["a"])
        XCTAssertNil(repository.desk(withId: "nope"))
    }
}
