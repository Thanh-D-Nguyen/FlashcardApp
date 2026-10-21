//
//  DesignSystem.swift
//  FlashcardApp
//
//  Semantic design tokens. Native-first: colors resolve from UIKit system colors
//  so light/dark, increased contrast and tint follow the platform. See docs/UI_FOUNDATION.md.
//

import UIKit

enum Design {

    // MARK: Spacing (4-pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: Colors

    enum Color {
        /// Screen background behind grouped lists.
        static let background = UIColor.systemGroupedBackground
        /// Row / card surface placed on `background`.
        static let surface = UIColor.secondarySystemGroupedBackground
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let separator = UIColor.separator
        /// Interactive elements follow the window tint.
        static let accent = UIColor.tintColor

        // Status colors are text-safe: light variants are darker than the system colors
        // (systemRed on white is only 3.55:1). Always pair with an icon or words.
        static let error = dynamic(light: 0xB3261E, dark: UIColor.systemRed)
        static let success = dynamic(light: 0x1E6B34, dark: UIColor.systemGreen)
        static let warning = dynamic(light: 0x8A4B00, dark: UIColor.systemOrange)

        private static func dynamic(light: UInt32, dark: UIColor) -> UIColor {
            let lightColor = UIColor(
                red: CGFloat((light >> 16) & 0xFF) / 255,
                green: CGFloat((light >> 8) & 0xFF) / 255,
                blue: CGFloat(light & 0xFF) / 255,
                alpha: 1)
            return UIColor { $0.userInterfaceStyle == .dark ? dark : lightColor }
        }
    }

    // MARK: Typography

    /// Text roles for Japanese study content. Every role is built on a Dynamic Type
    /// text style; the system font falls back to Hiragino for kana/kanji.
    enum TextRole {
        /// Level / section names and other plain list titles.
        case title
        /// Kanji or vocabulary headword.
        case headword
        /// Kana reading of a headword (furigana is not supplied by the content).
        case reading
        /// Vietnamese meaning.
        case meaning
        /// Grammar explanation and other multiline prose.
        case explanation
        /// Counts, tags, JLPT level and other secondary metadata.
        case metadata

        var font: UIFont {
            switch self {
            case .title: return .preferredFont(forTextStyle: .headline)
            case .headword: return .preferredFont(forTextStyle: .title3)
            case .reading: return .preferredFont(forTextStyle: .subheadline)
            case .meaning: return .preferredFont(forTextStyle: .body)
            case .explanation: return .preferredFont(forTextStyle: .body)
            case .metadata: return .preferredFont(forTextStyle: .footnote)
            }
        }

        var color: UIColor {
            switch self {
            case .title, .headword, .meaning, .explanation: return Color.textPrimary
            case .reading, .metadata: return Color.textSecondary
            }
        }
    }
}

extension UIListContentConfiguration.TextProperties {
    /// Applies a text role with Dynamic Type scaling and unlimited lines (no truncation).
    mutating func apply(_ role: Design.TextRole) {
        font = role.font
        color = role.color
        adjustsFontForContentSizeCategory = true
        numberOfLines = 0
    }
}
