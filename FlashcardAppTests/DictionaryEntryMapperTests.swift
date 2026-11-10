import XCTest
@testable import FlashcardApp

final class DictionaryEntryMapperTests: XCTestCase {
    func testVocabularyWithoutSensesUsesTheShortMeaningAsTheOnlyGloss() {
        let dto = BJTLexemeDetailDTO(id: "w1", headword: "食べる", reading: " たべる ", kanjiMeaningVi: "THỰC", jlptLevel: "N5", shortMeaningVi: "ăn",
                                     pronunciation: [.init(kana: "たべる", accent: "LHL-L", morae: ["た", "べ", "る"])])
        let detail = DictionaryEntryMapper.vocabulary(dto)
        XCTAssertEqual(detail.meanings, [.init(text: "ăn", partOfSpeech: nil, note: nil)])
        XCTAssertEqual(detail.reading, "たべる")
        XCTAssertEqual(detail.hanViet, "THỰC")
        XCTAssertEqual(detail.pitch.first?.number, 2)
        XCTAssertEqual(detail.item, DictionaryItem(kind: .vocabulary, id: "w1", title: "食べる", reading: "たべる", meaning: "ăn", level: "N5"))
    }

    func testVocabularySensesKeepTheirOrderPartOfSpeechAndNotes() {
        let dto = BJTLexemeDetailDTO(id: "w2", headword: "猫", shortMeaningVi: "mèo", senses: [
            .init(glossVi: "mèo", posTag: "n", note: nil), .init(glossVi: "  ", posTag: nil, note: nil), .init(glossVi: "người đánh đàn", posTag: "n", note: "tiếng lóng")
        ])
        XCTAssertEqual(DictionaryEntryMapper.vocabulary(dto).meanings.map(\.text), ["mèo", "người đánh đàn"])
        XCTAssertEqual(DictionaryEntryMapper.vocabulary(dto).meanings.last?.note, "tiếng lóng")
    }

    func testVocabularyWithNoMeaningAtAllHasNoMeaningsRatherThanAPlaceholder() {
        let detail = DictionaryEntryMapper.vocabulary(BJTLexemeDetailDTO(id: "w3", headword: "謎"))
        XCTAssertTrue(detail.meanings.isEmpty)
        XCTAssertNil(detail.reading)
        XCTAssertNil(detail.item.meaning)
    }

    func testKanjiMapsLevelReadingsExplanationAndMnemonic() {
        let dto = BJTKanjiDetailDTO(id: "k1", character: "食", meaningVi: "THỰC, TỰ", onyomi: "ショク ジキ", kunyomi: "く.う く.らう た.べる は.む",
                                    strokeCount: 9, level: 5, frequency: 328, detail: "Đồ để ăn.##Ăn. Như [食飯].## ", tip: "Cái làm tôi thấy tốt(良) ở nhà là <b>ăn</b>",
                                    strokeSvgHash: "abc", examples: [.init(id: "e", word: "食う", reading: "くう", meaningVi: "ăn", hanViet: nil)],
                                    components: [.init(id: "c2", character: "𠆢", hanViet: nil, position: 1), .init(id: "c1", character: "良", hanViet: "LƯƠNG", position: 0)])
        let detail = DictionaryEntryMapper.kanji(dto)
        XCTAssertEqual(detail.level, "N5")
        XCTAssertEqual(detail.onyomi, ["ショク", "ジキ"])
        XCTAssertEqual(detail.kunyomi, ["く.う", "く.らう", "た.べる", "は.む"])
        XCTAssertEqual(detail.explanation, ["Đồ để ăn.", "Ăn. Như [食飯]."])
        XCTAssertEqual(detail.mnemonic, [.init(text: "Cái làm tôi thấy tốt(良) ở nhà là ", isEmphasised: false), .init(text: "ăn", isEmphasised: true)])
        XCTAssertEqual(detail.components.map(\.character), ["良", "𠆢"], "Components are ordered by position")
        XCTAssertEqual(detail.strokeHash, "abc")
        XCTAssertEqual(detail.frequency, 328)
    }

    func testKanjiWithOutOfRangeNumbersShowsNoLevelOrCount() {
        let detail = DictionaryEntryMapper.kanji(BJTKanjiDetailDTO(id: "k", character: "鬱", strokeCount: 0, level: 9, frequency: 0))
        XCTAssertNil(detail.level)
        XCTAssertNil(detail.strokeCount)
        XCTAssertNil(detail.frequency)
        XCTAssertTrue(detail.onyomi.isEmpty)
        XCTAssertTrue(detail.mnemonic.isEmpty)
    }

    func testMarkupOtherThanBoldIsStrippedNotInterpreted() {
        XCTAssertEqual(TextSegment.parse("a <script>x</script><b>b</b> <i>c</i>").map(\.text), ["a x", "b", " c"])
        XCTAssertEqual(TextSegment.parse("a <script>x</script><b>b</b> <i>c</i>").map(\.isEmphasised), [false, true, false])
        XCTAssertEqual(TextSegment.parse("a < b").map(\.text), ["a < b"], "A bare < is text")
    }

    func testGrammarSectionsAreOrderedAndEmptyOnesDropped() {
        let dto = BJTGrammarDetailDTO(id: "g1", pattern: "ても", meaningVi: "Ai (gì)...cũng...", jlptLevel: "N4", category: "Bất biến", details: [
            .init(position: 1, meaningVi: nil, explanation: nil, note: "Lưu ý", synopsis: nil),
            .init(position: 0, meaningVi: nil, explanation: "Diễn tả.", note: nil, synopsis: "Nghi vấn từ + ても"),
            .init(position: 2, meaningVi: " ", explanation: nil, note: nil, synopsis: nil)
        ])
        let detail = DictionaryEntryMapper.grammar(dto)
        XCTAssertEqual(detail.sections.map(\.formation), ["Nghi vấn từ + ても", nil])
        XCTAssertEqual(detail.sections.count, 2)
        XCTAssertEqual(detail.item.level, "N4")
    }

    func testGrammarExampleTermDropsPlaceholderMarksAndRefusesTooShortPatterns() {
        func term(_ pattern: String) -> String? { GrammarDetail(id: "g", pattern: pattern, meaning: "", level: nil, category: nil, sections: []).exampleTerm }
        XCTAssertEqual(term("ても"), "ても")
        XCTAssertEqual(term("... ても"), "ても")
        XCTAssertEqual(term("〜てから"), "てから")
        XCTAssertEqual(term("ても／でも"), "ても", "Alternatives: the first one")
        XCTAssertNil(term("は"))
        XCTAssertNil(term("N（は）"), "Only one Japanese character remains")
    }

    func testSentenceDropsAReadingThatIsTheSentenceItself() {
        let item = DictionaryItem(kind: .sentence, id: "s", title: "食べるな。", reading: "食べるな。", meaning: "Cấm ăn.")
        XCTAssertNil(DictionaryEntryMapper.sentence(item).reading)
        XCTAssertEqual(DictionaryEntryMapper.sentence(item).translation, "Cấm ăn.")
    }

    func testKanjiReferencesAreListedOnceInOrder() {
        let rows = [BJTKanjiReferenceDTO(id: "a", character: "食", meaningVi: "THỰC"), BJTKanjiReferenceDTO(id: "a", character: "食", meaningVi: "THỰC"),
                    BJTKanjiReferenceDTO(id: "b", character: "事", meaningVi: nil)]
        XCTAssertEqual(DictionaryEntryMapper.kanjiReferences(rows).map(\.character), ["食", "事"])
    }
}
