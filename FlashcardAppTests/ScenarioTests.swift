import RxSwift
import XCTest
@testable import FlashcardApp

// MARK: Doubles

final class FakeScenarioInteractor: ScenarioInteractorInterface {
    var isSignedIn = true
    var catalogueResult: Single<[ScenarioSummary]> = .just([])
    var lessonResult: Single<ScenarioLesson> = .error(LearnerAPIError.notFound)
    /// Consumed in order, one per check; an exhausted queue answers "natural".
    var answers: [Single<ScenarioAnswer>] = []
    var completeResults: [Single<Void>] = []
    private(set) var catalogueCalls = 0
    private(set) var checked: [(stepID: String, key: String)] = []
    private(set) var completions: [(lessonID: String, choices: [String])] = []

    func catalogue() -> Single<[ScenarioSummary]> { catalogueCalls += 1; return catalogueResult }
    func lesson(id: String) -> Single<ScenarioLesson> { lessonResult }
    func answer(stepID: String, choiceKey: String) -> Single<ScenarioAnswer> {
        checked.append((stepID, choiceKey))
        return answers.isEmpty ? .just(ScenarioAnswer(choiceKey: choiceKey, isNatural: true)) : answers.removeFirst()
    }
    func complete(lessonID: String, choices: [(stepOrder: Int, choiceKey: String)]) -> Single<Void> {
        completions.append((lessonID, choices.map { "\($0.stepOrder)\($0.choiceKey)" }))
        return completeResults.isEmpty ? .just(()) : completeResults.removeFirst()
    }
}

final class SpyScenarioListView: ScenarioListViewInterface {
    var states: [ScenarioListState] = []
    func render(_ state: ScenarioListState) { states.append(state) }
    var last: ScenarioListState { states.last ?? ScenarioListState() }
}

final class FakeScenarioListWireframe: ScenarioListWireframeInterface {
    private(set) var opened: [(summary: ScenarioSummary, ordered: [String])] = []
    var signInFinish: (() -> Void)?
    private(set) var signInCount = 0
    func showScenario(_ summary: ScenarioSummary, ordered: [ScenarioSummary]) { opened.append((summary, ordered.map(\.id))) }
    func showSignIn(onFinish: @escaping () -> Void) { signInCount += 1; signInFinish = onFinish }
}

final class SpyScenarioPlayView: ScenarioPlayViewInterface {
    var states: [ScenarioPlayState] = []
    func render(_ state: ScenarioPlayState) { states.append(state) }
    var last: ScenarioPlayState { states.last ?? ScenarioPlayState() }
}

final class FakeScenarioPlayWireframe: ScenarioPlayWireframeInterface {
    private(set) var next: [ScenarioSummary] = []
    private(set) var leaves = 0
    func showNext(_ summary: ScenarioSummary) { next.append(summary) }
    func leave() { leaves += 1 }
}

private final class SpyScenarioSpeech: SpeechServiceInterface {
    private(set) var spoken: [(String, String)] = []
    private(set) var stops = 0
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() { stops += 1 }
}

private func summary(_ id: String, _ category: String, vi: String, ja: String? = nil, language: AppLanguage = .vietnamese) -> ScenarioSummary {
    ScenarioSummary(id: id, categoryKey: category, title: ScenarioText(vietnamese: vi, japanese: ja, language: language),
                    searchText: [vi, ja, ScenarioCategory.title(forKey: category)].compactMap { $0 }.joined(separator: " "))
}

private func lesson(id: String = "L1", steps: Int = 2) -> ScenarioLesson {
    ScenarioLesson(id: id, title: ScenarioText(vietnamese: "Cắt tóc", japanese: "髪を切る", language: .vietnamese), categoryKey: "beauty",
                   steps: (1...steps).map { order in
        ScenarioStep(id: "S\(order)", order: order, situation: ScenarioText(vietnamese: "Tình huống \(order)", japanese: "場面\(order)", language: .vietnamese), speaker: nil,
                     choices: [ScenarioChoice(key: "A", phrase: ScenarioText(vietnamese: "Câu A\(order)", japanese: "A\(order)です", language: .japanese), japanese: "A\(order)です"),
                               ScenarioChoice(key: "B", phrase: ScenarioText(vietnamese: "Câu B\(order)", japanese: "B\(order)です", language: .japanese), japanese: "B\(order)です")])
    })
}

