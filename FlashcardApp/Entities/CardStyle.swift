//
//  CardStyle.swift
//  FlashcardApp
//
//  The look of the study card. The catalogue is the website's (`FLASHCARD_THEME_DEFINITIONS` in
//  `packages/shared/src/flashcard-theme.ts`, also served by `GET /api/flashcards/styles`): same slugs, palettes,
//  radii, shadows and flip direction, so a style means the same card on both. The website's web fonts are mapped
//  to the system faces (Hiragino Mincho for serif, Hiragino Maru Gothic for rounded) instead of bundling fonts.
//
//  The choice is a per-device preference (`StudyPreferences`); it is not synced with the account's
//  `PUT /api/flashcards/styles/active`. The server marks every style unlocked, so none is gated here.
//  `nil` is the app's own adaptive card, which follows Light and Dark appearance.
//

import UIKit

struct CardStyle: Equatable {
    enum Background: Equatable {
        case solid(UInt32)
        /// CSS `linear-gradient(<angle>deg, stops…)`, stops evenly spaced.
        case gradient(angle: Double, stops: [UInt32])
    }

    enum FontDesign: Equatable { case standard, serif, rounded }

    enum Flip: Equatable {
        /// CSS `rotateY`: the card turns around its vertical axis.
        case horizontal
        /// CSS `rotateX`.
        case vertical
    }

    struct Shadow: Equatable {
        let color: UInt32
        let opacity: Float
        let radius: CGFloat
        let offsetY: CGFloat
    }

    let slug: String
    let background: Background
    /// Surface text sits on. The contrast of every text colour is checked against it.
    let contentSurface: UInt32
    let foreground: UInt32
    let mutedForeground: UInt32
    let border: UInt32
    let accent: UInt32
    let accentForeground: UInt32
    let cornerRadius: CGFloat
    let fontDesign: FontDesign
    let flip: Flip
    let shadow: Shadow

    /// A style whose background differs from its content surface is drawn as a frame around a content panel.
    var isFramed: Bool {
        if case .solid(let color) = background { return color != contentSurface }
        return true
    }

    // MARK: Catalogue

    static let minimalInk = CardStyle(slug: "minimal-ink", background: .solid(0xFFFFFF), contentSurface: 0xFFFFFF, foreground: 0x111827,
                                      mutedForeground: 0x4B5563, border: 0x64748B, accent: 0x1D4ED8, accentForeground: 0xFFFFFF,
                                      cornerRadius: 16, fontDesign: .standard, flip: .horizontal,
                                      shadow: Shadow(color: 0x000000, opacity: 0.08, radius: 12, offsetY: 4))
    static let warmPaper = CardStyle(slug: "warm-paper", background: .solid(0xFAF6F1), contentSurface: 0xFAF6F1, foreground: 0x3D3225,
                                     mutedForeground: 0x66543F, border: 0x75634D, accent: 0x92400E, accentForeground: 0xFFFFFF,
                                     cornerRadius: 12, fontDesign: .serif, flip: .horizontal,
                                     shadow: Shadow(color: 0x8B5A2B, opacity: 0.10, radius: 8, offsetY: 2))
    static let darkFocus = CardStyle(slug: "dark-focus", background: .solid(0x1E1E2E), contentSurface: 0x1E1E2E, foreground: 0xF8FAFC,
                                     mutedForeground: 0xCBD5E1, border: 0x94A3B8, accent: 0xC4B5FD, accentForeground: 0x1E1E2E,
                                     cornerRadius: 20, fontDesign: .standard, flip: .horizontal,
                                     shadow: Shadow(color: 0x000000, opacity: 0.40, radius: 16, offsetY: 8))
    static let sakuraBloom = CardStyle(slug: "sakura-bloom", background: .gradient(angle: 135, stops: [0xFFF5F7, 0xFFE4EC]),
                                       contentSurface: 0xFFF5F7, foreground: 0x4A1942, mutedForeground: 0x74405F, border: 0x82536B,
                                       accent: 0x9D174D, accentForeground: 0xFFFFFF, cornerRadius: 24, fontDesign: .rounded,
                                       flip: .vertical, shadow: Shadow(color: 0x9D174D, opacity: 0.16, radius: 20, offsetY: 8))
    static let neonTokyo = CardStyle(slug: "neon-tokyo", background: .gradient(angle: 160, stops: [0x0F0C29, 0x302B63, 0x24243E]),
                                     contentSurface: 0x17152B, foreground: 0xF1F5F9, mutedForeground: 0xC7D2FE, border: 0x94A3B8,
                                     accent: 0x4ADE80, accentForeground: 0x0F172A, cornerRadius: 8, fontDesign: .standard,
                                     flip: .horizontal, shadow: Shadow(color: 0x4ADE80, opacity: 0.20, radius: 15, offsetY: 0))
    static let oceanCalm = CardStyle(slug: "ocean-calm", background: .gradient(angle: 180, stops: [0xE0F7FA, 0xB2EBF2]),
                                     contentSurface: 0xE0F7FA, foreground: 0x003B49, mutedForeground: 0x285C66, border: 0x4F6F76,
                                     accent: 0x07566B, accentForeground: 0xFFFFFF, cornerRadius: 28, fontDesign: .standard,
                                     flip: .vertical, shadow: Shadow(color: 0x07566B, opacity: 0.14, radius: 24, offsetY: 12))
    static let goldCalligraphy = CardStyle(slug: "gold-calligraphy", background: .gradient(angle: 145, stops: [0x1A1A1A, 0x2D2D2D]),
                                           contentSurface: 0x1A1A1A, foreground: 0xF5E6C8, mutedForeground: 0xD6C7AA, border: 0xA78F61,
                                           accent: 0xE6C36A, accentForeground: 0x1A1A1A, cornerRadius: 4, fontDesign: .serif,
                                           flip: .horizontal, shadow: Shadow(color: 0xE6C36A, opacity: 0.22, radius: 10, offsetY: 4))

