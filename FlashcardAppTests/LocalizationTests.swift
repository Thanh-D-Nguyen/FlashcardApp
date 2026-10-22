import XCTest
@testable import FlashcardApp

/// Vietnamese, English and Japanese are all required. These tests read the tables Xcode compiled from
/// `Localizable.xcstrings` into the app bundle, so a missing or broken translation fails the build's tests.
final class LocalizationTests: XCTestCase {

    private let appBundle = Bundle(for: HomePresenter.self)
    private let required = ["en", "vi", "ja"]

    private func table(_ language: String) throws -> [String: String] {
        let path = try XCTUnwrap(
            appBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
            "Localizable.strings is missing for \(language)")
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    /// `%@`, `%lld`, `%1$@` … reduced to their conversion, in positional order.
    private func placeholders(_ text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:\\.\\d+)?(@|lld|ld|d|f)")
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    func test_appShipsExactlyVietnameseEnglishAndJapanese() {
        let shipped = Set(appBundle.localizations).subtracting(["Base"])
        XCTAssertEqual(shipped, Set(required))
    }

    func test_everyLanguageHasTheSameKeys() throws {
        let tables = try required.map { ($0, try table($0)) }
        let reference = Set(tables[0].1.keys)
        XCTAssertGreaterThan(reference.count, 80, "The catalog looks empty")
        for (language, strings) in tables {
            XCTAssertEqual(Set(strings.keys), reference, "\(language) has different keys than \(tables[0].0)")
        }
    }

    func test_translationsAreFilledInAndKeepTheirPlaceholders() throws {
        let english = try table("en")
        // Brand names, addresses and loanwords that legitimately read the same in the other languages.
        let sameAsKey: Set<String> = ["email@domain.com", "OK", "Kanji"]
        for language in ["vi", "ja"] {
            let strings = try table(language)
            for (key, value) in strings {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language): empty value for \(key)")
                if !sameAsKey.contains(key), key == english[key] {
                    XCTAssertNotEqual(value, key, "\(language): \(key) is still untranslated")
                }
                XCTAssertEqual(placeholders(value), placeholders(english[key] ?? key),
                               "\(language): placeholders of \(key) differ from English")
            }
        }
    }

    func test_japaneseCopyIsActuallyJapaneseAndVietnameseKeepsItsDiacritics() throws {
        let japanese = try table("ja")
        let kana = CharacterSet(charactersIn: "\u{3040}"..."\u{30FF}").union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
        let latinOnlyAllowed: Set<String> = ["email@domain.com", "OK", "Preparing Data..."]
        for (key, value) in japanese where !latinOnlyAllowed.contains(key) {
            XCTAssertNotNil(value.unicodeScalars.first(where: kana.contains), "ja: \(key) → \(value) has no Japanese characters")
        }
        XCTAssertEqual(try table("vi")["Levels"], "Cấp độ")
        XCTAssertEqual(japanese["Levels"], "レベル")
        XCTAssertEqual(try table("en")["Levels"], "Levels")
    }

    func test_appLanguageFollowsPreferredLocalizationAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolve(["vi"]), .vietnamese)
        XCTAssertEqual(AppLanguage.resolve(["ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolve(["en_GB"]), .english)
        XCTAssertEqual(AppLanguage.resolve(["fr", "ja"]), .japanese, "The first supported preference wins")
        XCTAssertEqual(AppLanguage.resolve(["fr", "de"]), .english)
        XCTAssertEqual(AppLanguage.resolve([]), .english)
    }

    func test_numbersFollowTheAppLanguageNotTheRegion() {
        XCTAssertEqual(1538.formatted(.number.locale(AppLanguage.vietnamese.locale)), "1.538")
        XCTAssertEqual(1538.formatted(.number.locale(AppLanguage.english.locale)), "1,538")
        XCTAssertEqual(1538.formatted(.number.locale(AppLanguage.japanese.locale)), "1,538")
    }

    func test_languageNamesAreWrittenInTheirOwnLanguage() {
        XCTAssertEqual(AppLanguage.allCases.map(\.nativeName), ["Tiếng Việt", "English", "日本語"])
    }
}
