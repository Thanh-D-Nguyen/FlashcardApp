import RxSwift
import XCTest
@testable import FlashcardApp

/// Which word a card is looked up by, which sentences count as examples of it, and how answers are kept.
final class CardExampleTests: XCTestCase {
    private func dto(_ sentence: String, reading: String? = nil, meaning: String? = "Tôi thích chó.", kind: String = "example",
                     id: String = UUID().uuidString) -> BJTSearchResultDTO {
        BJTSearchResultDTO(id: id, kind: kind, title: sentence, description: meaning, reading: reading, jlptLevel: nil)
    }

    // MARK: The word of a card

    func test_theJapaneseSideIsTheWordWhicheverSideItIsOn() {
        XCTAssertEqual(CardExampleLookup.term(front: "犬", back: "chó", deckHasJapaneseOnFront: true), "犬")
        XCTAssertEqual(CardExampleLookup.term(front: "chó", back: "犬", deckHasJapaneseOnFront: true), "犬")
        XCTAssertEqual(CardExampleLookup.term(front: " 犬 \n", back: "chó", deckHasJapaneseOnFront: true), "犬", "Whitespace is trimmed")
    }

    func test_aCardWithoutJapaneseOrWithASentenceForAWordHasNoTerm() {
        XCTAssertNil(CardExampleLookup.term(front: "dog", back: "chó", deckHasJapaneseOnFront: true))
        XCTAssertNil(CardExampleLookup.term(front: String(repeating: "犬", count: CardExampleLookup.maximumTermLength + 1), back: "chó", deckHasJapaneseOnFront: true))
        XCTAssertNotNil(CardExampleLookup.term(front: String(repeating: "犬", count: CardExampleLookup.maximumTermLength), back: "chó", deckHasJapaneseOnFront: true))
    }

    // MARK: Which sentences are examples

    func test_onlySentencesThatUseTheWordAreKept() {
        let results = [dto("犬は水の中をのぞいた。", reading: "いぬはみずのなかをのぞいた。"), dto("猫が好きです。"), dto("犬", kind: "lexeme")]
        let examples = CardExampleLookup.examples(from: results, term: "犬", cardReading: "")
        XCTAssertEqual(examples.map(\.japanese), ["犬は水の中をのぞいた。"])
        XCTAssertEqual(examples.first?.reading, "いぬはみずのなかをのぞいた。")
        XCTAssertEqual(examples.first?.translation, "Tôi thích chó.")
    }

    func test_aSentenceWrittenInKanaMatchesTheCardsReading() {
        let results = [dto("いぬがすきです。", reading: "いぬがすきです。"), dto("ねこがすきです。", reading: "ねこがすきです。")]
        let examples = CardExampleLookup.examples(from: results, term: "犬", cardReading: "いぬ")
        XCTAssertEqual(examples.map(\.japanese), ["いぬがすきです。"])
        XCTAssertEqual(examples.first?.reading, "", "A reading identical to the sentence is not repeated")
    }

    func test_sentencesComeBeforePhrasesThenShorterFirstAndDuplicatesCollapse() {
        let results = [dto("犬の口"), dto("私は犬を飼っています。"), dto("犬が好き。"), dto("犬が好き。"), dto("犬は病気みたい。")]
        let examples = CardExampleLookup.examples(from: results, term: "犬", cardReading: "")
        XCTAssertEqual(examples.map(\.japanese), ["犬が好き。", "犬は病気みたい。", "私は犬を飼っています。", "犬の口"])
    }

    func test_atMostFiveSentencesAreOffered() {
        let results = (1...12).map { dto("犬が\($0)匹います。") }
        XCTAssertEqual(CardExampleLookup.examples(from: results, term: "犬", cardReading: "").count, CardExampleLookup.maximumExamples)
    }

