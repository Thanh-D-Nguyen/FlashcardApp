import RealmSwift
import XCTest
@testable import FlashcardApp

/// The local store holds the learner's own decks and nothing else: dictionary content comes from the API.
/// Existing installs carry the old bundled dictionary tables, which the schema-2 migration drops.
final class RealmServiceTests: XCTestCase {
    private var folder: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("flash_card.realm")
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }

    func test_theLocalSchemaHoldsTheLearnersOwnData() {
        XCTAssertEqual(Set(RealmService.storedTypes.map { $0.className() }), ["RDesk", "RCard", "RCardExample"])
    }

    func test_aFreshInstallOpensAnEmptyStoreWithoutAnyBundledFile() throws {
        let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
        XCTAssertEqual(realm.objects(RDesk.self).count, 0)
        XCTAssertEqual(realm.configuration.schemaVersion, RealmService.schemaVersion)
    }

    func test_upgradingFromTheBundledSchemaKeepsDecksAndCardsAndEmptiesDictionaryTables() throws {
        try makeVersionOneStore()

        var deckName = "", frontTexts: [String] = [], cardBack: String?, tables: Set<String> = [], version: UInt64 = 0
        try autoreleasepool {
            let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            let desk = try XCTUnwrap(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-1"))
            deckName = desk.name
            frontTexts = desk.cards.map(\.frontText)
            cardBack = realm.object(ofType: RCard.self, forPrimaryKey: "card-1")?.backText
            tables = Set(realm.schema.objectSchema.map(\.className))
            version = realm.configuration.schemaVersion
        }

        XCTAssertEqual(deckName, "My deck")
        XCTAssertEqual(frontTexts, ["犬"], "The learner's cards survive the upgrade")
        XCTAssertEqual(cardBack, "con chó")
        XCTAssertEqual(tables, ["RDesk", "RCard", "RCardExample"])
        XCTAssertEqual(version, RealmService.schemaVersion)
        XCTAssertEqual(try retiredRowCount(), 0, "The dictionary rows were emptied")
    }

    func test_upgradingFromSchemaTwoKeepsEveryDeckAndAddsAnEmptyExampleTable() throws {
        try autoreleasepool {
            var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: 2)
            configuration.objectTypes = [RDesk.self, RCard.self]
            let realm = try Realm(configuration: configuration)
            try realm.write {
                let card = RCard()
                card.id = "card-1"
                card.frontText = "犬"
                let desk = RDesk()
                desk.id = "deck-1"
                desk.name = "My deck"
                desk.cards.append(card)
                realm.add(desk)
            }
        }
        let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
        XCTAssertEqual(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-1")?.cards.first?.frontText, "犬")
        XCTAssertEqual(realm.objects(RCardExample.self).count, 0)
        try realm.write {
            let example = RCardExample()
            example.id = "e1"
            example.cardId = "card-1"
            realm.add(example)
        }
        XCTAssertEqual(realm.objects(RCardExample.self).count, 1, "The new table is writable")
    }

    func test_aMigratedStoreOpensAgainWithoutFurtherMigration() throws {
        try makeVersionOneStore()
        try autoreleasepool { _ = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL)) }
        let again = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
        XCTAssertEqual(again.objects(RDesk.self).count, 1)
    }

    func test_aStoreIsCompactedOnlyWhenItIsLargeAndMostlyFree() {
        let megabyte = 1024 * 1024
        XCTAssertTrue(RealmService.shouldCompact(totalBytes: 126 * megabyte, usedBytes: 4 * megabyte))
        XCTAssertFalse(RealmService.shouldCompact(totalBytes: 126 * megabyte, usedBytes: 100 * megabyte))
        XCTAssertFalse(RealmService.shouldCompact(totalBytes: 2 * megabyte, usedBytes: 0))
    }

    func test_aLargeMostlyFreeStoreIsCompactedWhenItOpens() throws {
        try makeVersionOneStore()
        // The dictionary's rows are gone but its space is still part of the file, as after the upgrade.
        try autoreleasepool {
            var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: RealmService.schemaVersion, objectTypes: RealmService.storedTypes)
            configuration.migrationBlock = RealmService.migrate
            let realm = try Realm(configuration: configuration)
            let filler = String(repeating: "辞書", count: 500)
            try realm.write {
                (0..<30_000).forEach { id in realm.create(RCard.self, value: ["id": "filler-\(id)", "frontText": filler]) }
            }
            try realm.write { realm.delete(realm.objects(RCard.self).filter("id BEGINSWITH 'filler-'")) }
        }
        let before = try fileSize()

        let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))

        XCTAssertGreaterThan(before, 20 * 1024 * 1024, "The fixture is a large store")
        XCTAssertLessThan(try fileSize(), before / 4, "before \(before)")
        XCTAssertEqual(realm.objects(RDesk.self).count, 1, "Compaction keeps the decks")
    }

    // MARK: Fixture

    private func fileSize() throws -> Int {
        (try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
    }

    private func retiredRowCount() throws -> Int {
        var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: RealmService.schemaVersion)
        configuration.objectTypes = RealmService.retiredDictionaryTables
        // A Realm is cached per file until it is released: close it before the next open with another schema.
        return try autoreleasepool {
            let realm = try Realm(configuration: configuration)
            return RealmService.retiredDictionaryTables.reduce(0) { $0 + realm.dynamicObjects($1.className()).count }
        }
    }

    /// A store as the app wrote it before: schema 1 with the decks and the bundled dictionary tables.
    private func makeVersionOneStore(dictionaryRows: Int = 1) throws {
        var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: 1)
        configuration.objectTypes = [RDesk.self, RCard.self] + RealmService.retiredDictionaryTables
        try autoreleasepool {
            let realm = try Realm(configuration: configuration)
            try realm.write {
                let card = RCard()
                card.id = "card-1"
                card.frontText = "犬"
                card.backText = "con chó"
                let desk = RDesk()
                desk.id = "deck-1"
                desk.name = "My deck"
                desk.cards.append(card)
                realm.add(desk)
                RealmService.retiredDictionaryTables.forEach { table in
                    for id in 1...dictionaryRows {
                        let row = table.init()
                        row.setValue(id, forKey: "id")
                        realm.add(row)
                    }
                }
            }
        }
    }
}
