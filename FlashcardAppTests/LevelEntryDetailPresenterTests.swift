import RxSwift
import UIKit
import XCTest
@testable import FlashcardApp

final class LevelEntryDetailPresenterTests: XCTestCase {
    private let validUUID = "d5e13c40-fad5-4042-a364-b22e66b8b9b9"

    func testVocabularyStateRendersHeadwordReadingSensesAndDictionaryAction() {
        let entry = LevelEntry(
            id: validUUID,
            kind: .vocabulary,
            levelCode: "J4",
            levelName: "J4 — Sơ trung cấp",
            title: "あっ",
            reading: "アッ あっ あ",
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: "a!; ôi; này",
            explanations: ["A!, Ôi!", "Này!"],
            hasLessons: true
        )
        let view = LevelEntryDetailViewSpy()
        let wireframe = LevelEntryDetailWireframeSpy()
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: wireframe, speech: SpeechStub())
        presenter.view = view

        presenter.viewDidLoad()

        XCTAssertEqual(view.rendered?.eyebrow, "J4 · \(HomeContentKind.vocabulary.title)")
        XCTAssertEqual(view.rendered?.title, "あっ")
        XCTAssertEqual(view.rendered?.isKanjiGlyph, false)
        XCTAssertEqual(view.rendered?.reading, "アッ あっ あ")
        XCTAssertEqual(view.rendered?.shortMeaning, "a!; ôi; này")
        XCTAssertEqual(view.rendered?.detailItems, ["A!, Ôi!", "Này!"])
        XCTAssertEqual(view.rendered?.hasBodyContent, true)
        XCTAssertEqual(view.rendered?.canOpenDictionary, true)
        XCTAssertNotNil(view.rendered?.lessonsButtonTitle)

        presenter.openDictionaryEntry()
        XCTAssertEqual(wireframe.openedDictionaryItem?.id, validUUID)
        XCTAssertEqual(wireframe.openedDictionaryItem?.kind, .vocabulary)
        XCTAssertEqual(wireframe.openedDictionaryItem?.level, "J4")

