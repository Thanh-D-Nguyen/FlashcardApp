import XCTest
@testable import FlashcardApp

final class DictionaryQueryTests: XCTestCase {
    func testWhitespaceIsTrimmedAndCollapsed() {
        XCTAssertEqual(DictionaryQuery.validate("  ăn   cơm \n"), .valid(DictionaryQuery(text: "ăn cơm")))
    }

    func testEmptyAndSingleLatinLetterAreNotQueries() {
        XCTAssertEqual(DictionaryQuery.validate("   "), .empty)
        XCTAssertEqual(DictionaryQuery.validate(""), .empty)
        XCTAssertEqual(DictionaryQuery.validate("a"), .tooShort)
    }

    func testOneJapaneseCharacterIsEnoughBecauseTheServerCountsBytes() {
        XCTAssertEqual(DictionaryQuery.validate("食"), .valid(DictionaryQuery(text: "食")))
        XCTAssertEqual(DictionaryQuery.validate("あ"), .valid(DictionaryQuery(text: "あ")))
    }

    func testTheServerLimitOf200BytesIsEnforcedOnBytesNotCharacters() {
        XCTAssertEqual(DictionaryQuery.validate(String(repeating: "日", count: 66)), .valid(DictionaryQuery(text: String(repeating: "日", count: 66))))
        XCTAssertEqual(DictionaryQuery.validate(String(repeating: "日", count: 67)), .tooLong)
        XCTAssertEqual(DictionaryQuery.validate(String(repeating: "a", count: 201)), .tooLong)
    }

    func testFullWidthLatinAndHalfWidthKatakanaAreNormalised() {
        XCTAssertEqual(DictionaryQuery.validate("ｔａｂｅｒｕ"), .valid(DictionaryQuery(text: "taberu")))
        XCTAssertEqual(DictionaryQuery.validate("ﾀﾍﾞﾙ"), .valid(DictionaryQuery(text: "タベル")))
    }

    func testDecomposedVietnameseIsComposed() {
        let decomposed = "a\u{0306}n"   // a + combining breve
        XCTAssertEqual(DictionaryQuery.validate(decomposed), .valid(DictionaryQuery(text: "ăn")))
    }

    func testRomajiBecomesKanaOnlyWhenEverythingConverts() {
        XCTAssertEqual(RomajiConverter.hiragana(from: "taberu"), "たべる")
        XCTAssertEqual(RomajiConverter.hiragana(from: "Nihongo"), "にほんご")
        XCTAssertEqual(RomajiConverter.hiragana(from: "shimbun"), nil, "mb is not Hepburn-valid here; leftover letters mean no conversion")
        XCTAssertEqual(RomajiConverter.hiragana(from: "kitte"), "きって")
        XCTAssertEqual(RomajiConverter.hiragana(from: "gakkou"), "がっこう")
        XCTAssertEqual(RomajiConverter.hiragana(from: "kyou"), "きょう")
        XCTAssertEqual(RomajiConverter.hiragana(from: "shashin"), "しゃしん")
        XCTAssertEqual(RomajiConverter.hiragana(from: "konnichiha"), "こんにちは")
        XCTAssertEqual(RomajiConverter.hiragana(from: "kin'en"), "きんえん")
        XCTAssertEqual(RomajiConverter.hiragana(from: "ra-men"), "らーめん")
        XCTAssertEqual(RomajiConverter.hiragana(from: "tenpura"), "てんぷら")
        XCTAssertEqual(RomajiConverter.hiragana(from: "ja"), "じゃ")
    }

    func testTextThatIsNotRomajiIsNotConverted() {
        XCTAssertNil(RomajiConverter.hiragana(from: "ăn"))
        XCTAssertNil(RomajiConverter.hiragana(from: "ăn com"), "A Vietnamese phrase must not be read as romaji")
        XCTAssertNil(RomajiConverter.hiragana(from: "com"))
        XCTAssertNil(RomajiConverter.hiragana(from: "食べる"))
        XCTAssertNil(RomajiConverter.hiragana(from: ""))
        XCTAssertNil(RomajiConverter.hiragana(from: "q"))
    }

    func testAKanaCandidateIsOfferedForRomajiQueriesOnly() {
        XCTAssertEqual(DictionaryQuery(text: "taberu").kanaCandidate, "たべる")
        XCTAssertNil(DictionaryQuery(text: "食べる").kanaCandidate)
        XCTAssertNil(DictionaryQuery(text: "ăn cơm").kanaCandidate)
    }
}

extension DictionaryQueryTests {
    func testTchIsASokuonLikeMatcha() {
        XCTAssertEqual(RomajiConverter.hiragana(from: "matcha"), "まっちゃ")
    }
}
