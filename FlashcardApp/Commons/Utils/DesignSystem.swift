//
//  DesignSystem.swift
//  FlashcardApp
//
//  Semantic design tokens. Native-first: system bars, materials and controls are left to
//  UIKit (Liquid Glass on iOS 26); only content surfaces, accent and type roles are defined
//  here. See docs/UI_REDESIGN_BLUEPRINT.md.
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
        static let xxl: CGFloat = 32
        /// Leading/trailing content gutter; aligns row text with the large navigation title.
        static let gutter: CGFloat = 16
    }

    // MARK: Colors

    enum Color {
        /// Screen background: warm paper in light, near-black in dark.
        static let background = dynamic(light: 0xF6F3ED, dark: 0x0F0F10)
        /// Raised surface placed on `background` (grouped content, controls).
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let separator = UIColor.separator
        /// 藍 (indigo). Also the window tint through the `AccentColor` asset, so system
        /// controls, selected tabs and links share one accent. 8.0:1 on `background` (light).
        static let accent = UIColor.tintColor
        /// Fill for pressed/selected rows. Derived from the accent so it follows both appearances.
        static let highlight = UIColor.tintColor.withAlphaComponent(0.10)

        // Status colors are text-safe: light variants are darker than the system colors
        // (systemRed on white is only 3.55:1). Always pair with an icon or words.
        static let error = dynamic(light: 0xB3261E, dark: UIColor.systemRed)
        static let success = dynamic(light: 0x1E6B34, dark: UIColor.systemGreen)
        static let warning = dynamic(light: 0x8A4B00, dark: UIColor.systemOrange)

        private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
            dynamic(light: light, dark: rgb(dark))
        }

        private static func dynamic(light: UInt32, dark: UIColor) -> UIColor {
            let lightColor = rgb(light)
            return UIColor { $0.userInterfaceStyle == .dark ? dark : lightColor }
        }

        private static func rgb(_ value: UInt32) -> UIColor {
            UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255, alpha: 1)
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
        /// Large serif mark that identifies a level (J5, J1+). Editorial accent, not body text.
        case mark
        /// Numeric values in running metadata; tabular so counts align across rows.
        case figure

        var font: UIFont {
            switch self {
            case .title: return .preferredFont(forTextStyle: .headline)
            case .headword: return .preferredFont(forTextStyle: .title2)
            case .reading: return .preferredFont(forTextStyle: .subheadline)
            case .meaning: return .preferredFont(forTextStyle: .body)
            case .explanation: return .preferredFont(forTextStyle: .body)
            case .metadata: return .preferredFont(forTextStyle: .footnote)
            case .mark: return Self.serif(.largeTitle, weight: .semibold)
            case .figure: return Self.tabular(.footnote, weight: .semibold)
            }
        }

        var color: UIColor {
            switch self {
            case .title, .headword, .meaning, .explanation, .figure: return Color.textPrimary
            case .reading, .metadata: return Color.textSecondary
            case .mark: return Color.accent
            }
        }

        /// `UIFontMetrics` expects the size at the default (Large) category and scales it itself;
        /// starting from the already-scaled preferred size would scale twice.
        private static func baseSize(_ style: UIFont.TextStyle) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style,
                                 compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        }

        private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: baseSize(style), weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
        }

        private static func tabular(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            UIFontMetrics(forTextStyle: style)
                .scaledFont(for: .monospacedDigitSystemFont(ofSize: baseSize(style), weight: weight))
        }
    }

    // MARK: Controls

    enum Button {
        /// Single primary action on a screen (e.g. retry). Capsule, accent-filled, 44 pt minimum.
        static func primary(title: String) -> UIButton.Configuration {
            var configuration = UIButton.Configuration.borderedProminent()
            configuration.title = title
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .large
            configuration.baseBackgroundColor = Color.accent
            return configuration
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

extension UILabel {
    /// Configures a label for a text role. Labels wrap instead of truncating Japanese or Vietnamese.
    func apply(_ role: Design.TextRole) {
        font = role.font
        textColor = role.color
        adjustsFontForContentSizeCategory = true
        numberOfLines = 0
    }
}
