//
//  DesignSystem.swift
//  FlashcardApp
//
//  Semantic design tokens. Native-first: system bars, materials and controls are left to
//  UIKit (Liquid Glass on iOS 26); only content surfaces, accent and type roles are defined
//  here. See docs/UI_REDESIGN_BLUEPRINT.md and docs/ui-redesign/overhaul-2026-11-25/DESIGN_SYSTEM.md.
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

    // MARK: Hit Targets

    enum HitTarget {
        /// Apple HIG minimum touch target on both axes.
        static let minimum: CGFloat = 44
    }

    // MARK: Shape

    enum Radius {
        /// Primary raised hero panel or study card surface. Continuous curve, concentric with device corners.
        static let panel: CGFloat = 28
        /// Standard content cards, editorial blocks and banners.
        static let card: CGFloat = 20
        /// Inputs, compact surfaces, action tiles and AX-adapted rectangular buttons.
        static let control: CGFloat = 14
        /// Filter chips, kanji tiles and rounded pills.
        static let chip: CGFloat = 12
        /// Micro badges and inline metadata tags.
        static let badge: CGFloat = 8
    }

    // MARK: Colors

    enum Color {
        /// Screen background: warm paper in light, near-black in dark.
        static let background = dynamic(light: 0xF6F3ED, dark: 0x0F0F10)
        /// Raised surface placed on `background` (grouped content, cards, controls).
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
        /// Slightly elevated card surface in dark mode for nested panels.
        static let surfaceElevated = dynamic(light: 0xFFFFFF, dark: 0x242426)
        /// Quiet warm recessed surface for icon tiles, inactive pills and subtle containers.
        static let surfaceTint = dynamic(light: 0xECE8DF, dark: 0x242426)
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let placeholder = UIColor.placeholderText
        static let separator = UIColor.separator
        /// Hairline border around surfaces and inputs.
        static let border = UIColor.separator
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

        /// Deep indigo block that carries the single primary entry point of a screen.
        static let hero = dynamic(light: 0x23406B, dark: 0x24406E)
        /// Text/icons on an accent-filled control: white on the light-mode indigo, near-black on the dark-mode light blue
        /// (white on `#8FB4F0` is only about 2:1).
        static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0F0F10)
        /// Foreground for paper-colored controls placed on `hero`.
        static let heroDeep = rgb(0x1B2F52)
        /// Paper-colored text and controls on `hero` (≥ 8:1 in both appearances).
        static let onHero = rgb(0xF6F3ED)
        static let onHeroSecondary = rgb(0xF6F3ED).withAlphaComponent(0.82)
        /// Translucent chip/badge background placed directly on `hero`.
        static let heroChipFill = rgb(0xF6F3ED).withAlphaComponent(0.16)

        /// Subtle tinted background for status badges (always pair with matching icon/text).
        static func statusFill(_ color: UIColor) -> UIColor {
            color.withAlphaComponent(0.12)
        }

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
        /// Kanji numeral of a level (五) in a list row; Mincho, the typographic anchor of the row.
        case numeral
        /// The same numeral at display size for the featured level.
        case numeralDisplay
        /// Short label above a heading ("Bắt đầu từ đây").
        case eyebrow
        /// Initial of a person's name inside the account avatar; Mincho like the level numerals.
        case monogram
        /// The word on a study card: the largest text on the screen, so it reads at arm's length.
        case term
        /// The meaning on the back of a study card.
        case answer
        /// The one large number on the Today block: a count of items, in the same Mincho as the level numerals.
        case heroFigure
        /// Screen headline in an editorial serif (New York for Latin and Vietnamese, Hiragino Mincho for kana and kanji).
        case display
        /// The headword at the top of a dictionary entry: the largest, most carefully set text on the screen.
        case entryHeadword
        /// One kanji shown as a character to study (its stroke forms must stay legible): Mincho, very large.
        case kanjiGlyph
        /// Titles of the sections of a dictionary entry, in sentence case.
        case sectionTitle
        /// A Japanese example sentence: comfortable for long reading sessions.
        case sentence
        /// The title of a magazine article: Mincho, so a Japanese headline reads like print.
        case articleTitle

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
            case .numeral: return Self.mincho(size: 44, style: .title1, maximum: 72)
            case .numeralDisplay: return Self.mincho(size: 96, style: .largeTitle, maximum: 150)
            case .eyebrow: return Self.weighted(.caption1, weight: .semibold)
            case .monogram: return Self.mincho(size: 32, style: .title1, maximum: 44)
            case .term: return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 52, weight: .semibold), maximumPointSize: 96)
            case .answer: return .preferredFont(forTextStyle: .title2)
            case .display: return Self.editorialSerif(.largeTitle)
            case .entryHeadword: return Self.mincho(size: 52, style: .largeTitle, maximum: 88)
            case .kanjiGlyph: return Self.mincho(size: 120, style: .largeTitle, maximum: 190)
            case .sectionTitle: return Self.weighted(.subheadline, weight: .semibold)
            case .sentence: return .preferredFont(forTextStyle: .title3)
            case .articleTitle: return Self.mincho(size: 28, style: .title1, maximum: 44)
            case .heroFigure: return Self.mincho(size: 36, style: .largeTitle, maximum: 56)
            }
        }

        var color: UIColor {
            switch self {
            case .title, .headword, .meaning, .explanation, .figure, .term, .answer, .display, .entryHeadword, .kanjiGlyph, .sentence, .articleTitle: return Color.textPrimary
            case .sectionTitle: return Color.textSecondary
            case .reading, .metadata: return Color.textSecondary
            case .mark, .numeral, .monogram: return Color.accent
            case .numeralDisplay, .heroFigure: return Color.onHero
            case .eyebrow: return Color.textSecondary
            }
        }

        /// `UIFontMetrics` expects the size at the default (Large) category and scales it itself;
        /// starting from the already-scaled preferred size would scale twice.
        private static func baseSize(_ style: UIFont.TextStyle) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style,
                                 compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        }

        /// Dynamic-Type-safe weighted system font that updates automatically with `adjustsFontForContentSizeCategory`.
        static func weighted(_ style: UIFont.TextStyle, weight: UIFont.Weight, maximum: CGFloat? = nil) -> UIFont {
            let base = UIFont.systemFont(ofSize: baseSize(style), weight: weight)
            if let maximum {
                return UIFontMetrics(forTextStyle: style).scaledFont(for: base, maximumPointSize: maximum)
            }
            return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        }

        private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: baseSize(style), weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
        }

        /// Hiragino Mincho gives kanji numerals a printed, editorial stroke contrast; the system
        /// serif (New York) has no CJK glyphs. Falls back to the system serif if the face is missing.
        static func mincho(size: CGFloat, style: UIFont.TextStyle, maximum: CGFloat) -> UIFont {
            let font = UIFont(name: "HiraMinProN-W6", size: size) ?? serif(size: size)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font, maximumPointSize: maximum)
        }

        /// New York for the Latin script with Hiragino Mincho as the cascade for CJK, so one headline
        /// reads as the same typeface in Vietnamese, English and Japanese.
        private static func editorialSerif(_ style: UIFont.TextStyle) -> UIFont {
            let size = baseSize(style)
            let base = UIFont.systemFont(ofSize: size, weight: .semibold)
            var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            if let mincho = UIFont(name: "HiraMinProN-W6", size: size) {
                descriptor = descriptor.addingAttributes([.cascadeList: [mincho.fontDescriptor]])
            }
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size),
                                                                  maximumPointSize: 56)
        }

        private static func serif(size: CGFloat) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: .semibold)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
        }

        private static func tabular(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            UIFontMetrics(forTextStyle: style)
                .scaledFont(for: .monospacedDigitSystemFont(ofSize: baseSize(style), weight: weight))
        }
    }

    // MARK: Controls

    enum Button {
        /// Capsules look crisp on one line, but wrap into giant oval blobs at AX sizes.
        /// Switching to `.large` rounded rectangles at accessibility sizes keeps buttons legible and compact.
        static func cornerStyle(for traits: UITraitCollection = .current) -> UIButton.Configuration.CornerStyle {
            traits.preferredContentSizeCategory.isAccessibilityCategory ? .large : .capsule
        }

        /// Single primary action on a screen (e.g. retry, submit, reveal). Accent-filled, ≥ 44 pt.
        static func primary(title: String,
                            systemImage: String? = nil,
                            traits: UITraitCollection = .current) -> UIButton.Configuration {
            var configuration = UIButton.Configuration.borderedProminent()
            configuration.title = title
            configuration.titleAlignment = .center
            configuration.cornerStyle = cornerStyle(for: traits)
            configuration.buttonSize = .large
            configuration.baseBackgroundColor = Color.accent
            configuration.baseForegroundColor = Color.onAccent
            if let systemImage {
                configuration.image = UIImage(systemName: systemImage)
                configuration.imagePadding = Design.Spacing.s
            }
            return configuration
        }

        /// Secondary action on paper: raised white/dark surface with hairline border and accent ink.
        static func secondary(title: String,
                              systemImage: String? = nil,
                              traits: UITraitCollection = .current) -> UIButton.Configuration {
            var configuration = UIButton.Configuration.bordered()
            configuration.title = title
            configuration.titleAlignment = .center
            configuration.cornerStyle = cornerStyle(for: traits)
            configuration.buttonSize = .large
            configuration.baseBackgroundColor = Color.surface
            configuration.baseForegroundColor = Color.accent
            configuration.background.strokeColor = Color.border
            configuration.background.strokeWidth = 1
            if let systemImage {
                configuration.image = UIImage(systemName: systemImage)
                configuration.imagePadding = Design.Spacing.s
            }
            return configuration
        }

        /// Compact selectable chip or action pill on paper surfaces (replaces muddy `.gray()` buttons).
        static func surfaceChip(title: String,
                                systemImage: String? = nil,
                                selected: Bool = false,
                                traits: UITraitCollection = .current) -> UIButton.Configuration {
            var configuration = UIButton.Configuration.filled()
            configuration.title = title
            configuration.titleAlignment = .center
            configuration.cornerStyle = cornerStyle(for: traits)
            configuration.buttonSize = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: Design.Spacing.s + 2, leading: Design.Spacing.m + 2,
                bottom: Design.Spacing.s + 2, trailing: Design.Spacing.m + 2
            )
            configuration.baseBackgroundColor = selected ? Color.accent : Color.surface
            configuration.baseForegroundColor = selected ? Color.onAccent : Color.textPrimary
            configuration.background.strokeColor = selected ? .clear : Color.border
            configuration.background.strokeWidth = selected ? 0 : 1
            if let systemImage {
                configuration.image = UIImage(systemName: systemImage)
                configuration.imagePadding = Design.Spacing.xs + 2
            }
            return configuration
        }

        /// Primary action on the `hero` block: paper-colored capsule (or `.large` at AX) with indigo text.
        static func hero(title: String, traits: UITraitCollection = .current) -> UIButton.Configuration {
            let isAX = traits.preferredContentSizeCategory.isAccessibilityCategory
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = cornerStyle(for: traits)
            configuration.buttonSize = .large
            configuration.titleAlignment = .center
            configuration.baseBackgroundColor = Color.onHero
            configuration.baseForegroundColor = Color.heroDeep
            var text = AttributedString(title)
            text.font = UIFont.preferredFont(forTextStyle: .headline)
            configuration.attributedTitle = text
            configuration.image = isAX ? nil : UIImage(systemName: "arrow.right")
            configuration.imagePlacement = .trailing
            configuration.imagePadding = Design.Spacing.s
            return configuration
        }

        /// The icon-only action on the `hero` block: a 44 pt paper disc with an indigo play symbol. Its words are the accessibility label.
        static func heroIcon() -> UIButton.Configuration {
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = .capsule
            configuration.image = UIImage(systemName: "play.fill")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            configuration.contentInsets = .zero
            configuration.baseBackgroundColor = Color.onHero
            configuration.baseForegroundColor = Color.heroDeep
            return configuration
        }

        /// A quiet capsule on the `hero` block for a setting the learner can change, such as the session length.
        static func heroChip(title: String, traits: UITraitCollection = .current) -> UIButton.Configuration {
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = cornerStyle(for: traits)
            configuration.buttonSize = .medium
            configuration.image = UIImage(systemName: "timer")
            configuration.imagePadding = Design.Spacing.xs
            configuration.baseBackgroundColor = Color.heroChipFill
            configuration.baseForegroundColor = Color.onHero
            var text = AttributedString(title)
            text.font = UIFont.preferredFont(forTextStyle: .subheadline)
            configuration.attributedTitle = text
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

extension UIView {
    /// Styles a container as a standard raised card on `Design.Color.background` and keeps its
    /// `CGColor` border synced with Light/Dark appearance changes.
    func applyCardSurface(radius: CGFloat = Design.Radius.card,
                          background: UIColor = Design.Color.surface,
                          borderColor: UIColor? = Design.Color.border,
                          borderWidth: CGFloat = 1) {
        backgroundColor = background
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        if let borderColor {
            layer.borderWidth = borderWidth
            layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
            observeAdaptiveBorder { borderColor }
        } else {
            layer.borderWidth = 0
            layer.borderColor = nil
        }
    }

    /// Re-resolves `layer.borderColor` whenever the user switches Light/Dark mode so `CGColor` never goes stale.
    func observeAdaptiveBorder(_ colorProvider: @escaping () -> UIColor) {
        layer.borderColor = colorProvider().resolvedColor(with: traitCollection).cgColor
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.layer.borderColor = colorProvider().resolvedColor(with: view.traitCollection).cgColor
        }
    }
}

extension UIButton {
    /// Keeps a configured button's corner style adapted between `.capsule` (standard) and `.large` (AX sizes).
    func enableAdaptiveCornerStyle() {
        func sync(_ button: UIButton) {
            guard var config = button.configuration else { return }
            config.cornerStyle = Design.Button.cornerStyle(for: button.traitCollection)
            button.configuration = config
        }
        sync(self)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: UIButton, _) in
            sync(button)
        }
    }
}

extension UIFont {
    /// Same face and size with another weight; keeps Dynamic Type scaling of the source font.
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