        presenter.openLessons()
        XCTAssertEqual(wireframe.openedLessonsCount, 1)
    }

    func testKanjiStateKeepsOnyomiAndKunyomiSeparateAndSpeaksReading() {
        let entry = LevelEntry(
            id: validUUID,
            kind: .kanji,
            levelCode: "J4",
            levelName: "J4 — Sơ trung cấp",
            title: "会",
            reading: "カイ エ · あ.う",
            onyomi: "カイ エ",
            kunyomi: "あ.う あ.わせる",
            shortMeaning: "hội, gặp",
            explanations: [],
            hasLessons: true
        )
        let view = LevelEntryDetailViewSpy()
        let speech = SpeechStub()
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: LevelEntryDetailWireframeSpy(),
                                                  speech: speech, hasJapaneseVoice: { true })
        presenter.view = view

        presenter.viewDidLoad()

        XCTAssertEqual(view.rendered?.isKanjiGlyph, true)
        XCTAssertNil(view.rendered?.reading)
        XCTAssertEqual(view.rendered?.onyomi, "カイ エ")
        XCTAssertEqual(view.rendered?.kunyomi, "あ.う あ.わせる")
        XCTAssertEqual(view.rendered?.shortMeaning, "hội, gặp")
        XCTAssertEqual(view.rendered?.canOpenDictionary, true)

        presenter.speak()
        XCTAssertEqual(speech.spokenText, "あう")
        XCTAssertEqual(speech.spokenLanguage, "ja-JP")
    }

    func testGrammarEntryWithNoUUIDAndEmptyMeaningShowsEmptyStateAndNoDictionaryButton() {
        let entry = LevelEntry(
            id: "not-a-uuid",
            kind: .grammar,
            levelCode: "J1+",
            levelName: "J1+",
            title: "〜にすぎない",
            reading: nil,
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: nil,
            explanations: [],
            hasLessons: false
        )
        let view = LevelEntryDetailViewSpy()
        let wireframe = LevelEntryDetailWireframeSpy()
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: wireframe, speech: SpeechStub())
        presenter.view = view

        presenter.viewDidLoad()

        XCTAssertEqual(view.rendered?.hasBodyContent, false)
        XCTAssertEqual(view.rendered?.canOpenDictionary, false)
        XCTAssertNil(view.rendered?.lessonsButtonTitle)

        presenter.openDictionaryEntry()
        presenter.openLessons()
        XCTAssertNil(wireframe.openedDictionaryItem)
        XCTAssertEqual(wireframe.openedLessonsCount, 0)
    }

    func testSingleExplanationMatchingShortMeaningIsNotDuplicated() {
        let entry = LevelEntry(
            id: validUUID,
            kind: .vocabulary,
            levelCode: "J5",
            levelName: "J5",
            title: "猫",
            reading: "ねこ",
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: "con mèo",
            explanations: ["con mèo"],
            hasLessons: true
        )
        let state = LevelEntryDetailPresenter.makeState(for: entry)
        XCTAssertTrue(state.detailItems.isEmpty)
        XCTAssertNil(state.detailSectionTitle)
    }

    func testMissingJapaneseVoicePromptsVoiceUnavailableInsteadOfSpeaking() {
        let entry = LevelEntry(
            id: validUUID, kind: .vocabulary, levelCode: "J5", levelName: "J5",
            title: "猫", reading: "ねこ", onyomi: nil, kunyomi: nil, shortMeaning: "mèo",
            explanations: [], hasLessons: false
        )
        let view = LevelEntryDetailViewSpy()
        let speech = SpeechStub()
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: LevelEntryDetailWireframeSpy(),
                                                  speech: speech, hasJapaneseVoice: { false })
        presenter.view = view

        presenter.speak()

        XCTAssertNil(speech.spokenText)
        XCTAssertEqual(view.voiceUnavailableCount, 1)
    }

    func testCopyAndShareUseFormattedSummary() {
        let entry = LevelEntry(
            id: validUUID, kind: .vocabulary, levelCode: "J5", levelName: "J5",
            title: "猫", reading: "ねこ", onyomi: nil, kunyomi: nil, shortMeaning: "con mèo",
            explanations: ["Con mèo nhà"], hasLessons: false
        )
        var copied: String?
        let view = LevelEntryDetailViewSpy()
        let wireframe = LevelEntryDetailWireframeSpy()
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: wireframe, speech: SpeechStub(),
                                                  copyToPasteboard: { copied = $0 })
        presenter.view = view

        presenter.copySummary()
        XCTAssertEqual(copied, "猫（ねこ）\ncon mèo\nCon mèo nhà")
        XCTAssertEqual(view.toasts.count, 1)

        presenter.share()
        XCTAssertEqual(wireframe.sharedText, copied)
    }

    func testVocabularySpeaksFirstReadingTokenAndGrammarDisablesListenForMetaPatterns() {
        let vocab = LevelEntry(
            id: validUUID,
            kind: .vocabulary,
            levelCode: "J5",
            levelName: "J5",
            title: "一日",
            reading: "ついたち いちにち",
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: "mùng một",
            explanations: [],
            hasLessons: false
        )
        let speech = SpeechStub()
        let vocabPresenter = LevelEntryDetailPresenter(entry: vocab, wireframe: LevelEntryDetailWireframeSpy(),
                                                       speech: speech, hasJapaneseVoice: { true })
        vocabPresenter.speak()
        XCTAssertEqual(speech.spokenText, "ついたち", "Vocabulary TTS must speak the entry's first kana reading rather than an ambiguous kanji headword")

        let grammar = LevelEntry(
            id: validUUID,
            kind: .grammar,
            levelCode: "J4",
            levelName: "J4",
            title: "… いぜん",
            reading: nil,
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: "Trước khi nói tới ...",
            explanations: ["Diễn tả tình trạng chưa đạt tới giai đoạn."],
            hasLessons: true
        )
        let grammarView = LevelEntryDetailViewSpy()
        let grammarSpeech = SpeechStub()
        let grammarPresenter = LevelEntryDetailPresenter(entry: grammar, wireframe: LevelEntryDetailWireframeSpy(),
                                                         speech: grammarSpeech, hasJapaneseVoice: { true })
        grammarPresenter.view = grammarView
        grammarPresenter.viewDidLoad()
        grammarPresenter.speak()

        XCTAssertEqual(grammarView.rendered?.canSpeak, false, "Grammar meta-patterns like '… いぜん' must not offer TTS")
        XCTAssertNil(grammarSpeech.spokenText)
    }

    func testCrossTabLookUpLoadsColdDictionaryTabBeforeEmittingQuery() throws {
        let entry = LevelEntry(
            id: validUUID,
            kind: .vocabulary,
            levelCode: "J4",
            levelName: "J4 — Sơ trung cấp",
            title: "あっ",
            reading: "あっ",
            onyomi: nil,
            kunyomi: nil,
            shortMeaning: "a!; ôi",
            explanations: [],
            hasLessons: false
        )
        let detailWireframe = LevelEntryDetailWireframe(entry: entry, level: nil)
        let detailVC = detailWireframe.viewController
        let todayNav = UINavigationController(rootViewController: detailVC)

        let dictInteractor = ColdDictionaryInteractorSpy()
        let dictVC = DictionaryViewController()
        let dictPresenter = DictionaryPresenter(interactor: dictInteractor, wireframe: DummyDictionaryWireframe(), debounce: .milliseconds(0))
        dictVC.presenter = dictPresenter
        let dictNav = UINavigationController(rootViewController: dictVC)

        let tabs = UITabBarController()
        tabs.viewControllers = [todayNav, dictNav]
        tabs.selectedIndex = MainTab.today.rawValue
        XCTAssertFalse(dictVC.isViewLoaded, "Precondition: Dictionary tab view has not loaded before first visit")

        detailVC.presenter.openDictionaryEntry()
        let pushedEntryVC = try XCTUnwrap(todayNav.viewControllers.last as? DictionaryEntryViewController)
        pushedEntryVC.presenter.lookUp("会議")
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(tabs.selectedIndex, MainTab.dictionary.rawValue)
        XCTAssertEqual(todayNav.viewControllers.count, 2, "Cross-tab lookup must preserve the source tab's navigation stack")
        XCTAssertTrue(dictVC.isViewLoaded, "DictionaryViewController must load its view before PublishRelay query emission")
        XCTAssertEqual(dictInteractor.searchedQueries, ["会議"])
        XCTAssertEqual(dictInteractor.recordedQueries, ["会議"])
    }
}

