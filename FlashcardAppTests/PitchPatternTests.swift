import XCTest
@testable import FlashcardApp

final class PitchPatternTests: XCTestCase {
    func testNakadakaDropsAfterTheSecondMora() throws {
        let pattern = try XCTUnwrap(PitchPattern(accent: "LHL-L", morae: ["た", "べ", "る"]))
        XCTAssertEqual(pattern.levels, [.low, .high, .low])
        XCTAssertEqual(pattern.particle, .low)
        XCTAssertEqual(pattern.number, 2)
        XCTAssertEqual(pattern.kind, .nakadaka)
    }

    func testHeibanNeverDrops() throws {
        let pattern = try XCTUnwrap(PitchPattern(accent: "LH-H", morae: ["い", "く"]))
        XCTAssertEqual(pattern.number, 0)
        XCTAssertEqual(pattern.kind, .heiban)
    }

    func testAtamadakaDropsAfterTheFirstMora() throws {
        let pattern = try XCTUnwrap(PitchPattern(accent: "HLL-L", morae: ["か", "い", "ぎ"]))
        XCTAssertEqual(pattern.number, 1)
        XCTAssertEqual(pattern.kind, .atamadaka)
    }

    func testOdakaDropsOnlyOnTheParticle() throws {
        let pattern = try XCTUnwrap(PitchPattern(accent: "LH-L", morae: ["は", "な"]))
        XCTAssertEqual(pattern.number, 2)
        XCTAssertEqual(pattern.kind, .odaka)
    }

    func testTheGroupWhoseLengthMatchesTheMoraCountIsUsed() throws {
        // Same rule as the website: take the first H/L group with one letter per mora.
        let pattern = try XCTUnwrap(PitchPattern(accent: "LHH-LH", morae: ["ひ", "と", "つ"]))
        XCTAssertEqual(pattern.levels.count, 3)
    }

    func testDataThatDoesNotFitIsNoPitchRatherThanAWrongOne() {
        XCTAssertNil(PitchPattern(accent: "LHL-L", morae: ["た", "べ"]))
        XCTAssertNil(PitchPattern(accent: nil, morae: ["た"]))
        XCTAssertNil(PitchPattern(accent: "LHL-L", morae: []))
        XCTAssertNil(PitchPattern(accent: "X-Y", morae: ["た"]))
    }

    func testMoraeAreDerivedFromKanaWhenTheServerSendsNone() {
        XCTAssertEqual(PitchPattern.morae(ofKana: "べんきょう"), ["べ", "ん", "きょ", "う"])
        XCTAssertEqual(PitchPattern.morae(ofKana: "がっこう"), ["が", "っ", "こ", "う"])
        XCTAssertEqual(PitchPattern.morae(ofKana: "ラーメン"), ["ラ", "ー", "メ", "ン"])
    }

    func testPronunciationEntriesPickTheFirstDrawableOne() {
        let entries: [BJTLexemeDetailDTO.Pronunciation] = [
            .init(kana: "x", accent: "bad", morae: ["x"]),
            .init(kana: "いく", accent: "LH-H", morae: ["い", "く"]),
            .init(kana: "ゆく", accent: "LH-H", morae: ["ゆ", "く"])
        ]
        XCTAssertEqual(PitchPattern.patterns(from: entries).map(\.text), ["いく", "ゆく"])
    }
}
