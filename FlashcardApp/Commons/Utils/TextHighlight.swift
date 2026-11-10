import UIKit

/// Marks where search terms occur in a piece of text. Matching ignores case and Vietnamese tone marks, so "an" finds "ăn"
/// in a translation; Japanese matches literally. Only ranges that really occur are marked.
enum TextHighlight {
    static func ranges(of terms: [String], in text: String) -> [NSRange] {
        let nsText = text as NSString
        var found: [NSRange] = []
        for term in terms where !term.isEmpty {
            var searchRange = NSRange(location: 0, length: nsText.length)
            while searchRange.length > 0 {
                let range = nsText.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange, locale: Locale(identifier: "vi"))
                guard range.location != NSNotFound, range.length > 0 else { break }
                found.append(range)
                searchRange = NSRange(location: range.upperBound, length: nsText.length - range.upperBound)
            }
        }
        // Merge overlaps so a term and its stem do not paint the same characters twice.
        var merged: [NSRange] = []
        for range in found.sorted(by: { $0.location < $1.location }) {
            if let last = merged.last, range.location <= last.upperBound {
                merged[merged.count - 1] = NSRange(location: last.location, length: max(last.upperBound, range.upperBound) - last.location)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    /// Terms worth marking for a headword: the word itself and, for a word ending in a kana (a verb or い-adjective), its stem,
    /// because the sentence usually holds a conjugated form (食べる → 食べます).
    static func terms(forHeadword headword: String) -> [String] {
        var terms = [headword]
        if headword.count >= 3, let last = headword.last, ("\u{3041}"..."\u{3096}").contains(String(last).unicodeScalars.first!) {
            terms.append(String(headword.dropLast()))
        }
        return terms
    }

    static func attributed(_ text: String, terms: [String], font: UIFont, color: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        for range in ranges(of: terms, in: text) {
            result.addAttributes([
                .backgroundColor: Design.Color.highlight,
                .foregroundColor: Design.Color.accent,
                .font: font.withWeight(.semibold)
            ], range: range)
        }
        return result
    }
}
