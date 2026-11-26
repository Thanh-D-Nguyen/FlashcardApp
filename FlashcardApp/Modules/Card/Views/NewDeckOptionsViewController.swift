import UIKit

/// How a new deck gets its cards.
enum NewDeckMethod: Equatable {
    case manual, automatic
}

/// Shared presentation flow for creating a new deck (sheet chooser, manual editor, or auto-generator).
/// Reused by `CardWireframe` and `TodayWireframe` so both entry points stay identical.
enum NewDeckFlow {
    static func presentOptions(from presenter: UIViewController, onChoose: @escaping (NewDeckMethod) -> Void) {
        let options = NewDeckOptionsViewController(onChoose: onChoose)
        options.modalPresentationStyle = .pageSheet
        if let sheet = options.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(options, animated: true)
    }

    static func presentEditor(from presenter: UIViewController, deckId: String?, onFinish: @escaping () -> Void) {
        let editor = CreateDeskWireframe(deckId: deckId, onFinish: onFinish)
        presenter.present(UINavigationController(rootViewController: editor.viewController), animated: true)
    }

    static func presentGenerator(from presenter: UIViewController, onImported: @escaping (String) -> Void) {
        let generator = DeckGeneratorWireframe(onImported: onImported)
        let navigation = UINavigationController(rootViewController: generator.viewController)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.large()]
        presenter.present(navigation, animated: true)
    }

    static func presentCompleteFlow(from presenter: UIViewController, onFinish: @escaping () -> Void) {
        presentOptions(from: presenter) { [weak presenter] method in
            guard let presenter else { return }
            switch method {
            case .manual:
                presentEditor(from: presenter, deckId: nil, onFinish: onFinish)
            case .automatic:
                presentGenerator(from: presenter) { [weak presenter] deckId in
                    onFinish()
                    guard let presenter else { return }
                    presentEditor(from: presenter, deckId: deckId, onFinish: onFinish)
                }
            }
        }
    }
}

/// The two ways to start a deck, side by side in a short sheet: type the cards yourself, or let the dictionary
/// fill a deck for a JLPT level. Each row says what it needs, so the choice is made before any screen is opened.
final class NewDeckOptionsViewController: UIViewController {
    private let onChoose: (NewDeckMethod) -> Void
    private var didChoose = false

    init(onChoose: @escaping (NewDeckMethod) -> Void) {
        self.onChoose = onChoose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Closes the sheet first, so whatever opens next is presented from the Cards screen rather than from this sheet.
    private func choose(_ method: NewDeckMethod) {
        // A second tap during the dismissal animation must not open a second screen.
        guard !didChoose else { return }
        didChoose = true
        dismiss(animated: true) { [onChoose] in onChoose(method) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        let title = UILabel()
        title.apply(.display)
        title.text = NSLocalizedString("New deck", comment: "")
        title.accessibilityTraits = .header

        let manual = OptionRow(symbol: "square.and.pencil",
                               title: NSLocalizedString("Create manually", comment: ""),
                               detail: NSLocalizedString("Type your own words, import a list or add pictures. Works offline.", comment: ""))
        manual.accessibilityIdentifier = "new_deck_manual"
        manual.addAction(UIAction { [weak self] _ in self?.choose(.manual) }, for: .touchUpInside)
        let automatic = OptionRow(symbol: "wand.and.sparkles",
                                  title: NSLocalizedString("Auto-generate", comment: ""),
                                  detail: NSLocalizedString("Pick a JLPT level and what to study. You can edit every card afterwards. Needs your account.", comment: ""))
        automatic.accessibilityIdentifier = "new_deck_auto"
        automatic.addAction(UIAction { [weak self] _ in self?.choose(.automatic) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, manual, automatic])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.l, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }
}

private final class OptionRow: UIControl {
    private let row = UIStackView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.forward"))

    init(symbol: String, title: String, detail: String) {
        super.init(frame: .zero)
        applyCardSurface(radius: Design.Radius.card)

        let tile = UIImageView(image: UIImage(systemName: symbol))
        tile.contentMode = .center
        tile.tintColor = Design.Color.accent
        tile.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        tile.backgroundColor = Design.Color.highlight
        tile.layer.cornerRadius = Design.Radius.chip
        tile.layer.cornerCurve = .continuous
        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.apply(.title)
        titleLabel.text = title
        let detailLabel = UILabel()
        detailLabel.apply(.metadata)
        detailLabel.textColor = Design.Color.textSecondary
        detailLabel.text = detail
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = Design.Spacing.xs

        chevron.tintColor = Design.Color.textSecondary
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        [tile, text, chevron].forEach(row.addArrangedSubview)
        row.spacing = Design.Spacing.m
        row.isUserInteractionEnabled = false
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.l, leading: Design.Spacing.l, bottom: Design.Spacing.l, trailing: Design.Spacing.l)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            tile.widthAnchor.constraint(equalToConstant: 48),
            tile.heightAnchor.constraint(equalToConstant: 48)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
        accessibilityHint = detail
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: OptionRow, _) in
            view.updateAxis()
        }
    }

    private func updateAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = isAX ? .vertical : .horizontal
        row.alignment = isAX ? .leading : .center
        chevron.isHidden = isAX
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}
