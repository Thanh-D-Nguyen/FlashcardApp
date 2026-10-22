import RealmSwift
import UIKit
import XCTest
@testable import FlashcardApp

/// Real Realm (in memory) + real picture store (temporary folder) + real draft store: the pieces the Cards screens
/// rely on to not lose or leak data when they are used together.
final class CardsIntegrationTests: XCTestCase {
    private var repository: DeskManagement!
    private var images: CardImageStore!
    private var drafts: DeckDraftStore!
    private var folder: URL!
    private var suite: String!

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "cards-integration-\(UUID().uuidString)", objectTypes: [RDesk.self, RCard.self])
        RealmService.shared.realm = try Realm(configuration: configuration)
        repository = DeskManagement()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("cards-integration-\(UUID().uuidString)")
        images = CardImageStore(directory: folder)
        suite = "cards-integration-\(UUID().uuidString)"
        drafts = DeckDraftStore(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        RealmService.shared.realm = nil
    }

    private func picture() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return try images.save(image: renderer.image { UIColor.systemTeal.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 40, height: 40)) })
    }

    private func editor() -> CreateDeskInteractor {
        CreateDeskInteractor(repository: repository, drafts: drafts, images: images)
    }

    private func draft(id: String? = nil, cards prefix: String = "c", picture reference: String = "") -> DeckDraft {
        DeckDraft(deckId: id, name: "Deck", cards: [CardDraft(id: prefix + "1", front: "犬", back: "chó", imageReference: reference), CardDraft(id: prefix + "2", front: "猫", back: "mèo")])
    }

    func test_savingAnEditedDeckReplacesAPictureAndDeletesTheOldFile() throws {
        let first = try picture()
        try editor().save(draft(picture: first))
        let saved = try XCTUnwrap(repository.getAll().first)
        XCTAssertEqual(saved.cards.first?.imageUrl, first)
        XCTAssertTrue(images.exists(CardImageReference(first)))

        let second = try picture()
        try editor().save(draft(id: saved.id, picture: second))

        XCTAssertEqual(repository.getAll().first?.cards.first?.imageUrl, second)
        XCTAssertFalse(images.exists(CardImageReference(first)), "The replaced picture must not stay on disk")
        XCTAssertTrue(images.exists(CardImageReference(second)))
    }

    func test_removingAPictureFromACardDeletesItsFile() throws {
        let reference = try picture()
        try editor().save(draft(picture: reference))
        let id = try XCTUnwrap(repository.getAll().first?.id)
        try editor().save(draft(id: id, picture: ""))
        XCTAssertFalse(images.exists(CardImageReference(reference)))
    }

    func test_deletingADeckDeletesItsPicturesButNotThoseOfOtherDecks() throws {
        let mine = try picture()
        try editor().save(draft(picture: mine))
        let theirs = try picture()   // made after the first save: every save collects pictures nothing references yet
        try editor().save(draft(cards: "other", picture: theirs))
        let decks = DeskInteractor(repository: repository, maintenance: CardMediaMaintenance(repository: repository, drafts: drafts, store: images), drafts: drafts)
        let target = try XCTUnwrap(repository.getAll().first { $0.cards.first?.imageUrl == mine })

        try decks.deleteDesk(withId: target.id)

        XCTAssertFalse(images.exists(CardImageReference(mine)))
        XCTAssertTrue(images.exists(CardImageReference(theirs)))
        XCTAssertEqual(repository.getAll().count, 1)
    }

    func test_aPictureOnlyAnUnsavedDraftUsesSurvivesCleanup() throws {
        let pending = try picture()
        drafts.save(DeckDraft(deckId: "being-edited", name: "Unsaved", cards: [CardDraft(front: "a", back: "b", imageReference: pending)]))
        try editor().save(draft())   // any save triggers a cleanup
        XCTAssertTrue(images.exists(CardImageReference(pending)), "Recoverable work keeps its pictures")
        drafts.discard(forDeckId: "being-edited")
        editor().collectUnusedPictures()
        XCTAssertFalse(images.exists(CardImageReference(pending)), "Once the draft is gone the picture is collected")
    }

    func test_deletingADeckAlsoDropsItsUnsavedDraftAndThatDraftsPictures() throws {
        try editor().save(draft())
        let id = try XCTUnwrap(repository.getAll().first?.id)
        let pending = try picture()
        drafts.save(DeckDraft(deckId: id, name: "Edited", cards: [CardDraft(front: "a", back: "b", imageReference: pending)]))
        let decks = DeskInteractor(repository: repository, maintenance: CardMediaMaintenance(repository: repository, drafts: drafts, store: images), drafts: drafts)

        try decks.deleteDesk(withId: id)

        XCTAssertNil(drafts.draft(forDeckId: id), "A draft of a deleted deck can never be restored")
        XCTAssertFalse(images.exists(CardImageReference(pending)), "...so its picture must not be kept forever")
    }

    func test_deletingFromTheEditorRemovesDeckDraftAndPictures() throws {
        let reference = try picture()
        try editor().save(draft(picture: reference))
        let id = try XCTUnwrap(repository.getAll().first?.id)
        drafts.save(DeckDraft(deckId: id, name: "Edited"))

        try editor().deleteDeck(withId: id)

        XCTAssertTrue(repository.getAll().isEmpty)
        XCTAssertNil(drafts.draft(forDeckId: id))
        XCTAssertFalse(images.exists(CardImageReference(reference)))
        XCTAssertThrowsError(try editor().deleteDeck(withId: id), "A deck that is already gone is reported, not a crash")
    }

    func test_savingClearsTheDraftOfThatDeck() throws {
        drafts.save(DeckDraft(name: "Unsaved"))
        try editor().save(draft())
        XCTAssertNil(drafts.draft(forDeckId: nil))
    }

    func test_aLegacyDeckWithARemoteImageAndNoExtrasSurvivesAnEditUnchanged() throws {
        // What the previous version stored: no reading/note, direction never persisted, a remote picture URL.
        let legacyCard = CardEntity()
        legacyCard.id = "legacy-1"
        legacyCard.frontText = "犬"
        legacyCard.backText = "chó"
        legacyCard.imageUrl = "https://example.com/dog.jpg"
        let other = CardEntity()
        other.id = "legacy-2"
        other.frontText = "猫"
        other.backText = "mèo"
        let legacy = DeskEntity()
        legacy.id = "legacy-deck"
        legacy.name = "Old deck"
        legacy.cards = [legacyCard, other]
        try repository.add(legacy)

        var edited = DeckDraft(entity: try XCTUnwrap(repository.desk(withId: "legacy-deck")))
        edited.name = "Old deck (renamed)"
        try editor().save(edited)

        let stored = try XCTUnwrap(repository.desk(withId: "legacy-deck"))
        XCTAssertEqual(stored.cards.map(\.id), ["legacy-1", "legacy-2"], "Card identity survives an edit")
        XCTAssertEqual(stored.cards.first?.imageUrl, "https://example.com/dog.jpg", "A remote picture is kept as it was")
        XCTAssertEqual(stored.sortingLanguage, .normal)
        XCTAssertEqual(stored.name, "Old deck (renamed)")
    }

    func test_aDeckCannotTakeOverACardThatBelongsToAnotherDeck() throws {
        try editor().save(draft())
        XCTAssertThrowsError(try editor().save(draft()), "Same card ids in a second deck would move the cards; this is refused, not a crash")
        XCTAssertEqual(repository.getAll().count, 1)
        XCTAssertEqual(repository.getAll().first?.cards.count, 2)
    }

    func test_anInvalidDraftNeverReachesTheDatabase() {
        XCTAssertThrowsError(try editor().save(DeckDraft()))
        XCTAssertTrue(repository.getAll().isEmpty)
    }
}
