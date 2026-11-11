//
//  KanaAnswer.swift
//  FlashcardApp
//
//  Checks a reading the learner typed against the card's reading. Pure Foundation.
//
//  Accepted as the same reading: hiragana or katakana, full or half width katakana, a dakuten typed as a separate mark, and
//  spaces or "・" between the parts. NOT accepted: romaji, kanji, or "ー" standing in for a vowel ("らーめん" is not "らあめん").
//

import Foundation

enum KanaAnswer {
    private static let hiraganaToKatakanaOffset: UInt32 = 0x60
    private static let separators: Set<Unicode.Scalar> = ["\u{30FB}"]
    private static let longVowelMark: Unicode.Scalar = "\u{30FC}"

    /// The reading folded to hiragana without spaces or separators; "" when there is nothing to compare.
    static func normalized(_ text: String) -> String {
        // Compatibility composition turns half-width katakana into full width and joins a separate dakuten to its kana.
        var result = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCompatibilityMapping.unicodeScalars {
            if scalar.properties.isWhitespace || separators.contains(scalar) { continue }
            // Katakana ァ…ヶ (and the iteration marks ヽヾ) sit exactly 0x60 above their hiragana; "ー" stays as it is.
            if (0x30A1...0x30F6).contains(scalar.value) || scalar.value == 0x30FD || scalar.value == 0x30FE,
               let folded = Unicode.Scalar(scalar.value - hiraganaToKatakanaOffset) {
                result.append(folded)
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }

    /// Whether a card's reading can be asked as a typed answer: only kana (and "ー"), nothing else.
    static func isKana(_ text: String) -> Bool {
        let folded = normalized(text)
        guard !folded.isEmpty else { return false }
        return folded.unicodeScalars.allSatisfy { (0x3041...0x309E).contains($0.value) || $0 == longVowelMark }
    }

    static func matches(typed: String, expected: String) -> Bool {
        let answer = normalized(typed)
        return !answer.isEmpty && answer == normalized(expected)
    }
}