// MARK: Entities

final class ScenarioEntityTests: XCTestCase {
    func test_vietnameseReadersLeadWithVietnameseAndEveryoneElseWithJapanese() {
        let vi = ScenarioText(vietnamese: "Cắt tóc", japanese: "髪を切る", language: .vietnamese)
        XCTAssertEqual(vi.primary, "Cắt tóc")
        XCTAssertEqual(vi.secondary, "髪を切る")
        for language in [AppLanguage.english, .japanese] {
            let text = ScenarioText(vietnamese: "Cắt tóc", japanese: "髪を切る", language: language)
            XCTAssertEqual(text.primary, "髪を切る", "the Japanese is what is being learned")
            XCTAssertEqual(text.secondary, "Cắt tóc", "Vietnamese is the only translation the server has")
        }
    }

    func test_aMissingOrBlankJapaneseTextFallsBackToVietnameseAlone() {
        for japanese in [nil, "", "  "] {
            let text = ScenarioText(vietnamese: "Cắt tóc", japanese: japanese, language: .japanese)
            XCTAssertEqual(text.primary, "Cắt tóc")
            XCTAssertNil(text.secondary)
        }
    }

    func test_knownGroupsComeInTheCuratedOrderAndUnknownOnesLastWithReadableNames() {
        let keys = ["zzz_extra", "beauty", "arrival", "health", "aaa-new"]
        XCTAssertEqual(keys.sorted(by: ScenarioCategory.sortsBefore), ["arrival", "health", "beauty", "aaa-new", "zzz_extra"])
        XCTAssertEqual(ScenarioCategory.title(forKey: "pet_care"), "Pet care")
        XCTAssertEqual(ScenarioCategory.symbol(forKey: "pet_care"), "text.bubble")
        XCTAssertEqual(ScenarioCategory.symbol(forKey: "beauty"), "scissors")
    }

    func test_everyKnownGroupHasASymbolThatExists() {
        for category in ScenarioCategory.allCases {
            XCTAssertNotNil(UIImage(systemName: category.symbol), "\(category.rawValue) uses a symbol that does not exist")
            XCTAssertFalse(category.title.isEmpty)
        }
    }

    private func dto(steps: [BJTScenarioDetailDTO.Step]) -> BJTScenarioDetailDTO {
        BJTScenarioDetailDTO(id: "L1", slug: "s", titleVi: "Cắt tóc", titleJa: "髪を切る", descriptionVi: nil, difficulty: "beginner", category: "beauty", estimatedMin: 2, steps: steps)
    }

    private func step(order: Int, choices: Int, japanese: String? = "日本語") -> BJTScenarioDetailDTO.Step {
        BJTScenarioDetailDTO.Step(id: "S\(order)", stepOrder: order, situationVi: "vi", situationJa: "ja", speakerName: "", speakerRole: nil,
                                  choices: (0..<choices).map { BJTScenarioDetailDTO.Choice(id: "c\($0)", choiceKey: ["A", "B", "C"][$0], textVi: "nghĩa", textJa: japanese) })
    }

    func test_aLessonIsOrderedByStepAndTheJapanesePhraseLeadsWhateverTheScreenLanguage() throws {
        let built = try XCTUnwrap(ScenarioLesson(dto: dto(steps: [step(order: 2, choices: 2), step(order: 1, choices: 2)]), language: .vietnamese))
        XCTAssertEqual(built.steps.map(\.order), [1, 2])
        XCTAssertNil(built.steps[0].speaker, "an empty speaker name is no speaker")
        XCTAssertEqual(built.steps[0].choices[0].phrase.primary, "日本語")
        XCTAssertEqual(built.steps[0].choices[0].phrase.secondary, "nghĩa")
        XCTAssertEqual(built.steps[0].choices[0].japanese, "日本語")
    }

