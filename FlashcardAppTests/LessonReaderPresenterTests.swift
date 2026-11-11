import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

final class LessonReaderPresenterTests: XCTestCase {
    private let slug = "j5-01-greetings-intro"
    private var interactor: ReaderInteractorStub!
    private var language: AppLanguage = .vietnamese

    override func setUp() {
        super.setUp()
        interactor = ReaderInteractorStub()
        language = .vietnamese
    }

    private func makePresenter() -> LessonReaderPresenter {
        LessonReaderPresenter(slug: slug, title: "Tiêu đề danh sách", interactor: interactor, language: { [unowned self] in language },
                              progressStore: FailingProgressStore(), ownerKey: { "" })
    }

    private func lesson(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> BJTLessonDetailDTO {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(BJTLessonFixtures.j5Lesson01JSON.utf8)) as? [String: Any])
        edit(&object)
        return try JSONDecoder().decode(BJTLessonDetailDTO.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func editContent(_ object: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        var content = object["lessonContent"] as? [String: Any] ?? [:]
        edit(&content)
        object["lessonContent"] = content
    }

    func test_loadsTheLessonOnceAndShowsEverySectionInReadingOrder() throws {
        let presenter = makePresenter()
        XCTAssertEqual(presenter.title, "Tiêu đề danh sách", "The list's title is shown while the lesson loads")
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requested, [slug])
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.state, .loaded)
        XCTAssertEqual(presenter.sections.map(\.kind), [.context, .vocabulary, .grammar, .examples, .remember, .pitfalls])
        XCTAssertEqual(presenter.title, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
        XCTAssertEqual(presenter.minutes, 25)
        XCTAssertFalse(presenter.isFromCache)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 1)
    }

    func test_vocabularyGrammarAndExamplesAreTheServersTextUnchanged() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        let vocabulary = try XCTUnwrap(presenter.sections.first { $0.kind == .vocabulary })
        XCTAssertEqual(vocabulary.entries.count, 6)
        XCTAssertEqual(vocabulary.entries[0], ReaderEntry(headline: "初めまして", reading: "はじめまして", body: "rất hân hạnh"))
        let grammar = try XCTUnwrap(presenter.sections.first { $0.kind == .grammar })
        XCTAssertEqual(grammar.entries[0], ReaderEntry(headline: "～です", body: "Giới thiệu danh tính hoặc thông tin một cách lịch sự."))
        let examples = try XCTUnwrap(presenter.sections.first { $0.kind == .examples })
        XCTAssertEqual(examples.entries[0].headline, "新入社員：おはようございます。")
        XCTAssertEqual(examples.entries[0].body, "新入社員: Chào buổi sáng.")
        XCTAssertEqual(examples.entries[0].note, "Dùng khi gặp đồng nghiệp vào buổi sáng; nói rõ và vừa đủ trang trọng.")
        let pitfalls = try XCTUnwrap(presenter.sections.first { $0.kind == .pitfalls })
        XCTAssertEqual(pitfalls.entries.count, 3)
    }

    func test_contextCarriesTheScenarioFactsTheServerSent() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        let context = try XCTUnwrap(presenter.sections.first { $0.kind == .context })
        XCTAssertEqual(context.entries.first?.headline, "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 本時の焦点は「おはようございます。」です。")
        XCTAssertEqual(context.entries.first?.body, "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm của đơn vị là “Chào buổi sáng”.")
        let bodies = context.entries.compactMap(\.body)
        XCTAssertTrue(bodies.contains("chào khi bắt đầu ngày làm việc"), "goalVi")
        XCTAssertTrue(bodies.contains("người học cần tạo thiện cảm nhưng chưa biết vai trò của từng người."), "problemVi")
        XCTAssertTrue(bodies.contains("đối phương hiểu tên, bộ phận và mong muốn hợp tác của người nói."), "desiredOutcomeVi")
        XCTAssertTrue(bodies.contains("Chào, tự giới thiệu và kết thúc trao đổi ngắn đúng thời điểm."), "learning objectives")
        XCTAssertFalse(bodies.contains("senior-junior"), "A machine key such as the relationship code is not learner text")
    }

    func test_sectionsWithoutContentAreHiddenAndABlankReadingIsNotShown() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        let sparse = try lesson { object in
            editContent(&object) { content in
                content["grammar"] = []
                content["examples"] = nil
                content["vietnameseLearnerPitfalls"] = [" "]
                content["knowledgePoints"] = []
                content["nuanceNotesVi"] = []
                content["summaryVi"] = []
                content["businessUsageVi"] = ""
                content["politenessHierarchyVi"] = nil
                content["workplaceScenario"] = nil
                content["learningObjectives"] = []
                content["vocabulary"] = [["japanese": "挨拶", "reading": "", "meaningVi": "chào hỏi"]]
            }
        }
        interactor.respond(LessonReadResult(lesson: sparse, isFromCache: false))
        XCTAssertEqual(presenter.sections.map(\.kind), [.vocabulary])
        XCTAssertNil(presenter.sections[0].entries[0].reading)
    }

    func test_titleFollowsTheAppLanguageAndFallsBackToVietnamese() throws {
        language = .japanese
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.title, "職場の挨拶：おはようございます。")
        language = .english
        let english = makePresenter()
        english.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson { $0["titleJa"] = " " }, isFromCache: false))
        XCTAssertEqual(english.title, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
    }

    func test_aSavedCopyIsFlaggedSoTheScreenCanSaySo() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: true))
        XCTAssertTrue(presenter.isFromCache)
        XCTAssertEqual(presenter.state, .loaded)
    }

    func test_practiceIsOfferedWithTheServersActivityCountAndOpensTheLoadedLesson() throws {
        let presenter = makePresenter()
        let spy = ReaderWireframeSpy()
        presenter.wireframe = spy
        presenter.showPractice()
        XCTAssertTrue(spy.practised.isEmpty, "Nothing to practise before the lesson has loaded")
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.practiceActivityCount, 5, "From the payload, not an assumed number")
        XCTAssertTrue(presenter.isPracticeAvailable)
        presenter.showPractice()
        XCTAssertEqual(spy.practised.map(\.slug), [slug])
    }

    private func loadedPresenter(saver: LessonWordSaverInterface, wireframe: ReaderWireframeSpy, edit: (inout [String: Any]) -> Void = { _ in }) throws -> LessonReaderPresenter {
        let presenter = LessonReaderPresenter(slug: slug, title: "T", interactor: interactor, language: { .vietnamese },
                                              progressStore: FailingProgressStore(), ownerKey: { "" }, wordSaver: saver)
        presenter.wireframe = wireframe
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(edit), isFromCache: false))
        return presenter
    }

    func test_aChosenWordIsSavedToTheDeckTheLearnerPicks() throws {
        let saver = WordSaverStub()
        let wireframe = ReaderWireframeSpy()
        wireframe.pick = .existing(deckID: "deck-1")
        let presenter = try loadedPresenter(saver: saver, wireframe: wireframe)
        XCTAssertTrue(presenter.canSaveWords)
        presenter.saveWord(at: 1)
        XCTAssertEqual(wireframe.offeredChoices, [saver.decks], "The learner's own decks are offered")
        XCTAssertEqual(saver.saved.count, 1)
        XCTAssertEqual(saver.saved.first?.words, [LessonWord(japanese: "新入社員", reading: "しんにゅうしゃいん", meaning: "nhân viên mới")])
        XCTAssertEqual(saver.saved.first?.slug, slug)
        XCTAssertEqual(saver.saved.first?.target, .existing(deckID: "deck-1"))
        XCTAssertEqual(wireframe.messages.count, 1, "The result is reported")
    }

    func test_cancellingTheDeckChoiceSavesNothing() throws {
        let saver = WordSaverStub()
        let wireframe = ReaderWireframeSpy()
        wireframe.pick = nil
        let presenter = try loadedPresenter(saver: saver, wireframe: wireframe)
        presenter.saveWord(at: 0)
        presenter.saveAllWords()
        XCTAssertTrue(saver.saved.isEmpty)
        XCTAssertTrue(wireframe.messages.isEmpty)
    }

    func test_allWordsAreSavedTogetherInOneWrite() throws {
        let saver = WordSaverStub()
        let wireframe = ReaderWireframeSpy()
        wireframe.pick = .newDictionaryDeck
        let presenter = try loadedPresenter(saver: saver, wireframe: wireframe)
        presenter.saveAllWords()
        XCTAssertEqual(saver.saved.count, 1)
        XCTAssertEqual(saver.saved.first?.words.count, 6)
        XCTAssertEqual(saver.saved.first?.target, .newDictionaryDeck)
    }

    func test_aPositionOutsideTheVocabularyOrALessonWithoutWordsSavesNothing() throws {
        let saver = WordSaverStub()
        let wireframe = ReaderWireframeSpy()
        wireframe.pick = .newDictionaryDeck
        let presenter = try loadedPresenter(saver: saver, wireframe: wireframe)
        presenter.saveWord(at: 99)
        presenter.saveWord(at: -1)
        XCTAssertTrue(saver.saved.isEmpty)
        XCTAssertTrue(wireframe.offeredChoices.isEmpty, "No deck question for a word that does not exist")

        let empty = try loadedPresenter(saver: saver, wireframe: wireframe) { object in editContent(&object) { $0["vocabulary"] = [] } }
        XCTAssertFalse(empty.canSaveWords)
        empty.saveAllWords()
        XCTAssertTrue(saver.saved.isEmpty)
    }

    func test_aFailedSaveIsReportedAndNotShownAsSaved() throws {
        let saver = WordSaverStub()
        saver.error = AppError.databaseWriteFailed("disk full")
        let wireframe = ReaderWireframeSpy()
        wireframe.pick = .existing(deckID: "deck-1")
        let presenter = try loadedPresenter(saver: saver, wireframe: wireframe)
        presenter.saveWord(at: 0)
        XCTAssertEqual(wireframe.messages.count, 1)
        XCTAssertFalse(wireframe.messages[0].message.isEmpty)
        XCTAssertEqual(wireframe.messages[0].title, NSLocalizedString("Couldn't save the words", comment: ""))
    }

    func test_shadowingOffersTheServersExampleSentencesOnceLoaded() throws {
        let presenter = makePresenter()
        let spy = ReaderWireframeSpy()
        presenter.wireframe = spy
        presenter.showShadowing()
        XCTAssertTrue(spy.shadowed.isEmpty)
        presenter.viewDidLoad()
        let loaded = try lesson()
        interactor.respond(LessonReadResult(lesson: loaded, isFromCache: false))
        XCTAssertTrue(presenter.canShadow)
        presenter.showShadowing()
        XCTAssertEqual(spy.shadowed.first?.map(\.japanese), loaded.lessonContent.examples.map(\.japanese))
        XCTAssertEqual(spy.shadowed.first?.first?.translation, loaded.lessonContent.examples.first?.vietnamese)
    }

    func test_practiceIsNotOfferedForALessonWithoutActivities() throws {
        let presenter = makePresenter()
        let spy = ReaderWireframeSpy()
        presenter.wireframe = spy
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson { object in editContent(&object) { $0["activities"] = [] } }, isFromCache: false))
        XCTAssertFalse(presenter.isPracticeAvailable)
        presenter.showPractice()
        XCTAssertTrue(spy.practised.isEmpty)
    }

    func test_theReaderShowsWhereTheLearnerStandsAndRefreshesWhenComingBack() throws {
        RealmService.shared.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString, objectTypes: RealmService.storedTypes))
        defer { RealmService.shared.realm = nil }
        let store = RealmLessonProgressStore()
        let presenter = LessonReaderPresenter(slug: slug, title: "T", interactor: interactor, language: { .vietnamese }, progressStore: store, ownerKey: { "u1" })
        presenter.viewDidLoad()
        let loaded = try lesson()
        interactor.respond(LessonReadResult(lesson: loaded, isFromCache: false))
        XCTAssertEqual(presenter.practiceStatus, .notStarted)
        let ids = loaded.lessonContent.activities.map(\.id)
        let subject = LessonProgressSubject(slug: slug, lessonId: loaded.id, levelCode: "J5", sortOrder: 1, contentVersion: "", activityIds: ids)
        try store.recordAnswer(LessonAnswer(activityId: ids[0], optionKey: "A"), for: subject, ownerKey: "u1", at: Date())
        try store.recordAnswer(LessonAnswer(activityId: ids[1], optionKey: "A"), for: subject, ownerKey: "other", at: Date())
        presenter.viewDidLoad()   // back from practice
        XCTAssertEqual(presenter.practiceStatus, .inProgress(answered: 1, total: 5), "Only this account's answers count")
        XCTAssertEqual(interactor.requested.count, 1, "Coming back does not fetch the lesson again")
        for id in ids.dropFirst() { try store.recordAnswer(LessonAnswer(activityId: id, optionKey: "A"), for: subject, ownerKey: "u1", at: Date()) }
        try store.markCompleted(for: subject, ownerKey: "u1", at: Date())
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.practiceStatus, .completed)
    }

    func test_failureShowsAMessageAndOnlyRetryLoadsAgain() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.fail(LearnerAPIError.offline)
        XCTAssertEqual(presenter.state, .failed(LearnerAPIError.offline.errorDescription ?? ""))
        XCTAssertTrue(presenter.sections.isEmpty)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 1)
        presenter.retry()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requested.count, 2)
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.state, .loaded)
    }

    func test_leavingCancelsTheRequestAndALateAnswerIsIgnored() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.cancelLoading()
        XCTAssertEqual(interactor.cancelledCount, 1)
        XCTAssertEqual(presenter.state, .idle)
        interactor.respondToFirst(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertTrue(presenter.sections.isEmpty)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 2)
    }

    func test_retryWhileLoadingStartsNoSecondRequest() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.retry()
        XCTAssertEqual(interactor.requested.count, 1)
    }
}

