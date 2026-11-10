import UIKit

/// How the kinds of article look. Each kind has one quiet tint, used for its icon and its small label and never as the
/// only sign of the kind: the symbol and the words always come with it. The tints are text-safe on the paper surfaces.
extension MagazineKind {
    var tint: UIColor {
        switch self {
        case .vocabulary: return Design.Color.accent
        case .weather: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.42, green: 0.77, blue: 0.87, alpha: 1) : UIColor(red: 0.12, green: 0.44, blue: 0.55, alpha: 1) }
        case .horoscope: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.63, blue: 0.86, alpha: 1) : UIColor(red: 0.48, green: 0.24, blue: 0.56, alpha: 1) }
        case .businessPhrase: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.88, green: 0.69, blue: 0.38, alpha: 1) : UIColor(red: 0.54, green: 0.35, blue: 0.07, alpha: 1) }
        }
    }

    /// Fill behind the symbol tile.
    var tintFill: UIColor { tint.withAlphaComponent(0.14) }
}

/// A rounded square that holds a kind's symbol. Decorative: the row it sits in carries the words.
final class MagazineSymbolTile: UIView {
    private let imageView = UIImageView()
    private let side: CGFloat

    init(side: CGFloat = 44) {
        self.side = side
        super.init(frame: .zero)
        layer.cornerRadius = side * 0.28
        layer.cornerCurve = .continuous
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: side * 0.42, weight: .semibold)
        addSubview(imageView)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side), heightAnchor.constraint(equalToConstant: side),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor), imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(symbol: String, tint: UIColor) {
        imageView.image = UIImage(systemName: symbol)
        imageView.tintColor = tint
        backgroundColor = tint.withAlphaComponent(0.14)
    }
}

extension UILabel {
    /// Japanese text is read with the Japanese voice even when the app speaks Vietnamese or English.
    func markJapanese() {
        accessibilityLanguage = "ja"
    }
}
