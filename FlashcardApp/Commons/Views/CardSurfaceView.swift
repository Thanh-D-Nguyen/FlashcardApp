import UIKit

/// The surface of a study card: fill (solid or gradient), corner radius, shadow and, for framed styles, an inner
/// content panel with a border. Draws the app's own adaptive card when there is no style. Shared by the study card and
/// the previews in the style picker so both show the same card. Never takes touches.
final class CardSurfaceView: UIView {
    /// Gap between the frame and the content panel of a framed style.
    private static let frameInset: CGFloat = 10

    private let clipView = UIView()
    private let panel = UIView()
    private var gradientLayer: CAGradientLayer?
    private(set) var style: CardStyle?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipView.layer.cornerCurve = .continuous
        clipView.layer.masksToBounds = true
        panel.layer.cornerCurve = .continuous
        clipView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clipView)
        clipView.addSubview(panel)
        NSLayoutConstraint.activate([
            clipView.topAnchor.constraint(equalTo: topAnchor), clipView.bottomAnchor.constraint(equalTo: bottomAnchor),
            clipView.leadingAnchor.constraint(equalTo: leadingAnchor), clipView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        apply(style: nil)
        // CGColor does not follow the appearance by itself.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CardSurfaceView, _) in view.apply(style: view.style) }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func apply(style: CardStyle?) {
        self.style = style
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
        let radius = style?.cornerRadius ?? Design.Radius.panel
        clipView.layer.cornerRadius = radius
        if let style {
            clipView.backgroundColor = style.backgroundColor
            if let gradient = style.makeGradientLayer() {
                clipView.layer.insertSublayer(gradient, at: 0)
                gradientLayer = gradient
            }
            if style.isFramed {
                panel.isHidden = false
                panel.backgroundColor = style.contentSurfaceColor
                panel.layer.borderColor = style.borderColor.withAlphaComponent(0.55).cgColor
                panel.layer.borderWidth = 1
                clipView.layer.borderWidth = 0
            } else {
                panel.isHidden = true
                clipView.layer.borderColor = style.borderColor.withAlphaComponent(0.55).cgColor
                clipView.layer.borderWidth = 1
            }
            layer.shadowColor = UIColor(hex: style.shadow.color).cgColor
            layer.shadowOpacity = style.shadow.opacity
            layer.shadowRadius = style.shadow.radius
            layer.shadowOffset = CGSize(width: 0, height: style.shadow.offsetY)
        } else {
            clipView.backgroundColor = Design.Color.surface
            clipView.layer.borderColor = Design.Color.separator.cgColor
            clipView.layer.borderWidth = 1
            panel.isHidden = true
            layer.shadowOpacity = 0
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = clipView.bounds
        let inset = style?.isFramed == true ? Self.frameInset : 0
        panel.frame = clipView.bounds.insetBy(dx: inset, dy: inset)
        panel.layer.cornerRadius = max((style?.cornerRadius ?? 0) - inset, 2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: clipView.layer.cornerRadius).cgPath
    }
}
