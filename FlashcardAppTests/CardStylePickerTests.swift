import XCTest
@testable import FlashcardApp

final class CardStylePickerTests: XCTestCase {
    private var preferences: PickerPreferences!
    private var wireframe: PickerWireframe!
    private var view: PickerView!
    private var changes = 0

    override func setUp() {
        super.setUp()
        preferences = PickerPreferences()
        wireframe = PickerWireframe()
        view = PickerView()
        changes = 0
    }

    private func makePresenter(selected: String?) -> CardStylePickerPresenter {
        let presenter = CardStylePickerPresenter(selectedSlug: selected, preferences: preferences, wireframe: wireframe) { [unowned self] in changes += 1 }
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    func test_theDefaultCardComesFirstThenTheCatalogue() throws {
        _ = makePresenter(selected: nil)
        let state = try XCTUnwrap(view.states.last)
        XCTAssertEqual(state.options.map(\.slug), [nil] + CardStyle.catalog.map(\.slug))
        XCTAssertNil(state.selectedSlug)
        XCTAssertEqual(state.options.first?.title, NSLocalizedString("Default", comment: ""))
    }

    func test_theCurrentStyleIsMarkedSelected() {
        _ = makePresenter(selected: "ocean-calm")
        XCTAssertEqual(view.states.last?.selectedSlug, "ocean-calm")
    }

    func test_anUnknownSavedStyleIsShownAsTheDefaultCard() {
        _ = makePresenter(selected: "removed-style")
        XCTAssertNil(view.states.last?.selectedSlug)
    }

    func test_choosingAStyleStoresItAtOnceAndTellsTheStudyScreen() {
        let presenter = makePresenter(selected: nil)
        presenter.select(CardStyleOption(style: .goldCalligraphy))
        XCTAssertEqual(preferences.cardStyleSlug, "gold-calligraphy")
        XCTAssertEqual(view.states.last?.selectedSlug, "gold-calligraphy")
        XCTAssertEqual(changes, 1)
    }

    func test_choosingTheSameStyleAgainDoesNothing() {
        let presenter = makePresenter(selected: "dark-focus")
        let renders = view.states.count
        presenter.select(CardStyleOption(style: .darkFocus))
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(view.states.count, renders)
    }

    func test_choosingTheDefaultCardClearsTheStoredStyle() {
        preferences.cardStyleSlug = "sakura-bloom"
        let presenter = makePresenter(selected: "sakura-bloom")
        presenter.select(CardStyleOption(style: nil))
        XCTAssertNil(preferences.cardStyleSlug)
        XCTAssertNil(view.states.last?.selectedSlug)
        XCTAssertEqual(changes, 1)
    }

    func test_closingAsksTheWireframeToDismissTheSheet() {
        makePresenter(selected: nil).close()
        XCTAssertEqual(wireframe.finishCount, 1)
    }

    func test_preferencesStoreAndClearTheSlug() {
        let defaults = UserDefaults(suiteName: "CardStylePickerTests-\(UUID().uuidString)")!
        let store = UserDefaultsStudyPreferences(defaults: defaults)
        XCTAssertNil(store.cardStyleSlug)
        XCTAssertTrue(store.areExamplesVisible, "Sentences are shown by default")
        store.cardStyleSlug = "neon-tokyo"
        store.areExamplesVisible = false
        XCTAssertEqual(UserDefaultsStudyPreferences(defaults: defaults).cardStyleSlug, "neon-tokyo")
        XCTAssertFalse(UserDefaultsStudyPreferences(defaults: defaults).areExamplesVisible)
        store.cardStyleSlug = nil
        XCTAssertNil(UserDefaultsStudyPreferences(defaults: defaults).cardStyleSlug)
    }
}

private final class PickerView: CardStylePickerViewInterface {
    var states: [CardStylePickerState] = []
    func render(_ state: CardStylePickerState) { states.append(state) }
}

private final class PickerWireframe: CardStylePickerWireframeInterface {
    var finishCount = 0
    func finish() { finishCount += 1 }
}

private final class PickerPreferences: StudyPreferencesInterface {
    var isReadingVisible = true
    var areImagesVisible = true
    var autoSpeak = false
    var isShuffled = false
    var mode: StudyMode = .flip
    var cardStyleSlug: String?
    var areExamplesVisible = true
}