final class ReaderWireframeSpy: LessonReaderWireframeInterface {
    private(set) var practised: [BJTLessonDetailDTO] = []
    private(set) var offeredChoices: [[TodayDeckChoice]] = []
    private(set) var messages: [(title: String, message: String)] = []
    var pick: DictionaryDeckTarget?
    func showPractice(lesson: BJTLessonDetailDTO) { practised.append(lesson) }
    private(set) var shadowed: [[ShadowingSentence]] = []
    func showShadowing(sentences: [ShadowingSentence]) { shadowed.append(sentences) }
    func chooseDeck(from choices: [TodayDeckChoice], completion: @escaping (DictionaryDeckTarget?) -> Void) {
        offeredChoices.append(choices)
        completion(pick)
    }
    func showMessage(title: String, message: String) { messages.append((title, message)) }
}

final class WordSaverStub: LessonWordSaverInterface {
    let decks = [TodayDeckChoice(id: "deck-1", name: "My words", cardCount: 2)]
    var error: Error?
    private(set) var saved: [(words: [LessonWord], slug: String, target: DictionaryDeckTarget)] = []
    func choices() -> [TodayDeckChoice] { decks }
    func save(_ words: [LessonWord], fromLesson slug: String, to target: DictionaryDeckTarget) throws -> LessonWordSaveOutcome {
        if let error { throw error }
        saved.append((words, slug, target))
        return LessonWordSaveOutcome(deckID: "deck-1", deckName: "My words", added: words.count, alreadyThere: 0, skipped: 0)
    }
}

final class ReaderInteractorStub: LessonReaderInteractorInterface {
    private(set) var requested: [String] = []
    private(set) var cancelledCount = 0
    private var requests: [PublishSubject<LessonReadResult>] = []

    func lesson(slug: String) -> Single<LessonReadResult> {
        requested.append(slug)
        let subject = PublishSubject<LessonReadResult>()
        requests.append(subject)
        return subject.take(1).asSingle().do(onDispose: { [weak self] in self?.cancelledCount += 1 })
    }

    func respond(_ result: LessonReadResult) { requests.last?.onNext(result) }
    func respondToFirst(_ result: LessonReadResult) { requests.first?.onNext(result) }
    func fail(_ error: Error) { requests.last?.onError(error) }
}
