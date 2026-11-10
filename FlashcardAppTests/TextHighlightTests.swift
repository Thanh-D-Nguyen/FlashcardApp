import XCTest
@testable import FlashcardApp

final class TextHighlightTests: XCTestCase {
    func testJapaneseTermsAreMarkedWhereTheyOccur() {
        let text = "食べることは食べるが、あまり美味しくない。"
        let ranges = TextHighlight.ranges(of: ["食べる"], in: text)
        XCTAssertEqual(ranges.map { (text as NSString).substring(with: $0) }, ["食べる", "食べる"])
    }

    func testVietnameseMatchesIgnoreToneMarksAndCase() {
        let text = "Hãy cẩn thận về những gì bạn ĂN."
        let ranges = TextHighlight.ranges(of: ["an"], in: text)
        XCTAssertTrue(ranges.map { (text as NSString).substring(with: $0).lowercased() }.contains("ăn"))
    }

    func testAStemAndItsWordAreMergedNotDoublePainted() {
        let text = "ご飯を食べる。"
        let ranges = TextHighlight.ranges(of: ["食べる", "食べ"], in: text)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "食べる")
    }

    func testAConjugatedFormIsFoundThroughTheStem() {
        let text = "ご飯を食べます。"
        XCTAssertTrue(TextHighlight.ranges(of: ["食べる"], in: text).isEmpty)
        let terms = TextHighlight.terms(forHeadword: "食べる")
        XCTAssertEqual(terms, ["食べる", "食べ"])
        XCTAssertEqual(TextHighlight.ranges(of: terms, in: text).map { (text as NSString).substring(with: $0) }, ["食べ"])
    }

    func testShortHeadwordsAndKanjiEndingsHaveNoStem() {
        XCTAssertEqual(TextHighlight.terms(forHeadword: "行く"), ["行く"], "Stem would be a single character that matches far too much")
        XCTAssertEqual(TextHighlight.terms(forHeadword: "勉強"), ["勉強"])
    }

    func testEmptyTermsAndTextDoNothing() {
        XCTAssertTrue(TextHighlight.ranges(of: [""], in: "abc").isEmpty)
        XCTAssertTrue(TextHighlight.ranges(of: ["a"], in: "").isEmpty)
    }
}
