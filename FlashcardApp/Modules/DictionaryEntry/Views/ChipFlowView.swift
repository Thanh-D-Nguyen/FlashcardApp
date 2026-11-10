import UIKit

/// Lays its subviews out left to right and wraps them onto new lines at the width it is given. Every subview must have a
/// fitting size (a label, a button). The height follows the width: the view keeps its own height constraint up to date.
final class ChipFlowView: UIView {
    var spacing: CGFloat = Design.Spacing.s
    private var heightConstraint: NSLayoutConstraint!
    private var laidOutWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .required - 1
        heightConstraint.isActive = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setChips(_ chips: [UIView]) {
        subviews.forEach { $0.removeFromSuperview() }
        chips.forEach(addSubview)
        laidOutWidth = 0
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = arrange(width: bounds.width, apply: true)
        if abs(heightConstraint.constant - height) > 0.5 { heightConstraint.constant = height }
        laidOutWidth = bounds.width
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontal: UILayoutPriority,
                                          verticalFittingPriority vertical: UILayoutPriority) -> CGSize {
        CGSize(width: targetSize.width, height: arrange(width: targetSize.width, apply: false))
    }

    /// Returns the height needed at `width`; moves the subviews only when `apply` is set.
    @discardableResult
    private func arrange(width: CGFloat, apply: Bool) -> CGFloat {
        guard width > 0 else { return 0 }
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for chip in subviews {
            var size = chip.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                    withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)
            size.width = min(size.width, width)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            if apply { chip.frame = CGRect(origin: CGPoint(x: x, y: y), size: size) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return y + rowHeight
    }
}