private final class ColdDictionaryInteractorSpy: DictionaryInteractorInterface {
    var searchedQueries: [String] = []
    var recordedQueries: [String] = []
    var recentQueries: [String] { recordedQueries }
    var recentItems: [DictionaryItem] { [] }
    func search(_ query: String, type: DictionarySearchType, offset: Int) -> Single<[BJTSearchResultDTO]> {
        searchedQueries.append(query)
        return .just([])
    }
    func recordQuery(_ query: String) { recordedQueries.append(query) }
    func removeQuery(_ query: String) {}
    func clearQueries() {}
    func removeItem(_ item: DictionaryItem) {}
    func clearItems() {}
}

private final class DummyDictionaryWireframe: DictionaryWireframeInterface {
    func showEntry(_ item: DictionaryItem) {}
    func showSaved() {}
    func showScanner() {}
    func showVoice() {}
    func showHandwriting() {}
}

private final class LevelEntryDetailViewSpy: LevelEntryDetailViewInterface {
    var rendered: LevelEntryDetailState?
    var toasts: [String] = []
    var voiceUnavailableCount = 0
    func render(_ state: LevelEntryDetailState) { rendered = state }
    func showToast(_ message: String) { toasts.append(message) }
    func showVoiceUnavailable() { voiceUnavailableCount += 1 }
}

private final class LevelEntryDetailWireframeSpy: LevelEntryDetailWireframeInterface {
    var openedDictionaryItem: DictionaryItem?
    var openedLessonsCount = 0
    var sharedText: String?
    var openedSettingsCount = 0
    func showDictionaryEntry(_ item: DictionaryItem) { openedDictionaryItem = item }
    func showLessons() { openedLessonsCount += 1 }
    func share(_ text: String) { sharedText = text }
    func openSystemSettings() { openedSettingsCount += 1 }
}

private final class SpeechStub: SpeechServiceInterface {
    var spokenText: String?
    var spokenLanguage: String?
    var stopCount = 0
    func speak(_ text: String, languageCode: String) { spokenText = text; spokenLanguage = languageCode }
    func stop() { stopCount += 1 }
}