    func test_aMissingTranslationIsLeftEmptyAndCopyingSkipsEmptyParts() {
        let example = CardExampleLookup.examples(from: [dto("犬がいる。", meaning: nil)], term: "犬", cardReading: "").first
        XCTAssertEqual(example?.translation, "")
        XCTAssertEqual(example?.copyText, "犬がいる。")
        XCTAssertEqual(CardExample(id: "1", japanese: "犬がいる。", reading: "いぬがいる。", translation: "Có chó.").copyText, "犬がいる。\nいぬがいる。\nCó chó.")
    }

    // MARK: The interactor

    func test_anAnswerIsKeptSoARevisitedCardDoesNotAskTheServerAgain() {
        let search = StubSentences()
        search.result = .just([dto("犬が好き。")])
        let interactor = CardExamplesInteractor(search: search)
        XCTAssertEqual(try wait(interactor.examples(for: "犬", cardReading: "")).map(\.japanese), ["犬が好き。"])
        XCTAssertEqual(try wait(interactor.examples(for: "犬", cardReading: "")).map(\.japanese), ["犬が好き。"])
        XCTAssertEqual(search.requests.count, 1)
        XCTAssertEqual(search.requests.first?.limit, CardExampleLookup.candidateLimit)
    }

    func test_aFailureIsNotRememberedSoTryingAgainAsksAgain() {
        let search = StubSentences()
        search.result = .error(LearnerAPIError.offline)
        let interactor = CardExamplesInteractor(search: search)
        XCTAssertThrowsError(try wait(interactor.examples(for: "犬", cardReading: "")))
        search.result = .just([dto("犬が好き。")])
        XCTAssertEqual(try wait(interactor.examples(for: "犬", cardReading: "")).count, 1)
        XCTAssertEqual(search.requests.count, 2)
    }

    func test_aWordWithNoSentencesIsRememberedAsEmpty() {
        let search = StubSentences()
        search.result = .just([])
        let interactor = CardExamplesInteractor(search: search)
        XCTAssertEqual(try wait(interactor.examples(for: "会議", cardReading: "かいぎ")), [])
        XCTAssertEqual(try wait(interactor.examples(for: "会議", cardReading: "かいぎ")), [])
        XCTAssertEqual(search.requests.count, 1)
    }

    func test_theCacheIsBoundedAndForgetsTheOldestWord() {
        let search = StubSentences()
        search.result = .just([])
        let interactor = CardExamplesInteractor(search: search)
        for index in 0...CardExamplesInteractor.cacheCapacity { _ = try? wait(interactor.examples(for: "語\(index)", cardReading: "")) }
        let before = search.requests.count
        _ = try? wait(interactor.examples(for: "語0", cardReading: ""))
        XCTAssertEqual(search.requests.count, before + 1, "The first word was evicted")
        _ = try? wait(interactor.examples(for: "語\(CardExamplesInteractor.cacheCapacity)", cardReading: ""))
        XCTAssertEqual(search.requests.count, before + 1, "The newest word is still cached")
    }

    func test_disposingCancelsTheServerRequest() {
        let search = StubSentences()
        let subject = PublishSubject<[BJTSearchResultDTO]>()
        var cancelled = false
        search.result = subject.asSingle().do(onDispose: { cancelled = true })
        CardExamplesInteractor(search: search).examples(for: "犬", cardReading: "").subscribe().dispose()
        XCTAssertTrue(cancelled)
    }

    /// The interactor delivers on the main queue: pump it until the single answers.
    private func wait(_ single: Single<[CardExample]>) throws -> [CardExample] {
        var outcome: Result<[CardExample], Error>?
        let bag = DisposeBag()
        single.subscribe(onSuccess: { outcome = .success($0) }, onFailure: { outcome = .failure($0) }).disposed(by: bag)
        let deadline = Date().addingTimeInterval(2)
        while outcome == nil, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        return try XCTUnwrap(outcome).get()
    }
}

private final class StubSentences: SentenceSearchInterface {
    var result: Single<[BJTSearchResultDTO]> = .just([])
    var requests: [(text: String, limit: Int)] = []
    func sentences(containing text: String, limit: Int) -> Single<[BJTSearchResultDTO]> {
        requests.append((text, limit))
        return result
    }
}