    func test_aChoiceWithoutJapaneseShowsItsVietnameseAndIsNotSpoken() throws {
        let built = try XCTUnwrap(ScenarioLesson(dto: dto(steps: [step(order: 1, choices: 2, japanese: nil)]), language: .vietnamese))
        XCTAssertEqual(built.steps[0].choices[0].phrase.primary, "nghĩa")
        XCTAssertNil(built.steps[0].choices[0].japanese)
    }

    func test_aLessonWithNothingToChooseFromIsNotPlayable() {
        XCTAssertNil(ScenarioLesson(dto: dto(steps: []), language: .vietnamese))
        XCTAssertNil(ScenarioLesson(dto: dto(steps: [step(order: 1, choices: 1)]), language: .vietnamese))
    }
}

// MARK: List

final class ScenarioListPresenterTests: XCTestCase {
    private var interactor: FakeScenarioInteractor!
    private var wireframe: FakeScenarioListWireframe!
    private var view: SpyScenarioListView!
    private var presenter: ScenarioListPresenter!

    private let catalogue = [
        summary("1", "health", vi: "Khám bệnh ở bệnh viện", ja: "病院で診てもらう"),
        summary("2", "beauty", vi: "Dặn thợ cắt tóc ngắn hơn", ja: "髪を少し短く切る"),
        summary("3", "beauty", vi: "Đặt lịch làm móng", ja: "ネイルの予約をする"),
        summary("4", "arrival", vi: "Hỏi hành lý ở sân bay", ja: "預けた荷物を確認する")
    ]

    override func setUp() {
        super.setUp()
        interactor = FakeScenarioInteractor()
        wireframe = FakeScenarioListWireframe()
        view = SpyScenarioListView()
        presenter = ScenarioListPresenter(interactor: interactor, wireframe: wireframe)
        presenter.view = view
    }

    private func load() {
        interactor.catalogueResult = .just(catalogue)
        presenter.viewDidLoad()
    }

    func test_situationsAreGroupedInTheCuratedOrderWithAChipPerGroup() {
        load()
        XCTAssertEqual(view.last.screen, .content)
        XCTAssertEqual(view.last.sections.map(\.key), ["arrival", "health", "beauty"])
        XCTAssertEqual(view.last.sections[2].rows.map(\.id), ["2", "3"], "the server's order is kept inside a group")
        XCTAssertEqual(view.last.chips.map(\.key), ["arrival", "health", "beauty"])
        XCTAssertEqual(view.last.sections[2].symbol, "scissors")
        XCTAssertFalse(view.last.totalText.isEmpty)
    }

    func test_aSignedOutLearnerIsAskedToSignInAndTheServerIsNotCalled() {
        interactor.isSignedIn = false
        presenter.viewDidLoad()
        XCTAssertEqual(view.last.screen, .signInRequired)
        XCTAssertEqual(interactor.catalogueCalls, 0)
        presenter.signIn()
        XCTAssertEqual(wireframe.signInCount, 1)
        interactor.isSignedIn = true
        interactor.catalogueResult = .just(catalogue)
        wireframe.signInFinish?()
        XCTAssertEqual(view.last.screen, .content, "the catalogue loads as soon as sign-in finishes")
    }

    func test_aFailureCanBeRetriedAndAnExpiredSessionAsksForSignIn() {
        interactor.catalogueResult = .error(LearnerAPIError.offline)
        presenter.viewDidLoad()
        guard case .failed(_, let canRetry) = view.last.screen else { return XCTFail("expected failure") }
        XCTAssertTrue(canRetry)
        interactor.catalogueResult = .error(LearnerAPIError.signInRequired)
        presenter.retry()
        XCTAssertEqual(view.last.screen, .signInRequired)
        interactor.catalogueResult = .just(catalogue)
        presenter.retry()
        XCTAssertEqual(view.last.screen, .content)
    }

    func test_anEmptyCatalogueIsSaidSoInsteadOfShowingABlankList() {
        interactor.catalogueResult = .just([])
        presenter.viewDidLoad()
        XCTAssertEqual(view.last.screen, .empty)
    }

