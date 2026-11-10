import UIKit

/// A short confirmation near the bottom of the screen ("Copied", "Saved to My words"). It never blocks touches, goes away on
/// its own, and is announced to VoiceOver because a sighted-only toast would hide the result of an action from those users.
final class NoticeToastView: UIView {
    private let label = UILabel()
    private var hideWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = Design.Color.hero
        layer.cornerCurve = .continuous
        label.apply(.metadata)
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = Design.Color.onHero
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])
        alpha = 0
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.height / 2, 22)
    }

    /// Shows `text` in the lower part of `host`, above its safe area.
    func show(_ text: String, in host: UIView, duration: TimeInterval = 3.5) {
        hideWork?.cancel()
        label.text = text
        if superview !== host {
            translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(self)
            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: host.centerXAnchor),
                bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
                leadingAnchor.constraint(greaterThanOrEqualTo: host.layoutMarginsGuide.leadingAnchor),
                trailingAnchor.constraint(lessThanOrEqualTo: host.layoutMarginsGuide.trailingAnchor)
            ])
        }
        host.bringSubviewToFront(self)
        UIAccessibility.post(notification: .announcement, argument: text)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduceMotion ? 0 : 0.18) { self.alpha = 1 }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: reduceMotion ? 0 : 0.25) { self?.alpha = 0 }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}