    /// In the website's order.
    static let catalog: [CardStyle] = [.minimalInk, .warmPaper, .darkFocus, .sakuraBloom, .neonTokyo, .oceanCalm, .goldCalligraphy]

    /// `nil` for no slug or one this version does not know (a style removed from the catalogue falls back to the default card).
    static func style(forSlug slug: String?) -> CardStyle? {
        slug.flatMap { slug in catalog.first { $0.slug == slug } }
    }

    // MARK: Names

    var name: String {
        switch slug {
        case "minimal-ink": return NSLocalizedString("Minimal Ink", comment: "Card style name")
        case "warm-paper": return NSLocalizedString("Warm Paper", comment: "Card style name")
        case "dark-focus": return NSLocalizedString("Dark Focus", comment: "Card style name")
        case "sakura-bloom": return NSLocalizedString("Sakura Bloom", comment: "Card style name")
        case "neon-tokyo": return NSLocalizedString("Neon Tokyo", comment: "Card style name")
        case "ocean-calm": return NSLocalizedString("Ocean Calm", comment: "Card style name")
        default: return NSLocalizedString("Gold Calligraphy", comment: "Card style name")
        }
    }

    var summary: String {
        switch slug {
        case "minimal-ink": return NSLocalizedString("Clean, clear, and neutral.", comment: "Card style description")
        case "warm-paper": return NSLocalizedString("A gentle paper tone for longer sessions.", comment: "Card style description")
        case "dark-focus": return NSLocalizedString("A low-glare dark study surface.", comment: "Card style description")
        case "sakura-bloom": return NSLocalizedString("Soft sakura tones with strong readable text.", comment: "Card style description")
        case "neon-tokyo": return NSLocalizedString("High contrast with a modern accent.", comment: "Card style description")
        case "ocean-calm": return NSLocalizedString("An airy, calm blue reading surface.", comment: "Card style description")
        default: return NSLocalizedString("An elegant ink-and-gold combination.", comment: "Card style description")
        }
    }

    // MARK: Contrast (WCAG), used to keep every palette readable

    static func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        func luminance(_ value: UInt32) -> Double {
            func channel(_ shift: UInt32) -> Double {
                let component = Double((value >> shift) & 0xFF) / 255
                return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let lighter = max(luminance(first), luminance(second)), darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }
}

// MARK: UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension CardStyle {
    var foregroundColor: UIColor { UIColor(hex: foreground) }
    var mutedColor: UIColor { UIColor(hex: mutedForeground) }
    var accentColor: UIColor { UIColor(hex: accent) }
    var contentSurfaceColor: UIColor { UIColor(hex: contentSurface) }
    var borderColor: UIColor { UIColor(hex: border) }

    /// Fill of the card. A gradient is drawn by `gradientLayer`; this is its first colour for a plain background.
    var backgroundColor: UIColor {
        switch background {
        case .solid(let color): return UIColor(hex: color)
        case .gradient(_, let stops): return UIColor(hex: stops[0])
        }
    }

    /// `nil` for a solid background. Start and end points follow CSS `linear-gradient(<angle>deg, …)`.
    func makeGradientLayer() -> CAGradientLayer? {
        guard case .gradient(let angle, let stops) = background else { return nil }
        let layer = CAGradientLayer()
        layer.colors = stops.map { UIColor(hex: $0).cgColor }
        layer.locations = stops.indices.map { NSNumber(value: Double($0) / Double(max(stops.count - 1, 1))) }
        let radians = angle * .pi / 180
        layer.startPoint = CGPoint(x: 0.5 - sin(radians) / 2, y: 0.5 + cos(radians) / 2)
        layer.endPoint = CGPoint(x: 0.5 + sin(radians) / 2, y: 0.5 - cos(radians) / 2)
        return layer
    }

    /// A Dynamic Type font in this style's face. Latin and Vietnamese use the system serif or rounded design; kana and
    /// kanji cascade to Hiragino Mincho or Maru Gothic (the system serif has no CJK glyphs).
    func font(textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular, size: CGFloat? = nil, maximum: CGFloat? = nil,
              compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        let size = size ?? UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let japanese: String?
        let design: UIFontDescriptor.SystemDesign?
        switch fontDesign {
        case .standard: japanese = nil; design = nil
        case .serif: japanese = weight >= .semibold ? "HiraMinProN-W6" : "HiraMinProN-W3"; design = .serif
        case .rounded: japanese = "HiraMaruProN-W4"; design = .rounded
        }
        var descriptor = design.flatMap { base.fontDescriptor.withDesign($0) } ?? base.fontDescriptor
        if let japanese, let face = UIFont(name: japanese, size: size) {
            descriptor = descriptor.addingAttributes([.cascadeList: [face.fontDescriptor]])
        }
        let font = UIFont(descriptor: descriptor, size: size)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        if let maximum { return metrics.scaledFont(for: font, maximumPointSize: maximum, compatibleWith: traits) }
        return metrics.scaledFont(for: font, compatibleWith: traits)
    }
}
