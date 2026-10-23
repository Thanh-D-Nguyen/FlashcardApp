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
        XCTAssertEqual(Set(RealmService.storedTypes.map { $0.className() }), ["RDesk", "RCard", "RCardExample", "RReviewAttempt", "RReviewState"])
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
        XCTAssertEqual(tables, ["RDesk", "RCard", "RCardExample", "RReviewAttempt", "RReviewState"])
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

    func test_upgradingFromSchemaThreeKeepsEveryLearnerRecordAndAddsAnEmptyWritableReviewTable() throws {
        let sentExamples = try makeVersionThreeStore()

        try autoreleasepool {
            let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            XCTAssertEqual(realm.configuration.schemaVersion, RealmService.schemaVersion)
            XCTAssertGreaterThan(RealmService.schemaVersion, 3)

            let desks = realm.objects(RDesk.self).sorted(byKeyPath: "id")
            XCTAssertEqual(desks.map(\.id), ["deck-a", "deck-b"])
            let deckA = try XCTUnwrap(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-a"))
            XCTAssertEqual(deckA.name, "JLPT N5 · Everyday")
            XCTAssertEqual(deckA.desc, "Basics")
            XCTAssertEqual(deckA.sortingLanguage, 1)
            XCTAssertEqual(deckA.imageNamed, "deck-a.jpg")
            XCTAssertEqual(deckA.date, sentExamples.deckDate)
            XCTAssertEqual(deckA.cards.map(\.id), ["card-3", "card-1", "card-2"], "The order of the cards is kept")
            let cardOne = try XCTUnwrap(realm.object(ofType: RCard.self, forPrimaryKey: "card-1"))
            XCTAssertEqual([cardOne.frontText, cardOne.frontExtraText, cardOne.backText, cardOne.backExtraText, cardOne.imageUrl, cardOne.videoUrl],
                           ["犬", "いぬ", "con chó", "animal", "local-image:dog.jpg", "clip.mp4"])
            XCTAssertEqual(cardOne.assignee.first?.id, "deck-a", "The card still belongs to its deck")
            XCTAssertEqual(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-b")?.cards.map(\.id), ["card-4"])

            let examples = realm.objects(RCardExample.self).sorted(byKeyPath: "id")
            XCTAssertEqual(examples.map(\.id), ["u1|card-1|s1", "u1|card-1|s2", "custom-1"].sorted())
            let edited = try XCTUnwrap(realm.object(ofType: RCardExample.self, forPrimaryKey: "u1|card-1|s1"))
            XCTAssertEqual([edited.kind, edited.ownerKey, edited.cardId, edited.serverExampleId, edited.japanese, edited.reading, edited.translation],
                           ["edited", "u1", "card-1", "s1", "犬が好き。", "いぬがすき。", "Thích chó."])
            XCTAssertEqual(edited.createdAt, sentExamples.exampleDate)
            XCTAssertEqual(realm.object(ofType: RCardExample.self, forPrimaryKey: "u1|card-1|s2")?.kind, "hidden")
            XCTAssertEqual(realm.object(ofType: RCardExample.self, forPrimaryKey: "custom-1")?.ownerKey, "")

            XCTAssertEqual(realm.objects(RReviewAttempt.self).count, 0, "The new table starts empty")
        }

        // The new table works against the upgraded file, and the old data is still intact afterwards.
        try autoreleasepool {
            RealmService.shared.realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            defer { RealmService.shared.realm = nil }
            let attempt = ReviewAttempt(id: "run/0", cardID: "card-1", result: .correct, hints: [.reading], contentVersion: "v",
                                        answeredAt: sentExamples.exampleDate)
            XCTAssertTrue(try RealmReviewHistoryStore().save(attempt, ownerKey: "u1"))
            XCTAssertEqual(RealmReviewHistoryStore().attempts(ownerKey: "u1", cardId: "card-1"), [attempt])
            XCTAssertEqual(RealmService.shared.realm.objects(RDesk.self).count, 2)
            XCTAssertEqual(RealmService.shared.realm.objects(RCardExample.self).count, 3)
        }
    }

    func test_upgradingFromSchemaFourKeepsEverythingAndSchedulesCanBeBuiltFromTheSavedAttempts() throws {
        // A real schema-4 file: the schema-3 store upgraded by schema-4 code, with one saved attempt in it.
        let dates = try makeVersionThreeStore()
        try autoreleasepool {
            var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: 4)
            configuration.objectTypes = [RDesk.self, RCard.self, RCardExample.self, RReviewAttempt.self]
            let realm = try Realm(configuration: configuration)
            try realm.write {
                let record = RReviewAttempt()
                record.recordId = "u1|run/0"
                record.attemptId = "run/0"
                record.ownerKey = "u1"
                record.cardId = "card-1"
                record.contentVersion = "v1"
                record.result = "correct"
                record.hints.append("reading")
                record.answeredAt = dates.exampleDate
                realm.add(record)
            }
        }

        try autoreleasepool {
            RealmService.shared.realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            defer { RealmService.shared.realm = nil }
            let realm = try XCTUnwrap(RealmService.shared.realm)
            XCTAssertEqual(realm.configuration.schemaVersion, RealmService.schemaVersion)
            XCTAssertEqual(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-a")?.cards.map(\.id), ["card-3", "card-1", "card-2"])
            XCTAssertEqual(realm.objects(RDesk.self).count, 2)
            XCTAssertEqual(realm.objects(RCardExample.self).count, 3)
            XCTAssertEqual(realm.objects(RReviewAttempt.self).count, 1, "The saved attempt survives")
            XCTAssertEqual(realm.objects(RReviewState.self).count, 0, "The new table starts empty")

            let store = RealmReviewHistoryStore()
            try store.rebuildSchedules(ownerKey: "u1")
            let schedule = try XCTUnwrap(store.schedules(ownerKey: "u1").first)
            XCTAssertEqual([schedule.cardID, schedule.skill.rawValue], ["card-1", "recognition"])
            XCTAssertEqual(schedule.state.reviews, 1)
            XCTAssertEqual(schedule.state.contentVersion, "v1")
            XCTAssertEqual(store.attempts(ownerKey: "u1", cardId: nil).count, 1, "Rebuilding never touches the attempts")
        }
    }

    func test_aSchemaFiveStoreMadeBeforeAnUnusedColumnWasRemovedStillOpensAndKeepsItsData() throws {
        // Schema 5 first shipped `RReviewState` with a `lastAttemptId` column that nothing read; a store written then must
        // still open once the column is gone, with every row kept.
        try autoreleasepool {
            var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: 5)
            configuration.objectTypes = [RDesk.self, RCard.self, RCardExample.self, RReviewAttempt.self, EarlierReviewState.self]
            let realm = try Realm(configuration: configuration)
            try realm.write {
                let state = EarlierReviewState()
                state.recordId = "u1|card-1|selfRecall"
                state.ownerKey = "u1"
                state.cardId = "card-1"
                state.skill = "selfRecall"
                state.contentVersion = "v1"
                state.algorithm = FSRSParameters.algorithm
                state.stability = 2.3065
                state.difficulty = 2.118
                state.due = Date(timeIntervalSince1970: 1_800_000_000)
                state.lastReview = Date(timeIntervalSince1970: 1_799_800_000)
                state.reviews = 1
                state.lastAttemptId = "run/0"
                realm.add(state)
                let desk = RDesk()
                desk.id = "deck-1"
                desk.name = "Kept"
                realm.add(desk)
            }
        }

        try autoreleasepool {
            let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            XCTAssertEqual(realm.object(ofType: RDesk.self, forPrimaryKey: "deck-1")?.name, "Kept")
            let state = try XCTUnwrap(realm.object(ofType: RReviewState.self, forPrimaryKey: "u1|card-1|selfRecall"))
            XCTAssertEqual([state.cardId, state.skill, state.contentVersion], ["card-1", "selfRecall", "v1"])
            XCTAssertEqual(state.stability, 2.3065, accuracy: 1e-12)
            XCTAssertEqual(state.reviews, 1)
        }
    }

    func test_everySupportedOlderSchemaOpensWithTheReviewTableAvailable() throws {
        try makeVersionOneStore()
        try autoreleasepool {
            let realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
            XCTAssertEqual(realm.objects(RReviewAttempt.self).count, 0)
            XCTAssertEqual(realm.objects(RDesk.self).count, 1)
        }
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

    /// A store exactly as schema 3 wrote it: two decks, ordered cards with every field set, and the learner's example
    /// sentences of all three kinds. Opened with the schema-3 types only, so it is a real old file, not a new one.
    private func makeVersionThreeStore() throws -> (deckDate: Date, exampleDate: Date) {
        var configuration = Realm.Configuration(fileURL: fileURL, schemaVersion: 3)
        configuration.objectTypes = [RDesk.self, RCard.self, RCardExample.self]
        let deckDate = Date(timeIntervalSince1970: 1_650_000_000)
        let exampleDate = Date(timeIntervalSince1970: 1_690_000_000)
        try autoreleasepool {
            let realm = try Realm(configuration: configuration)
            try realm.write {
                func card(_ id: String, _ front: String, _ back: String) -> RCard {
                    let card = RCard()
                    card.id = id
                    card.frontText = front
                    card.backText = back
                    return card
                }
                let one = card("card-1", "犬", "con chó")
                one.frontExtraText = "いぬ"
                one.backExtraText = "animal"
                one.imageUrl = "local-image:dog.jpg"
                one.videoUrl = "clip.mp4"
                let deckA = RDesk()
                deckA.id = "deck-a"
                deckA.name = "JLPT N5 · Everyday"
                deckA.desc = "Basics"
                deckA.sortingLanguage = 1
                deckA.imageNamed = "deck-a.jpg"
                deckA.date = deckDate
                deckA.cards.append(objectsIn: [card("card-3", "猫", "con mèo"), one, card("card-2", "鳥", "con chim")])
                let deckB = RDesk()
                deckB.id = "deck-b"
                deckB.name = "Work"
                deckB.date = deckDate
                deckB.cards.append(card("card-4", "会議", "cuộc họp"))
                realm.add([deckA, deckB])

                func example(_ id: String, owner: String, kind: RCardExample.Kind, server: String, japanese: String = "") -> RCardExample {
                    let example = RCardExample()
                    example.id = id
                    example.cardId = "card-1"
                    example.ownerKey = owner
                    example.kind = kind.rawValue
                    example.serverExampleId = server
                    example.japanese = japanese
                    example.createdAt = exampleDate
                    example.updatedAt = exampleDate
                    return example
                }
                let edited = example("u1|card-1|s1", owner: "u1", kind: .edited, server: "s1", japanese: "犬が好き。")
                edited.reading = "いぬがすき。"
                edited.translation = "Thích chó."
                realm.add([edited,
                           example("u1|card-1|s2", owner: "u1", kind: .hidden, server: "s2"),
                           example("custom-1", owner: "", kind: .custom, server: "", japanese: "犬を飼う。")])
            }
        }
        return (deckDate, exampleDate)
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

/// `RReviewState` as the first schema-5 build wrote it, with the column that was removed afterwards.
final class EarlierReviewState: Object {
    override class func _realmObjectName() -> String? { "RReviewState" }

    @Persisted(primaryKey: true) var recordId: String
    @Persisted(indexed: true) var ownerKey: String
    @Persisted(indexed: true) var cardId: String
    @Persisted var skill: String
    @Persisted var contentVersion: String
    @Persisted var algorithm: String
    @Persisted var stability: Double
    @Persisted var difficulty: Double
    @Persisted(indexed: true) var due: Date
    @Persisted var lastReview: Date
    @Persisted var reviews: Int
    @Persisted var lapses: Int
    @Persisted var lastAttemptId: String
}
