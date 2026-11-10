import XCTest
@testable import FlashcardApp

final class DictionaryHistoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsDictionaryHistoryStore!
    private let suite = "DictionaryHistoryTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = UserDefaultsDictionaryHistoryStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testQueriesAreNewestFirstAndAQueryAppearsOnce() {
        store.recordQuery("食べる")
        store.recordQuery("ăn")
        store.recordQuery("食べる")
        XCTAssertEqual(store.recentQueries, ["食べる", "ăn"])
    }

    func testRepeatedQueryIgnoresCase() {
        store.recordQuery("Taberu")
        store.recordQuery("taberu")
        XCTAssertEqual(store.recentQueries, ["taberu"])
    }

    func testQueriesTheSearchWouldRejectAreNotRemembered() {
        store.recordQuery("  ")
        store.recordQuery("a")
        XCTAssertTrue(store.recentQueries.isEmpty)
    }

    func testQueriesAreBounded() {
        for number in 0..<(UserDefaultsDictionaryHistoryStore.queryLimit + 5) { store.recordQuery("語\(number)") }
        XCTAssertEqual(store.recentQueries.count, UserDefaultsDictionaryHistoryStore.queryLimit)
        XCTAssertEqual(store.recentQueries.first, "語\(UserDefaultsDictionaryHistoryStore.queryLimit + 4)")
    }

    func testOneQueryCanBeRemovedAndTheRestCleared() {
        store.recordQuery("食べる")
        store.recordQuery("飲む")
        store.removeQuery("食べる")
        XCTAssertEqual(store.recentQueries, ["飲む"])
        store.clearQueries()
        XCTAssertTrue(store.recentQueries.isEmpty)
    }

    func testViewedEntriesKeepTheirBackendIdentityAndMoveToTheFrontWhenOpenedAgain() {
        let eat = DictionaryItem(kind: .vocabulary, id: "9adc769d-2d6f-48a1-a9ca-5fe729033518", title: "食べる", reading: "たべる", meaning: "ăn", level: "N5")
        let drink = DictionaryItem(kind: .vocabulary, id: "11111111-2222-3333-4444-555555555555", title: "飲む")
        store.recordItem(eat)
        store.recordItem(drink)
        store.recordItem(eat)
        XCTAssertEqual(store.recentItems, [eat, drink])
        XCTAssertEqual(store.recentItems.first?.id, "9adc769d-2d6f-48a1-a9ca-5fe729033518")
    }

    func testTheSameIdOfAnotherKindIsAnotherEntry() {
        store.recordItem(DictionaryItem(kind: .vocabulary, id: "x", title: "日"))
        store.recordItem(DictionaryItem(kind: .kanji, id: "x", title: "日"))
        XCTAssertEqual(store.recentItems.count, 2)
    }

    func testViewedEntriesAreBoundedAndCanBeRemovedOrCleared() {
        for number in 0..<(UserDefaultsDictionaryHistoryStore.itemLimit + 3) {
            store.recordItem(DictionaryItem(kind: .vocabulary, id: "id\(number)", title: "語\(number)"))
        }
        XCTAssertEqual(store.recentItems.count, UserDefaultsDictionaryHistoryStore.itemLimit)
        let newest = store.recentItems[0]
        store.removeItem(newest)
        XCTAssertFalse(store.recentItems.contains(newest))
        store.clearItems()
        XCTAssertTrue(store.recentItems.isEmpty)
    }

    func testDamagedStoredDataIsTreatedAsEmpty() {
        defaults.set(Data("not json".utf8), forKey: "com.flashcardapp.dictionary.recentItems")
        XCTAssertTrue(store.recentItems.isEmpty)
        store.recordItem(DictionaryItem(kind: .grammar, id: "g", title: "ても"))
        XCTAssertEqual(store.recentItems.count, 1)
    }

    func testItemsAreBuiltFromSearchRowsOfKnownKindsOnly() {
        let row = BJTSearchResultDTO(id: "a", kind: "example", title: "食べるな。", description: " Cấm ăn. ", reading: "たべるな。", jlptLevel: nil)
        XCTAssertEqual(DictionaryItem(row), DictionaryItem(kind: .sentence, id: "a", title: "食べるな。", reading: "たべるな。", meaning: "Cấm ăn.", level: nil))
        XCTAssertNil(DictionaryItem(BJTSearchResultDTO(id: "l", kind: "lesson", title: "Bài", description: nil, reading: nil, jlptLevel: nil)))
        XCTAssertNil(DictionaryItem(BJTSearchResultDTO(id: "", kind: "lexeme", title: "x", description: nil, reading: nil, jlptLevel: nil)))
    }

    func testSummaryReadsAsWordReadingMeaning() {
        let item = DictionaryItem(kind: .vocabulary, id: "x", title: "食べる", reading: "たべる", meaning: "ăn")
        XCTAssertEqual(item.summary, "食べる（たべる） — ăn")
        XCTAssertEqual(DictionaryItem(kind: .vocabulary, id: "x", title: "ありがとう", reading: "ありがとう").summary, "ありがとう")
    }
}