    func test_searchMatchesEitherLanguageIgnoringCaseAndAccents() {
        load()
        presenter.search("cat toc")
        XCTAssertEqual(view.last.sections.flatMap(\.rows).map(\.id), ["2"])
        presenter.search("ネイル")
        XCTAssertEqual(view.last.sections.flatMap(\.rows).map(\.id), ["3"])
        presenter.search("BỆNH VIỆN")
        XCTAssertEqual(view.last.sections.flatMap(\.rows).map(\.id), ["1"])
        presenter.search("Hair and beauty")
        XCTAssertEqual(view.last.sections.flatMap(\.rows).map(\.id), ["2", "3"], "the group name is searchable too")
    }

    func test_aSearchWithoutMatchesKeepsTheChipsAndSaysNothingMatched() {
        load()
        presenter.search("zzz")
        XCTAssertEqual(view.last.screen, .noMatches(query: "zzz"))
        XCTAssertEqual(view.last.chips.count, 3)
        presenter.search("")
        XCTAssertEqual(view.last.screen, .content)
    }

    func test_aChipNarrowsToItsGroupAndTheSameChipAgainShowsEverything() {
        load()
        presenter.toggleCategory("beauty")
        XCTAssertEqual(view.last.sections.map(\.key), ["beauty"])
        XCTAssertTrue(view.last.chips.first { $0.key == "beauty" }?.isSelected == true)
        presenter.toggleCategory("beauty")
        XCTAssertEqual(view.last.sections.count, 3)
    }

    func test_nextSituationFollowsTheOrderTheLearnerSees() {
        load()
        presenter.toggleCategory("beauty")
        presenter.select(id: "2")
        XCTAssertEqual(wireframe.opened.first?.summary.id, "2")
        XCTAssertEqual(wireframe.opened.first?.ordered, ["2", "3"], "a group the learner filtered out is not 'next'")
        presenter.toggleCategory("beauty")
        presenter.select(id: "4")
        XCTAssertEqual(wireframe.opened.last?.ordered, ["4", "1", "2", "3"])
    }

    func test_comingBackFromASituationDoesNotReloadTheCatalogue() {
        load()
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.catalogueCalls, 1)
    }
}

// MARK: Play

final class ScenarioPlayPresenterTests: XCTestCase {
    private var interactor: FakeScenarioInteractor!
    private var wireframe: FakeScenarioPlayWireframe!
    private var view: SpyScenarioPlayView!
    private var speech: SpyScenarioSpeech!
    private var language: AppLanguage = .vietnamese
    private let next = summary("N", "beauty", vi: "Tiếp")

