import Foundation

/// A part of the website the app offers from the Discover tab. The website has more features than the app; each one is
/// added here when it is built, and only then does it appear. To add one: a case here, its entry in
/// `DiscoverWireframe.show(_:)`, and its strings. Nothing else in Discover changes.
enum DiscoverFeature: CaseIterable, Equatable {
    case loto
    case magazine
    case levels

    /// The groups of the hub, in the order they are shown (the website's Explore page groups its features the same way).
    enum Section: CaseIterable {
        case featured, study

        /// nil for a section without a heading.
        var title: String? {
            switch self {
            case .featured: return nil
            case .study: return NSLocalizedString("Read and study", comment: "Discover: section of reading and levels")
            }
        }
    }

    var section: Section {
        switch self {
        case .loto: return .featured
        case .magazine, .levels: return .study
        }
    }

    /// Features that are built, in the order they are listed. A feature that is planned but not built is not listed.
    static var available: [DiscoverFeature] { allCases.filter(\.isAvailable) }

    var isAvailable: Bool {
        switch self {
        case .loto, .magazine, .levels: return true
        }
    }

    var title: String {
        switch self {
        case .loto: return NSLocalizedString("Loto picks", comment: "Discover: Loto number sets")
        case .magazine: return NSLocalizedString("Magazine", comment: "Name of the daily reading feed")
        case .levels: return NSLocalizedString("BJT levels", comment: "Discover: the BJT levels")
        }
    }

    var subtitle: String {
        switch self {
        case .loto: return NSLocalizedString("Numbers for the next Loto 6 and Loto 7 draws, with a countdown and the reasons behind them.", comment: "Discover: Loto description")
        case .magazine: return NSLocalizedString("A short daily read: vocabulary, weather, workplace phrases and a quick quiz.", comment: "Discover: Magazine description")
        case .levels: return NSLocalizedString("Content to study by BJT level, J1 to J5", comment: "Discover: BJT levels description")
        }
    }

    /// What is inside the feature, as short labels under its description.
    var tags: [String] {
        switch self {
        case .magazine: return MagazineKind.allCases.map(\.title)
        case .loto: return [LotoGame.loto6.title, LotoGame.loto7.title]
        case .levels: return []
        }
    }

    /// SF Symbol that stands for the feature.
    var symbol: String {
        switch self {
        case .loto: return "circle.hexagongrid.fill"
        case .magazine: return "newspaper.fill"
        case .levels: return "graduationcap.fill"
        }
    }

    /// The one entry drawn as a dark hero card instead of a paper card.
    var isFeatured: Bool { self == .loto }

    var accessibilityIdentifier: String {
        switch self {
        case .loto: return "discover_loto"
        case .magazine: return "discover_magazine"
        case .levels: return "discover_levels"
        }
    }
}
