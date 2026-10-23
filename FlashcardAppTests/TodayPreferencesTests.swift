import XCTest
@testable import FlashcardApp

final class TodayPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var preferences: UserDefaultsTodayPreferences!
    private let suiteName = "today-preferences-\(UUID().uuidString)"
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        preferences = UserDefaultsTodayPreferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_nothingIsChosenUntilTheLearnerChoosesAndTheSessionDefaultsToFiveMinutes() {
        XCTAssertNil(preferences.selectedDeckID(ownerKey: owner))
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: owner), 5)
    }

    func test_theChoiceIsKeptPerLearnerAndForTheSignedOutLearner() {
        preferences.setSelectedDeckID("deck-a", ownerKey: owner)
        preferences.setSelectedDeckID("deck-b", ownerKey: other)
        preferences.setSelectedDeckID("deck-guest", ownerKey: "")
        preferences.setBudgetMinutes(10, ownerKey: owner)
        preferences.setBudgetMinutes(3, ownerKey: "")

        XCTAssertEqual(preferences.selectedDeckID(ownerKey: owner), "deck-a")
        XCTAssertEqual(preferences.selectedDeckID(ownerKey: other), "deck-b")
        XCTAssertEqual(preferences.selectedDeckID(ownerKey: ""), "deck-guest")
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: owner), 10)
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: other), 5, "Another learner is not affected")
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: ""), 3)
    }

    func test_theChoiceSurvivesANewInstanceOverTheSameStorage() {
        preferences.setSelectedDeckID("deck-a", ownerKey: owner)
        preferences.setBudgetMinutes(3, ownerKey: owner)
        let again = UserDefaultsTodayPreferences(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(again.selectedDeckID(ownerKey: owner), "deck-a")
        XCTAssertEqual(again.budgetMinutes(ownerKey: owner), 3)
    }

    func test_clearingTheChoiceLeavesNone() {
        preferences.setSelectedDeckID("deck-a", ownerKey: owner)
        preferences.setSelectedDeckID(nil, ownerKey: owner)
        XCTAssertNil(preferences.selectedDeckID(ownerKey: owner))
    }

    func test_aTimeThatIsNotOfferedIsNeverKeptOrReturned() {
        preferences.setBudgetMinutes(7, ownerKey: owner)
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: owner), 5)
        defaults.set(99, forKey: "com.flashcardapp.today.budget.\(owner)")
        XCTAssertEqual(preferences.budgetMinutes(ownerKey: owner), 5, "A value from elsewhere is not trusted either")
    }
}
