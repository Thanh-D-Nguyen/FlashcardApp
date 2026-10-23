import UIKit
import XCTest
@testable import FlashcardApp

/// The catalogue is the website's: same slugs, readable palettes, and a safe fall back for an unknown slug.
final class CardStyleTests: XCTestCase {
    func test_theCatalogueIsTheWebsitesInItsOrder() {
        XCTAssertEqual(CardStyle.catalog.map(\.slug),
                       ["minimal-ink", "warm-paper", "dark-focus", "sakura-bloom", "neon-tokyo", "ocean-calm", "gold-calligraphy"])
        XCTAssertEqual(Set(CardStyle.catalog.map(\.slug)).count, CardStyle.catalog.count)
    }

    func test_aSlugIsResolvedAndAnUnknownOrMissingOneIsTheDefaultCard() {
        XCTAssertEqual(CardStyle.style(forSlug: "neon-tokyo"), .neonTokyo)
        XCTAssertNil(CardStyle.style(forSlug: "no-such-style"))
        XCTAssertNil(CardStyle.style(forSlug: nil))
        XCTAssertNil(CardStyle.style(forSlug: ""))
    }

    /// The website holds every theme to these ratios (WCAG AA: 4.5 for text, 3 for borders and accents).
    func test_everyPaletteIsReadable() {
        for style in CardStyle.catalog {
            func ratio(_ foreground: UInt32, _ background: UInt32) -> Double { CardStyle.contrastRatio(foreground, background) }
            XCTAssertGreaterThanOrEqual(ratio(style.foreground, style.contentSurface), 4.5, "\(style.slug) text")
            XCTAssertGreaterThanOrEqual(ratio(style.mutedForeground, style.contentSurface), 4.5, "\(style.slug) secondary text")
            XCTAssertGreaterThanOrEqual(ratio(style.accentForeground, style.accent), 4.5, "\(style.slug) on accent")
            XCTAssertGreaterThanOrEqual(ratio(style.border, style.contentSurface), 3, "\(style.slug) border")
            XCTAssertGreaterThanOrEqual(ratio(style.accent, style.contentSurface), 3, "\(style.slug) accent")
        }
    }

    func test_contrastRatioMatchesTheWcagDefinition() {
        XCTAssertEqual(CardStyle.contrastRatio(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(CardStyle.contrastRatio(0xFFFFFF, 0xFFFFFF), 1, accuracy: 0.001)
    }

    func test_everyStyleHasALocalisedNameAndDescription() {
        for style in CardStyle.catalog {
            XCTAssertFalse(style.name.isEmpty)
            XCTAssertNotEqual(style.name, style.slug)
            XCTAssertFalse(style.summary.isEmpty)
        }
        XCTAssertEqual(Set(CardStyle.catalog.map(\.name)).count, CardStyle.catalog.count)
    }

    func test_aSolidStyleThatMatchesItsSurfaceIsNotFramedAndAGradientIs() {
        XCTAssertFalse(CardStyle.minimalInk.isFramed)
        XCTAssertFalse(CardStyle.warmPaper.isFramed)
        XCTAssertTrue(CardStyle.sakuraBloom.isFramed)
        XCTAssertTrue(CardStyle.neonTokyo.isFramed)
        XCTAssertTrue(CardStyle.goldCalligraphy.isFramed)
    }

    func test_gradientsFollowTheCssAngle() throws {
        XCTAssertNil(CardStyle.minimalInk.makeGradientLayer())
        let diagonal = try XCTUnwrap(CardStyle.sakuraBloom.makeGradientLayer())
        XCTAssertEqual(diagonal.startPoint.x, 0.146, accuracy: 0.01)
        XCTAssertEqual(diagonal.startPoint.y, 0.146, accuracy: 0.01)
        XCTAssertEqual(diagonal.endPoint.x, 0.854, accuracy: 0.01)
        XCTAssertEqual(diagonal.endPoint.y, 0.854, accuracy: 0.01)
        let vertical = try XCTUnwrap(CardStyle.oceanCalm.makeGradientLayer())
        XCTAssertEqual(vertical.startPoint.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(vertical.startPoint.y, 0, accuracy: 0.001)
        XCTAssertEqual(vertical.endPoint.y, 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(CardStyle.neonTokyo.makeGradientLayer()).locations, [0, 0.5, 1])
    }

    func test_theFlipFollowsTheWebsitesAnimation() {
        XCTAssertEqual(CardStyle.sakuraBloom.flip, .vertical)
        XCTAssertEqual(CardStyle.oceanCalm.flip, .vertical)
        XCTAssertEqual(CardStyle.minimalInk.flip, .horizontal)
    }

    func test_serifAndRoundedStylesAskForAJapaneseFaceToCoverKanaAndKanji() {
        let serif = CardStyle.warmPaper.font(textStyle: .body)
        let rounded = CardStyle.sakuraBloom.font(textStyle: .body)
        XCTAssertNotNil(serif.fontDescriptor.object(forKey: .cascadeList))
        XCTAssertNotNil(rounded.fontDescriptor.object(forKey: .cascadeList))
        XCTAssertNil(CardStyle.minimalInk.font(textStyle: .body).fontDescriptor.object(forKey: .cascadeList), "The standard design uses the system fallback")
    }

    func test_aStylesFontsScaleWithDynamicTypeUpToTheirLimit() {
        func pointSize(_ category: UIContentSizeCategory, maximum: CGFloat? = nil) -> CGFloat {
            CardStyle.warmPaper.font(textStyle: .body, maximum: maximum, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
        }
        XCTAssertGreaterThan(pointSize(.accessibilityExtraExtraExtraLarge), pointSize(.extraSmall))
        XCTAssertEqual(pointSize(.accessibilityExtraExtraExtraLarge, maximum: 30), 30, accuracy: 0.01, "A headword stops growing at its maximum")
    }
}
