import UIKit

/// Draws a word's pitch accent: its morae in a row and a line that sits high or low over each one, with a short tail for the
/// particle that follows. The line is the whole message, so it keeps the accent colour; the kana stay in the text colour.
final class PitchAccentView: UIView {
    private let pattern: PitchPattern
    private let line = CAShapeLayer()
    private let labels: [UILabel]
    private let lowY: CGFloat = 26
    private let highY: CGFloat = 6
    /// One mora's width follows the text size, so large type never makes neighbouring kana overlap.
    private var cell: CGFloat { max(30, (labels.first?.font.pointSize ?? 20) * 1.3) }
    private let tail: CGFloat = 14

    init(pattern: PitchPattern) {
        self.pattern = pattern
        labels = pattern.morae.map { mora in
            let label = UILabel()
            label.text = mora
            label.textAlignment = .center
            label.isAccessibilityElement = false
            return label
        }
        super.init(frame: .zero)
        line.fillColor = nil
        line.lineWidth = 2
        line.lineCap = .round
        line.lineJoin = .round
        layer.addSublayer(line)
        labels.forEach(addSubview)
        applyColors()
        applyFonts()
        isAccessibilityElement = true
        accessibilityLabel = Self.description(of: pattern)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitUserInterfaceStyle.self]) { (view: PitchAccentView, _) in
            view.applyFonts()
            view.applyColors()
            view.invalidateIntrinsicContentSize()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyColors() {
        line.strokeColor = Design.Color.accent.resolvedColor(with: traitCollection).cgColor
        labels.forEach { $0.textColor = Design.Color.textPrimary }
    }

    private func applyFonts() {
        let font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .regular))
        labels.forEach { $0.font = font }
    }

    override var intrinsicContentSize: CGSize {
        let labelHeight = labels.first?.font.lineHeight ?? 24
        return CGSize(width: CGFloat(pattern.morae.count) * cell + tail, height: lowY + 6 + labelHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let labelTop = lowY + 6
        for (index, label) in labels.enumerated() {
            label.frame = CGRect(x: CGFloat(index) * cell, y: labelTop, width: cell, height: label.font.lineHeight)
        }
        func y(_ level: PitchPattern.Level) -> CGFloat { level == .high ? highY : lowY }
        let path = UIBezierPath()
        for (index, level) in pattern.levels.enumerated() {
            let point = CGPoint(x: (CGFloat(index) + 0.5) * cell, y: y(level))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if let particle = pattern.particle {
            path.addLine(to: CGPoint(x: CGFloat(pattern.morae.count) * cell + tail * 0.6, y: y(particle)))
        }
        line.path = path.cgPath
        line.frame = bounds
    }

    private static func description(of pattern: PitchPattern) -> String {
        let word = pattern.text
        let kind: String
        switch pattern.kind {
        case .heiban: kind = NSLocalizedString("Heiban: flat, never drops", comment: "Pitch accent type")
        case .atamadaka: kind = NSLocalizedString("Atamadaka: drops after the first mora", comment: "Pitch accent type")
        case .nakadaka: kind = NSLocalizedString("Nakadaka: drops inside the word", comment: "Pitch accent type")
        case .odaka: kind = NSLocalizedString("Odaka: drops on the particle after the word", comment: "Pitch accent type")
        }
        return String(format: NSLocalizedString("Pitch accent of %1$@: %2$@ [%3$lld]", comment: "VoiceOver for the pitch accent drawing"), word, kind, pattern.number)
    }

    /// "[2] Nakadaka" — the name next to the drawing.
    static func caption(for pattern: PitchPattern) -> String {
        let name: String
        switch pattern.kind {
        case .heiban: name = NSLocalizedString("Heiban (flat)", comment: "Pitch accent type")
        case .atamadaka: name = NSLocalizedString("Atamadaka (head-high)", comment: "Pitch accent type")
        case .nakadaka: name = NSLocalizedString("Nakadaka (middle-high)", comment: "Pitch accent type")
        case .odaka: name = NSLocalizedString("Odaka (tail-high)", comment: "Pitch accent type")
        }
        return "[\(pattern.number)] \(name)"
    }
}
