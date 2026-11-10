import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Contract tests for the public dictionary detail endpoints. The fixtures are trimmed copies of real responses from
/// the Go backend (captured 2026-10-26).
final class BJTDictionaryAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTDictionaryAPI!
    private var bag: DisposeBag!
    private let lexemeID = "9adc769d-2d6f-48a1-a9ca-5fe729033518"
    private let kanjiID = "30997740-7d8c-4216-a987-dc6ea83edc9c"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DictionaryURLProtocol.self]
        session = Session(configuration: config)
        api = BJTDictionaryAPI(session: session, baseURL: "https://api.test/api")
        bag = DisposeBag()
        DictionaryURLProtocol.handler = nil
        DictionaryURLProtocol.onStop = nil
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        api = nil
        session = nil
        DictionaryURLProtocol.handler = nil
        DictionaryURLProtocol.onStop = nil
        super.tearDown()
    }

    // MARK: Decoding

    func testLexemeDecodesPitchAccentAndKeepsOptionalFieldsOptional() throws {
        let dto = try JSONDecoder().decode(BJTLexemeDetailDTO.self, from: Self.lexemeJSON)
        XCTAssertEqual(dto.id, lexemeID)
        XCTAssertEqual(dto.headword, "食べる")
        XCTAssertEqual(dto.reading, "たべる")
        XCTAssertEqual(dto.jlptLevel, "N5")
        XCTAssertEqual(dto.shortMeaningVi, "ăn")
        XCTAssertEqual(dto.kanjiMeaningVi, "THỰC")
        XCTAssertTrue(dto.senses.isEmpty)
        XCTAssertEqual(dto.pronunciation.first?.accent, "LHL-L")
        XCTAssertEqual(dto.pronunciation.first?.morae, ["た", "べ", "る"])
    }

    func testLexemeWithoutOptionalFieldsOrWithOddPronunciationStillDecodes() throws {
        let json = Data(#"{"id":"\#(lexemeID)","headword":"猫","senses":[{"glossVi":"mèo","posTag":"n"}],"pronunciation":{"unexpected":true}}"#.utf8)
        let dto = try JSONDecoder().decode(BJTLexemeDetailDTO.self, from: json)
        XCTAssertNil(dto.reading)
        XCTAssertNil(dto.jlptLevel)
        XCTAssertEqual(dto.senses, [.init(glossVi: "mèo", posTag: "n", note: nil)])
        XCTAssertTrue(dto.pronunciation.isEmpty, "A pronunciation shape the app does not know means no pitch data, not a failed lookup")
    }

    func testKanjiDetailDecodesLevelFrequencyExamplesAndComponents() throws {
        let dto = try JSONDecoder().decode(BJTKanjiDetailDTO.self, from: Self.kanjiJSON)
        XCTAssertEqual(dto.character, "食")
        XCTAssertEqual(dto.strokeCount, 9)
        XCTAssertEqual(dto.level, 5)
        XCTAssertEqual(dto.frequency, 328)
        XCTAssertEqual(dto.onyomi, "ショク ジキ")
        XCTAssertEqual(dto.examples.first?.word, "食う")
        XCTAssertNil(dto.examples.first?.hanViet)
        XCTAssertEqual(dto.components.map(\.character), ["良", "𠆢"])
        XCTAssertNil(dto.components.last?.hanViet)
    }

    func testGrammarDetailDecodesDetailsAndToleratesMissingParts() throws {
        let json = Data(#"{"id":"12a86f71-b86f-4c95-a4f7-942853009cad","pattern":"ても","meaningVi":"Ai (gì)...cũng...","jlptLevel":"N4","category":"Bất biến","details":[{"position":0,"explanation":"Diễn tả.","synopsis":"Nghi vấn từ + ても"}]}"#.utf8)
        let dto = try JSONDecoder().decode(BJTGrammarDetailDTO.self, from: json)
        XCTAssertEqual(dto.pattern, "ても")
        XCTAssertEqual(dto.details.first?.synopsis, "Nghi vấn từ + ても")
        XCTAssertNil(dto.details.first?.note)
        let bare = try JSONDecoder().decode(BJTGrammarDetailDTO.self, from: Data(#"{"id":"x","pattern":"は","meaningVi":"chủ đề"}"#.utf8))
        XCTAssertTrue(bare.details.isEmpty)
    }

    // MARK: Requests

    func testLexemeRequestUsesTheContentPathWithoutCredentials() {
        let done = expectation(description: "lexeme")
        DictionaryURLProtocol.handler = { request, proto in
            XCTAssertEqual(request.url?.path, "/api/content/lexemes/\(self.lexemeID)")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            proto.respond(status: 200, data: Self.lexemeJSON)
        }
        api.lexeme(id: lexemeID).subscribe(onSuccess: {
            XCTAssertEqual($0.headword, "食べる")
            done.fulfill()
        }, onFailure: { XCTFail("\($0)"); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testAnIdThatIsNotAUUIDNeverReachesTheNetwork() {
        DictionaryURLProtocol.handler = { _, _ in XCTFail("a path segment must be a UUID") }
        for id in ["", "../admin", "123", "9adc769d/../x"] {
            let done = expectation(description: "invalid id \(id)")
            api.lexeme(id: id).subscribe(onSuccess: { _ in XCTFail(); done.fulfill() },
                                         onFailure: { error in
                                             XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
                                             done.fulfill()
                                         }).disposed(by: bag)
            wait(for: [done], timeout: 1)
        }
    }

    func testStatusesMapToErrorsTheScreenCanExplain() {
        let cases: [(Int, LearnerAPIError)] = [(404, .notFound), (429, .rateLimited), (500, .server(500)), (503, .serviceUnavailable(nil))]
        for (status, expected) in cases {
            let done = expectation(description: "status \(status)")
            DictionaryURLProtocol.handler = { _, proto in proto.respond(status: status, data: Data(#"{"error":"x"}"#.utf8)) }
            api.grammar(id: lexemeID).subscribe(onSuccess: { _ in XCTFail(); done.fulfill() }, onFailure: { error in
                // `serviceUnavailable` carries the server text; compare the case only.
                switch (error as? LearnerAPIError, expected) {
                case (.serviceUnavailable?, .serviceUnavailable): break
                default: XCTAssertEqual(error as? LearnerAPIError, expected)
                }
                done.fulfill()
            }).disposed(by: bag)
            wait(for: [done], timeout: 3)
        }
    }

    func testAnUnexpectedBodyIsAnInvalidResponseNotAHalfFilledEntry() {
        let done = expectation(description: "malformed")
        DictionaryURLProtocol.handler = { _, proto in proto.respond(status: 200, data: Data(#"{"headword":"食べる"}"#.utf8)) }
        api.lexeme(id: lexemeID).subscribe(onSuccess: { _ in XCTFail(); done.fulfill() }, onFailure: {
            XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse)
            done.fulfill()
        }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testNoConnectionIsReportedAsOffline() {
        let done = expectation(description: "offline")
        DictionaryURLProtocol.handler = { _, proto in proto.fail(URLError(.notConnectedToInternet)) }
        api.kanji(id: kanjiID).subscribe(onSuccess: { _ in XCTFail(); done.fulfill() }, onFailure: {
            XCTAssertEqual($0 as? LearnerAPIError, .offline)
            done.fulfill()
        }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testKanjiLookupByCharacterKeepsOnlyTheExactCharacter() {
        let done = expectation(description: "lookup")
        DictionaryURLProtocol.handler = { request, proto in
            let url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertEqual(url.path, "/api/kanji")
            XCTAssertEqual(url.queryItems?.first { $0.name == "q" }?.value, "良")
            // The backend searches meanings and readings too, so the first row is not necessarily the character itself.
            proto.respond(status: 200, data: Data(#"[{"id":"a","character":"食"},{"id":"b","character":"良","meaningVi":"LƯƠNG","strokeCount":7,"level":3}]"#.utf8))
        }
        api.kanji(character: "良").subscribe(onSuccess: {
            XCTAssertEqual($0?.id, "b")
            done.fulfill()
        }, onFailure: { XCTFail("\($0)"); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testKanjiLookupWithoutAMatchIsNilAndAMultiCharacterTextIsRejected() {
        let none = expectation(description: "none")
        DictionaryURLProtocol.handler = { _, proto in proto.respond(status: 200, data: Data("[]".utf8)) }
        api.kanji(character: "𠆢").subscribe(onSuccess: { XCTAssertNil($0); none.fulfill() },
                                              onFailure: { XCTFail("\($0)"); none.fulfill() }).disposed(by: bag)
        wait(for: [none], timeout: 3)

        // A component that is not a kanji (a radical form, a stroke) has no entry: nil, and no request.
        let radical = expectation(description: "radical")
        DictionaryURLProtocol.handler = { _, _ in XCTFail("a non-kanji component must not reach the network") }
        api.kanji(character: "ノ").subscribe(onSuccess: { XCTAssertNil($0); radical.fulfill() },
                                              onFailure: { XCTFail("\($0)"); radical.fulfill() }).disposed(by: bag)
        wait(for: [radical], timeout: 1)

        let rejected = expectation(description: "rejected")
        DictionaryURLProtocol.handler = { _, _ in XCTFail("only one character may be looked up") }
        api.kanji(character: "食べ").subscribe(onSuccess: { _ in XCTFail(); rejected.fulfill() },
                                                onFailure: { _ in rejected.fulfill() }).disposed(by: bag)
        wait(for: [rejected], timeout: 1)
    }

    func testStrokeRequestAsksForSVGAndReturnsTheText() {
        let done = expectation(description: "stroke")
        DictionaryURLProtocol.handler = { request, proto in
            XCTAssertEqual(request.url?.path, "/api/kanji/\(self.kanjiID)/stroke")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "image/svg+xml")
            proto.respond(status: 200, data: Self.svg, contentType: "image/svg+xml; charset=utf-8")
        }
        api.strokeSVG(kanjiID: kanjiID).subscribe(onSuccess: {
            XCTAssertTrue($0.hasPrefix("<svg"))
            done.fulfill()
        }, onFailure: { XCTFail("\($0)"); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testStrokeResponseThatIsNotASmallSVGIsRejected() {
        let wrongType = expectation(description: "json instead of svg")
        DictionaryURLProtocol.handler = { _, proto in proto.respond(status: 200, data: Self.svg, contentType: "application/json") }
        api.strokeSVG(kanjiID: kanjiID).subscribe(onSuccess: { _ in XCTFail(); wrongType.fulfill() }, onFailure: {
            XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse)
            wrongType.fulfill()
        }).disposed(by: bag)
        wait(for: [wrongType], timeout: 3)

        let tooBig = expectation(description: "oversized")
        DictionaryURLProtocol.handler = { _, proto in
            proto.respond(status: 200, data: Data(repeating: 0x20, count: BJTDictionaryAPI.maximumStrokeBytes + 1), contentType: "image/svg+xml")
        }
        api.strokeSVG(kanjiID: kanjiID).subscribe(onSuccess: { _ in XCTFail(); tooBig.fulfill() }, onFailure: {
            XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse)
            tooBig.fulfill()
        }).disposed(by: bag)
        wait(for: [tooBig], timeout: 3)
    }

    func testDisposingCancelsTheOwnedRequest() {
        let started = expectation(description: "started")
        let stopped = expectation(description: "cancelled")
        DictionaryURLProtocol.handler = { _, _ in started.fulfill() }
        DictionaryURLProtocol.onStop = { stopped.fulfill() }
        let request = api.kanjiWords(kanjiID: kanjiID).subscribe()
        wait(for: [started], timeout: 3)
        request.dispose()
        wait(for: [stopped], timeout: 3)
    }

    // MARK: Fixtures

    private static let lexemeJSON = Data(#"""
    {"id":"9adc769d-2d6f-48a1-a9ca-5fe729033518","headword":"食べる","reading":"たべる","kanjiMeaningVi":"THỰC","jlptLevel":"N5",
     "shortMeaningVi":"ăn","pronunciation":[{"kana":"たべる","accent":"LHL-L","tokenizedKana":[{"type":"mora","value":"た"},{"type":"mora","value":"べ"},{"type":"mora","value":"る"}]}],"senses":[]}
    """#.utf8)

    private static let kanjiJSON = Data(#"""
    {"id":"30997740-7d8c-4216-a987-dc6ea83edc9c","character":"食","meaningVi":"THỰC, TỰ","onyomi":"ショク ジキ","kunyomi":"く.う く.らう た.べる は.む",
     "strokeCount":9,"level":5,"frequency":328,"detail":"Đồ để ăn.##Ăn.","tip":"Cái làm tôi thấy tốt(良) ở nhà là <b>ăn</b>",
     "examples":[{"id":"c5403459-eaf5-4731-a5da-20b953356f29","word":"食う","reading":"くう","meaningVi":"ăn","hanViet":null}],
     "components":[{"id":"23236b23-9853-41bc-a4eb-85b0f9cb8c16","character":"良","hanViet":"LƯƠNG","position":0},{"id":"89638e27-fba5-412e-a8b0-783c110432a0","character":"𠆢","hanViet":null,"position":1}]}
    """#.utf8)

    private static let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="109" height="109" viewBox="0 0 109 109"><path d="M1,1L2,2"/></svg>"#.utf8)
}

private final class DictionaryURLProtocol: URLProtocol {
    static var handler: ((URLRequest, DictionaryURLProtocol) -> Void)?
    static var onStop: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(request, self) }
    override func stopLoading() { Self.onStop?() }

    func respond(status: Int, data: Data, contentType: String = "application/json") {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    func fail(_ error: Error) { client?.urlProtocol(self, didFailWithError: error) }
}