    private func makePresenter(next: ScenarioSummary? = nil, steps: Int = 2) -> ScenarioPlayPresenter {
        interactor = FakeScenarioInteractor()
        interactor.lessonResult = .just(lesson(steps: steps))
        wireframe = FakeScenarioPlayWireframe()
        view = SpyScenarioPlayView()
        speech = SpyScenarioSpeech()
        let presenter = ScenarioPlayPresenter(summary: summary("L1", "beauty", vi: "Cắt tóc", ja: "髪を切る"), next: next, interactor: interactor,
                                              wireframe: wireframe, speech: speech, language: { [unowned self] in language })
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    func test_theFirstStepShowsTheSituationAndEveryPhraseUnmarked() {
        _ = makePresenter()
        XCTAssertEqual(view.last.screen, .step)
        XCTAssertEqual(view.last.situation, "Tình huống 1")
        XCTAssertEqual(view.last.situationGloss, "場面1")
        XCTAssertEqual(view.last.choices.map(\.title), ["A1です", "B1です"])
        XCTAssertTrue(view.last.choices.allSatisfy { $0.mark == .none && $0.isEnabled })
        XCTAssertNil(view.last.feedback)
        XCTAssertEqual(view.last.progress, 0)
    }

    func test_aLoadFailureOffersRetryExceptWhenNothingWouldChange() {
        let presenter = makePresenter()
        interactor.lessonResult = .error(LearnerAPIError.offline)
        presenter.retryLoad()
        guard case .failed(_, let retry) = view.last.screen else { return XCTFail("expected failure") }
        XCTAssertTrue(retry)
        interactor.lessonResult = .error(LearnerAPIError.notFound)
        presenter.retryLoad()
        guard case .failed(_, let notFoundRetry) = view.last.screen else { return XCTFail("expected failure") }
        XCTAssertFalse(notFoundRetry)
    }

    func test_chosingTheNaturalPhraseMarksItAndOffersContinue() {
        let presenter = makePresenter()
        presenter.choose(key: "A")
        XCTAssertEqual(interactor.checked.map(\.key), ["A"])
        XCTAssertEqual(interactor.checked.first?.stepID, "S1")
        XCTAssertEqual(view.last.choices.map(\.mark), [.natural, .none])
        XCTAssertTrue(view.last.choices.allSatisfy { !$0.isEnabled }, "one check per step")
        XCTAssertEqual(view.last.feedback?.isNatural, true)
        XCTAssertEqual(view.last.feedback?.spokenText, "A1です")
        XCTAssertFalse(view.last.canChooseAgain)
        XCTAssertEqual(view.last.continueTitle, NSLocalizedString("Continue", comment: ""))
    }

    func test_aPhraseThatFitsLessOffersToChooseAgainAndTheNewChoiceReplacesIt() {
        let presenter = makePresenter(steps: 1)
        interactor.answers = [.just(ScenarioAnswer(choiceKey: "B", isNatural: false)), .just(ScenarioAnswer(choiceKey: "A", isNatural: true))]
        presenter.choose(key: "B")
        XCTAssertEqual(view.last.choices.map(\.mark), [.none, .other])
        XCTAssertTrue(view.last.canChooseAgain)
        presenter.chooseAgain()
        XCTAssertNil(view.last.feedback)
        XCTAssertTrue(view.last.choices.allSatisfy(\.isEnabled))
        presenter.choose(key: "A")
        presenter.advance()
        XCTAssertEqual(interactor.completions.first?.choices, ["1A"], "only the final choice of a step is recorded")
    }

    func test_theServersVietnameseNoteIsShownToVietnameseReadersOnly() {
        language = .vietnamese
        var presenter = makePresenter(steps: 1)
        interactor.answers = [.just(ScenarioAnswer(choiceKey: "A", isNatural: true, noteVietnamese: "Phù hợp."))]
        presenter.choose(key: "A")
        XCTAssertEqual(view.last.feedback?.detail, "Phù hợp.")
        language = .english
        presenter = makePresenter(steps: 1)
        interactor.answers = [.just(ScenarioAnswer(choiceKey: "A", isNatural: true, noteVietnamese: "Phù hợp."))]
        presenter.choose(key: "A")
        XCTAssertNil(view.last.feedback?.detail)
    }

    func test_aFailedCheckStoresNothingAndTheLearnerCanTapAgain() {
        let presenter = makePresenter()
        interactor.answers = [.error(LearnerAPIError.offline)]
        presenter.choose(key: "A")
        XCTAssertNotNil(view.last.error)
        XCTAssertNil(view.last.feedback)
        XCTAssertTrue(view.last.choices.allSatisfy(\.isEnabled))
        presenter.choose(key: "A")
        XCTAssertNil(view.last.error)
        XCTAssertEqual(view.last.feedback?.isNatural, true)
        XCTAssertEqual(interactor.checked.count, 2)
    }

    func test_advancingNeedsAnAnswerAndMovesThroughTheSteps() {
        let presenter = makePresenter()
        presenter.advance()
        XCTAssertEqual(view.last.situation, "Tình huống 1", "no answer, no next step")
        presenter.choose(key: "A")
        presenter.advance()
        XCTAssertEqual(view.last.situation, "Tình huống 2")
        XCTAssertEqual(view.last.progress, 0.5)
        XCTAssertEqual(view.last.choices.map(\.title), ["A2です", "B2です"])
        XCTAssertEqual(interactor.completions.count, 0, "nothing is recorded before the last step")
        presenter.choose(key: "B")
        XCTAssertEqual(view.last.continueTitle, NSLocalizedString("See result", comment: ""))
    }

    func test_theSummaryCountsFinalChoicesAndRecordsTheRunExactlyOnce() {
        let presenter = makePresenter(next: next)
        interactor.answers = [.just(ScenarioAnswer(choiceKey: "A", isNatural: true)), .just(ScenarioAnswer(choiceKey: "B", isNatural: false))]
        presenter.choose(key: "A")
        presenter.advance()
        presenter.choose(key: "B")
        presenter.advance()
        XCTAssertEqual(view.last.screen, .summary)
        XCTAssertEqual(view.last.summary?.rows.map(\.isNatural), [true, false])
        XCTAssertEqual(view.last.summary?.headline, String(format: NSLocalizedString("%1$lld of %2$lld natural phrases", comment: ""), 1, 2))
        XCTAssertEqual(view.last.summary?.save, .saved)
        XCTAssertEqual(view.last.summary?.nextTitle, "Tiếp")
        XCTAssertEqual(interactor.completions.count, 1)
        XCTAssertEqual(interactor.completions.first?.lessonID, "L1")
        XCTAssertEqual(interactor.completions.first?.choices, ["1A", "2B"])
        presenter.advance()
        presenter.retrySave()
        XCTAssertEqual(interactor.completions.count, 1, "a saved run is never sent again")
    }

    func test_aFailedRecordingIsRetriedOnlyWhenTheLearnerAsks() {
        let presenter = makePresenter(steps: 1)
        interactor.completeResults = [.error(LearnerAPIError.offline), .just(())]
        presenter.choose(key: "A")
        presenter.advance()
        guard case .failed = view.last.summary?.save else { return XCTFail("expected a failed save") }
        XCTAssertEqual(interactor.completions.count, 1, "no automatic retry")
        presenter.retrySave()
        XCTAssertEqual(interactor.completions.count, 2)
        XCTAssertEqual(view.last.summary?.save, .saved)
    }

    func test_anInterruptedRecordingSaysItMayHaveBeenSaved() {
        let presenter = makePresenter(steps: 1)
        interactor.completeResults = [.error(LearnerAPIError.interrupted)]
        presenter.choose(key: "A")
        presenter.advance()
        guard case .failed(let message)? = view.last.summary?.save else { return XCTFail("expected a failed save") }
        XCTAssertTrue(message.contains(NSLocalizedString("It may or may not have been saved.", comment: "")))
    }

    func test_practisingAgainStartsOverAndRecordsItsOwnAttempt() {
        let presenter = makePresenter(steps: 1)
        presenter.choose(key: "A")
        presenter.advance()
        presenter.replay()
        XCTAssertEqual(view.last.screen, .step)
        XCTAssertNil(view.last.summary)
        XCTAssertTrue(view.last.choices.allSatisfy { $0.mark == .none && $0.isEnabled })
        presenter.choose(key: "B")
        presenter.advance()
        XCTAssertEqual(interactor.completions.map(\.choices), [["1A"], ["1B"]])
    }

    func test_listeningSpeaksJapaneseAndLeavingStopsTheVoice() {
        let presenter = makePresenter()
        presenter.speak("A1です")
        XCTAssertEqual(speech.spoken.first?.0, "A1です")
        XCTAssertEqual(speech.spoken.first?.1, "ja-JP")
        presenter.viewWillDisappear()
        XCTAssertEqual(speech.stops, 1)
    }

    func test_nextAndCloseGoThroughTheWireframe() {
        let presenter = makePresenter(next: next)
        presenter.openNext()
        XCTAssertEqual(wireframe.next.first?.id, "N")
        presenter.close()
        XCTAssertEqual(wireframe.leaves, 1)
    }

    func test_withoutANextSituationOpeningNextDoesNothing() {
        let presenter = makePresenter()
        presenter.openNext()
        XCTAssertTrue(wireframe.next.isEmpty)
    }
}
