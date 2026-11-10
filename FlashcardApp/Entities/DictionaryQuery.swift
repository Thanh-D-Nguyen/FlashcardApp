//
//  DictionaryQuery.swift
//  FlashcardApp
//
//  What the learner typed, made safe to send: the search endpoint counts BYTES (2…200), so one kanji is enough and a
//  single Latin letter is not. Romaji has no server support; the app converts it locally and only OFFERS the kana
//  reading, because "an" is also a Vietnamese word and the server cannot tell which language was meant.
//

import Foundation

struct DictionaryQuery: Equatable {
    static let minimumBytes = 2
    static let maximumBytes = 200

    let text: String

    enum Validity: Equatable {
        case empty
        case tooShort
        case tooLong
        case valid(DictionaryQuery)
    }

    static func validate(_ raw: String) -> Validity {
        // NFKC folds full-width Latin and half-width katakana (what a Japanese keyboard produces) into the forms the index holds.
        let folded = raw.precomposedStringWithCompatibilityMapping
        let text = folded.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        guard !text.isEmpty else { return .empty }
        let bytes = text.utf8.count
        if bytes < minimumBytes { return .tooShort }
        if bytes > maximumBytes { return .tooLong }
        return .valid(DictionaryQuery(text: text))
    }

    /// Hiragana for a query typed in romaji ("taberu" → "たべる"), or `nil` when the text is not entirely romaji.
    var kanaCandidate: String? { RomajiConverter.hiragana(from: text) }
}

/// Hepburn (with the common Kunrei spellings) to hiragana. All-or-nothing: any leftover Latin letter, space or accent
/// means the text was not romaji, so a Vietnamese query is never turned into kana by accident.
enum RomajiConverter {
    static func hiragana(from input: String) -> String? {
        let source = Array(input.lowercased())
        guard !source.isEmpty, source.allSatisfy({ ($0.isASCII && ($0.isLetter || $0 == "'" || $0 == "-")) }) else { return nil }
        var output = ""
        var index = 0
        while index < source.count {
            let rest = source[index...]
            // っ: a doubled consonant (but not n, which is ん).
            if rest.count >= 2, consonants.contains(rest[index]), rest[index] != "n",
               rest[index] == rest[index + 1] || (rest[index] == "t" && rest[index + 1] == "c") {
                output.append("っ")
                index += 1
                continue
            }
            if source[index] == "-" { output.append("ー"); index += 1; continue }
            if source[index] == "'" { index += 1; continue }
            // ん before a consonant other than y, at the end, or written nn / n'.
            if source[index] == "n" {
                let next = index + 1 < source.count ? source[index + 1] : nil
                if next == nil || next == "'" || (next == "n" && !(index + 2 < source.count && vowelsAndY.contains(source[index + 2]))) {
                    output.append("ん")
                    index += (next == "'" || next == "n") ? 2 : 1
                    continue
                }
                if let next, !vowelsAndY.contains(next) {
                    output.append("ん")
                    index += 1
                    continue
                }
            }
            var matched = false
            for length in stride(from: min(3, source.count - index), through: 1, by: -1) {
                let chunk = String(source[index..<index + length])
                if let kana = table[chunk] {
                    output.append(kana)
                    index += length
                    matched = true
                    break
                }
            }
            if !matched { return nil }
        }
        return output.isEmpty ? nil : output
    }

    private static let consonants: Set<Character> = ["k", "s", "t", "h", "m", "y", "r", "w", "g", "z", "d", "b", "p", "f", "j", "c"]
    private static let vowelsAndY: Set<Character> = ["a", "i", "u", "e", "o", "y"]

    private static let table: [String: String] = {
        var table: [String: String] = [
            "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
            "sa": "さ", "shi": "し", "si": "し", "su": "す", "se": "せ", "so": "そ",
            "ta": "た", "chi": "ち", "ti": "ち", "tsu": "つ", "tu": "つ", "te": "て", "to": "と",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
            "ha": "は", "hi": "ひ", "fu": "ふ", "hu": "ふ", "he": "へ", "ho": "ほ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
            "ya": "や", "yu": "ゆ", "yo": "よ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
            "wa": "わ", "wo": "を",
            "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "za": "ざ", "ji": "じ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
            "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
            "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "je": "じぇ",
            "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "che": "ちぇ",
            "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "she": "しぇ",
            "tsa": "つぁ", "thi": "てぃ", "dhi": "でぃ", "wi": "うぃ", "we": "うぇ"
        ]
        // Contracted syllables: consonant + y + a/u/o.
        let contracted: [(String, String)] = [("ky", "き"), ("gy", "ぎ"), ("sy", "し"), ("zy", "じ"), ("jy", "じ"), ("ty", "ち"), ("cy", "ち"),
                                              ("dy", "ぢ"), ("ny", "に"), ("hy", "ひ"), ("by", "び"), ("py", "ぴ"), ("my", "み"), ("ry", "り")]
        for (prefix, base) in contracted {
            for (vowel, small) in [("a", "ゃ"), ("u", "ゅ"), ("o", "ょ")] { table[prefix + vowel] = base + small }
        }
        return table
    }()
}
