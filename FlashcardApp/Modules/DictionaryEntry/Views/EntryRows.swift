import UIKit

/// A tappable row of an entry: a lead line, optional second and third lines, and a trailing accessory (a speaker button or a
/// chevron). Used for example sentences and for the words listed under a kanji. The whole row is one VoiceOver element that
/// opens the target; the speaker is its own button.
final class EntryRowControl: UIControl {
    /// Long-press actions of the row (copy, share…). `nil` or an empty menu disables the long press.
    var menuProvider: (() -> UIMenu?)?

    private let stack = UIStackView()
    private let lead = UILabel()
    private let second = UILabel()
    private let third = UILabel()
    private let accessory = UIButton(type: .system)
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var onSpeak: (() -> Void)?
    private var stackToAccessory: NSLayoutConstraint!
    private var stackToChevron: NSLayoutConstraint!
    private var stackToEdge: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        [lead, second, third].forEach { stack.addArrangedSubview($0) }
        accessory.translatesAutoresizingMaskIntoConstraints = false
        accessory.addAction(UIAction { [weak self] _ in self?.onSpeak?() }, for: .touchUpInside)
        chevron.tintColor = Design.Color.textSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(stack)
        addSubview(accessory)
        addSubview(chevron)
        stackToAccessory = stack.trailingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: -Design.Spacing.s)
        stackToChevron = stack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -Design.Spacing.s)
        stackToEdge = stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessory.trailingAnchor.constraint(equalTo: trailingAnchor),
            accessory.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xs),
            accessory.widthAnchor.constraint(equalToConstant: 44),
            accessory.heightAnchor.constraint(equalToConstant: 44),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackToEdge
        ])
        let minimum = heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        minimum.priority = .defaultHigh
        minimum.isActive = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        isContextMenuInteractionEnabled = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let menu = menuProvider?() else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1 }
    }

    /// `speak` shows a speaker button that does not open the row; without it the row ends in a chevron.
    func configure(lead leadText: NSAttributedString, second secondText: NSAttributedString?, third thirdText: NSAttributedString?,
                   accessibilityLabel label: String, opens: Bool = true, speak: (() -> Void)? = nil, speakLabel: String? = nil,
                   onOpen: @escaping () -> Void) {
        lead.attributedText = leadText
        lead.numberOfLines = 0
        second.attributedText = secondText
        second.numberOfLines = 0
        second.isHidden = secondText == nil
        third.attributedText = thirdText
        third.numberOfLines = 0
        third.isHidden = thirdText == nil
        onSpeak = speak
        accessory.isHidden = speak == nil
        if speak != nil {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: "speaker.wave.2")
            configuration.baseForegroundColor = Design.Color.accent
            accessory.configuration = configuration
            accessory.accessibilityLabel = speakLabel
        }
        chevron.isHidden = speak != nil || !opens
        stackToAccessory.isActive = speak != nil
        stackToChevron.isActive = speak == nil && opens
        stackToEdge.isActive = speak == nil && !opens
        accessibilityLabel = label
        removeTarget(nil, action: nil, for: .touchUpInside)
        addAction(UIAction { _ in onOpen() }, for: .touchUpInside)
        // The speaker is a separate button, so it must stay reachable for VoiceOver next to the row.
        accessibilityElements = nil
        if speak != nil {
            isAccessibilityElement = false
            accessibilityElements = [RowAccessibilityElement(row: self, label: label, onOpen: onOpen), accessory]
        } else {
            isAccessibilityElement = true
        }
    }
}

/// VoiceOver element for the text part of a row whose speaker button is a sibling element.
private final class RowAccessibilityElement: UIAccessibilityElement {
    private let onOpen: () -> Void
    private weak var row: UIView?

    init(row: UIView, label: String, onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        self.row = row
        super.init(accessibilityContainer: row)
        accessibilityLabel = label
        accessibilityTraits = .button
    }

    override var accessibilityFrameInContainerSpace: CGRect {
        get { row.map { CGRect(x: 0, y: 0, width: max(0, $0.bounds.width - 44), height: $0.bounds.height) } ?? .zero }
        set {}
    }

    override func accessibilityActivate() -> Bool {
        onOpen()
        return true
    }
}

/// The title of a section of an entry, optionally with one trailing action ("Hide readings").
final class SectionTitleView: UIView {
    private let row = UIStackView()
    private var spacer: UIView?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil, actionIdentifier: String? = nil) {
        super.init(frame: .zero)
        let label = UILabel()
        label.apply(.sectionTitle)
        label.text = title
        label.accessibilityTraits = .header
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(label)
        row.alignment = .center
        row.spacing = Design.Spacing.s
        if let actionTitle, let action {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = actionTitle
            configuration.baseForegroundColor = Design.Color.accent
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.s, bottom: Design.Spacing.m, trailing: 0)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.preferredFont(forTextStyle: .subheadline)
                return attributes
            }
            button.configuration = configuration
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            button.accessibilityIdentifier = actionIdentifier
            let gap = UIView()
            gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer = gap
            row.addArrangedSubview(gap)
            row.addArrangedSubview(button)
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: SectionTitleView, _) in
            view.updateAxis()
        }
    }

    private func updateAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = isAX ? .vertical : .horizontal
        row.alignment = isAX ? .leading : .center
        spacer?.isHidden = isAX
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// A hairline between rows, inset like the rest of the content.
final class HairlineView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.separator
        isAccessibilityElement = false
        let height = heightAnchor.constraint(equalToConstant: 0.5)
        height.isActive = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
