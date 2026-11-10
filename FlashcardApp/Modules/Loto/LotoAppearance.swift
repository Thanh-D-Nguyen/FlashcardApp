import UIKit

/// How a number is marked. The tint is never the only sign: every tag also has a symbol and a word.
extension LotoTag {
    var title: String {
        switch self {
        case .hot: return NSLocalizedString("Frequent", comment: "Loto number tag")
        case .cold: return NSLocalizedString("Rare", comment: "Loto number tag")
        case .overdue: return NSLocalizedString("Overdue", comment: "Loto number tag")
        case .recent: return NSLocalizedString("Recent", comment: "Loto number tag")
        }
    }

    /// What the tag means, for the legend.
    var explanation: String {
        switch self {
        case .hot: return NSLocalizedString("Drawn often in the past", comment: "Loto tag meaning")
        case .cold: return NSLocalizedString("Drawn rarely in the past", comment: "Loto tag meaning")
        case .overdue: return NSLocalizedString("Not drawn for a while", comment: "Loto tag meaning")
        case .recent: return NSLocalizedString("Drawn in the latest draws", comment: "Loto tag meaning")
        }
    }

    var symbol: String {
        switch self {
        case .hot: return "flame.fill"
        case .cold: return "snowflake"
        case .overdue: return "hourglass"
        case .recent: return "arrow.counterclockwise"
        }
    }

    /// Ball colour. Deep enough for white digits (≥ 4.5:1).
    var ballColor: UIColor {
        switch self {
        case .hot: return LotoPalette.rgb(0xB83A1E)
        case .cold: return LotoPalette.rgb(0x16707F)
        case .overdue: return LotoPalette.rgb(0x35509B)
        case .recent: return LotoPalette.rgb(0x8F5A00)
        }
    }
}

enum LotoPalette {
    static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
    /// A number with no tag.
    static let plainBall = rgb(0x2E3340)
    /// Gold of the hero's accents on the indigo block.
    static let gold = rgb(0xF0C36A)
}

extension LotoSignals {
    /// The tag a number carries in the signals, when its own tags are missing.
    func tag(of number: Int) -> LotoTag? {
        if hot.contains(number) { return .hot }
        if overdue.contains(number) { return .overdue }
        if cold.contains(number) { return .cold }
        return nil
    }
}

extension LotoNumber {
    /// The tag that colours the ball: the first one the server lists, in the order that says most.
    var primaryTag: LotoTag? {
        [LotoTag.hot, .overdue, .cold, .recent].first { tags.contains($0) }
    }
}

/// A lottery ball: a round, lit surface with the number on it and, for a tagged number, a small symbol badge.
final class LotoBallView: UIView {
    let number: Int
    private let gradient = CAGradientLayer()
    private let label = UILabel()
    private let badge = UIImageView()
    private let badgeBackground = UIView()
    private let diameter: CGFloat
    private let isBonus: Bool
    private let base: UIColor

    init(number: Int, tag: LotoTag?, isBonus: Bool = false, diameter: CGFloat = 44) {
        self.number = number
        self.diameter = diameter
        self.isBonus = isBonus
        self.base = tag?.ballColor ?? LotoPalette.plainBall
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        layer.cornerRadius = diameter / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        gradient.type = .radial
        gradient.startPoint = CGPoint(x: 0.32, y: 0.28)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.colors = [Self.lighten(base).cgColor, base.cgColor]
        gradient.cornerRadius = diameter / 2
        layer.addSublayer(gradient)
        if isBonus {
            // The bonus number is drawn as a ring: it is a different kind of number, not a different colour of the same one.
            gradient.isHidden = true
            layer.borderWidth = 2.5
            layer.borderColor = base.cgColor
            layer.shadowOpacity = 0
        }

        label.text = String(number)
        label.font = .systemFont(ofSize: diameter * 0.42, weight: .heavy).withRoundedDesign()
        label.textColor = isBonus ? .label : .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.frame = bounds.insetBy(dx: 2, dy: 2)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)

        if let tag {
            let side = max(16, diameter * 0.38)
            badgeBackground.backgroundColor = .systemBackground
            badgeBackground.layer.cornerRadius = side / 2
            badgeBackground.frame = CGRect(x: diameter - side * 0.8, y: diameter - side * 0.8, width: side, height: side)
            badge.image = UIImage(systemName: tag.symbol)
            badge.tintColor = tag.ballColor
            badge.contentMode = .scaleAspectFit
            badge.frame = badgeBackground.bounds.insetBy(dx: side * 0.2, dy: side * 0.2)
            badgeBackground.addSubview(badge)
            addSubview(badgeBackground)
        }
        isAccessibilityElement = true
        let numberText = String(format: NSLocalizedString("Number %d", comment: "VoiceOver: a lottery number"), number)
        accessibilityLabel = [numberText, isBonus ? NSLocalizedString("bonus", comment: "VoiceOver: bonus number") : nil, tag?.title]
            .compactMap { $0 }.joined(separator: ", ")
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: diameter, height: diameter) }

    override func sizeThatFits(_ size: CGSize) -> CGSize { intrinsicContentSize }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    /// A short pop-in, played once when the numbers appear. Not played under Reduce Motion.
    func popIn(delay: TimeInterval) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        alpha = 0
        UIView.animate(withDuration: 0.45, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.allowUserInteraction]) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    private static func lighten(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + 0.28, 1), green: min(g + 0.28, 1), blue: min(b + 0.28, 1), alpha: 1)
    }
}

private extension UIFont {
    func withRoundedDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

/// Views of a fixed size laid out left to right and wrapped to the next row when they do not fit.
final class LotoFlowView: UIView {
    var spacing: CGFloat = Design.Spacing.s { didSet { setNeedsLayout() } }

    init(views: [UIView]) {
        super.init(frame: .zero)
        views.forEach(addSubview)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func arrange(width: CGFloat, apply: Bool) -> CGSize {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            if apply { view.frame = CGRect(origin: CGPoint(x: x, y: y), size: size) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    private var fittedHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = arrange(width: bounds.width, apply: true)
        if abs(size.height - fittedHeight) > 0.5 { fittedHeight = size.height; invalidateIntrinsicContentSize() }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize { arrange(width: size.width, apply: false) }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: fittedHeight) }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        CGSize(width: targetSize.width, height: arrange(width: targetSize.width, apply: false).height)
    }
}
