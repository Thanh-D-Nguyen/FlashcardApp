import Foundation

/// Script detection for card text. A card side is "Japanese" when it holds kana or kanji, whichever deck
/// direction it belongs to, so mixed-direction decks and cards typed on the "wrong" side still behave.
enum JapaneseText {
    static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isJapanese)
    }

    private static func isJapanese(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x309F,   // hiragana
             0x30A0...0x30FF,   // katakana (includes the long-vowel mark ー)
             0x31F0...0x31FF,   // katakana phonetic extensions
             0xFF66...0xFF9F,   // half-width katakana
             0x3400...0x4DBF,   // CJK extension A
             0x4E00...0x9FFF,   // CJK unified ideographs
             0xF900...0xFAFF:   // CJK compatibility ideographs
            return true
        default:
            return false
        }
    }

    /// Which side of a card is Japanese. When exactly one side holds kana or kanji that side is Japanese, whatever the deck's
    /// direction says (a generated deck can mix directions card by card); otherwise `deckHasJapaneseOnFront` decides.
    static func japaneseIsOnFront(front: String, back: String, deckHasJapaneseOnFront: Bool) -> Bool {
        let frontJapanese = containsJapanese(front), backJapanese = containsJapanese(back)
        return frontJapanese != backJapanese ? frontJapanese : deckHasJapaneseOnFront
    }

    /// Lower-cased, diacritic-free form for comparing Vietnamese words typed with or without tone marks.
    static func folded(_ text: String) -> String {
        text.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
    }

    /// The first gloss of a dictionary meaning ("ăn; dùng bữa" → "ăn"), a short search term for a picture.
    static func firstGloss(of meaning: String, maximumLength: Int = 60) -> String {
        let first = meaning.split(whereSeparator: { ";,，、・/".contains($0) }).first.map(String.init) ?? meaning
        return String(first.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumLength))
    }
}
