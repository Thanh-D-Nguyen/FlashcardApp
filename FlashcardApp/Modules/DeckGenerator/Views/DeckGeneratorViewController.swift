import UIKit

/// Auto-generate: choose a JLPT level, what to study and how many cards; see how many are available; create the
/// deck. The summary and the bottom button always say what will happen next, so the screen has one clear path.
final class DeckGeneratorViewController: BaseViewController, DeckGeneratorViewInterface {
    var presenter: DeckGeneratorPresenterInterface!

    private let scroll = UIScrollView()
    private let content = UIStackView()
    private let levelControl = UISegmentedControl(items: GenerationLevel.allCases.map(\.title))
    private var contentButtons: [GenerationContentType: UIButton] = [:]
    private let directionButton = UIButton(configuration: .plain())
    private let directionNote = UILabel()
    private let countSlider = UISlider()
    private let countLabel = UILabel()
    private let nameField = UITextField()
    private let summary = UIStackView()
    private let summarySpinner = UIActivityIndicatorView(style: .medium)
    private let summaryIcon = UIImageView()
    private let summaryTitle = UILabel()
    private let summaryDetail = UILabel()
    private let summaryAction = UIButton(configuration: .plain())
    private var summaryHandler: (() -> Void)?
    private let noticeLabel = ErrorMessageLabel()
    private let footnote = UILabel()
    private let generateButton = UIButton(configuration: Design.Button.primary(title: ""))
    private let bottomBar = UIView()

    private lazy var closeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        item.accessibilityIdentifier = "close_generator"
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func subscribe() {}

    // MARK: Layout

    func setupUI() {
        title = NSLocalizedString("Auto-generate", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = closeItem

        content.axis = .vertical
        content.spacing = Design.Spacing.xl
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        scroll.alwaysBounceVertical = true
        scroll.addSubview(content)

        let intro = UILabel()
        intro.apply(.reading)
        intro.textColor = Design.Color.textSecondary
        intro.text = NSLocalizedString("Pick what to study. The cards come from the dictionary and stay editable.", comment: "")

        levelControl.addAction(UIAction { [weak self] _ in
            guard let self, let level = GenerationLevel.allCases[safe: self.levelControl.selectedSegmentIndex] else { return }
            self.presenter.setLevel(level)
        }, for: .valueChanged)
        levelControl.accessibilityIdentifier = "generator_level"

        let contentRow = UIStackView()
        contentRow.spacing = Design.Spacing.s
        contentRow.distribution = .fillProportionally
        for type in GenerationContentType.allCases {
            let button = UIButton(configuration: .tinted())
            button.changesSelectionAsPrimaryAction = false
            button.accessibilityIdentifier = "generator_type_\(type.rawValue)"
            button.addAction(UIAction { [weak self] _ in self?.presenter.toggle(type) }, for: .primaryActionTriggered)
            button.configurationUpdateHandler = { button in
                var configuration: UIButton.Configuration = button.isSelected ? .filled() : .tinted()
                configuration.title = type.title
                configuration.cornerStyle = .capsule
                configuration.buttonSize = .medium
                configuration.image = button.isSelected ? UIImage(systemName: "checkmark") : nil
                configuration.imagePadding = Design.Spacing.xs
                button.configuration = configuration
            }
            button.accessibilityTraits = .button
            contentButtons[type] = button
            contentRow.addArrangedSubview(button)
        }

        directionButton.showsMenuAsPrimaryAction = true
        directionButton.contentHorizontalAlignment = .leading
        directionButton.accessibilityIdentifier = "generator_direction"
        directionNote.apply(.metadata)
        directionNote.textColor = Design.Color.textSecondary
        let directionStack = UIStackView(arrangedSubviews: [directionButton, directionNote])
        directionStack.axis = .vertical
        directionStack.alignment = .leading

        countSlider.minimumValue = Float(DeckGenerationRequest.countRange.lowerBound)
        countSlider.maximumValue = Float(DeckGenerationRequest.countRange.upperBound)
        countSlider.accessibilityIdentifier = "generator_count"
        countSlider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter.setCount(Int(self.countSlider.value.rounded()))
        }, for: .valueChanged)
        countLabel.apply(.figure)
        countLabel.textAlignment = .right
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        let countRow = UIStackView(arrangedSubviews: [countSlider, countLabel])
        countRow.spacing = Design.Spacing.m
        countRow.alignment = .center

        nameField.placeholder = NSLocalizedString("Deck name", comment: "")
        nameField.borderStyle = .none
        nameField.backgroundColor = Design.Color.surface
        nameField.layer.cornerRadius = Design.Spacing.m
        nameField.layer.cornerCurve = .continuous
        nameField.font = Design.TextRole.meaning.font
        nameField.adjustsFontForContentSizeCategory = true
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.autocorrectionType = .no
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Design.Spacing.l, height: 1))
        nameField.leftViewMode = .always
        nameField.accessibilityIdentifier = "generator_name"
        nameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        nameField.delegate = self
        nameField.addAction(UIAction { [weak self] _ in self?.presenter.setName(self?.nameField.text ?? "") }, for: .editingChanged)

        buildSummary()

        [intro,
         group(NSLocalizedString("JLPT level", comment: "Generator section"), levelControl),
         group(NSLocalizedString("What to study", comment: "Generator section"), contentRow),
         group(NSLocalizedString("Card direction", comment: ""), directionStack),
         group(NSLocalizedString("Number of cards", comment: "Generator section"), countRow),
         summary,
         group(NSLocalizedString("Deck name", comment: ""), nameField),
         footnote].forEach(content.addArrangedSubview)

        noticeLabel.accessibilityIdentifier = "generator_notice"
        footnote.apply(.metadata)
        footnote.textColor = Design.Color.textSecondary
        footnote.text = NSLocalizedString("The deck is also created in your account on the website. It is saved on this device; changes you make here are not synced back.", comment: "")
        generateButton.accessibilityIdentifier = "generate_deck"
        generateButton.addAction(UIAction { [weak self] _ in
            self?.view.endEditing(true)
            self?.presenter.generate()
        }, for: .primaryActionTriggered)

        let bar = UIStackView(arrangedSubviews: [noticeLabel, generateButton])
        bar.axis = .vertical
        bar.spacing = Design.Spacing.s
        bar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = Design.Color.background
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(bar)
        let hairline = UIView()
        hairline.backgroundColor = Design.Color.separator
        hairline.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(hairline)

        view.addSubview(scroll)
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            hairline.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            hairline.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)),
            bar.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: Design.Spacing.m),
            bar.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: Design.Spacing.gutter),
            bar.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -Design.Spacing.gutter),
            bar.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.s)
        ])
    }

    private func group(_ title: String, _ control: UIView) -> UIView {
        let label = UILabel()
        label.apply(.eyebrow)
        label.text = title.uppercased(with: AppLanguage.current.locale)
        label.accessibilityTraits = .header
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        return stack
    }

    private func buildSummary() {
        summarySpinner.hidesWhenStopped = true
        summaryIcon.contentMode = .scaleAspectFit
        summaryIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        summaryIcon.setContentHuggingPriority(.required, for: .horizontal)
        summaryTitle.apply(.title)
        summaryDetail.apply(.metadata)
        summaryDetail.textColor = Design.Color.textSecondary
        let text = UIStackView(arrangedSubviews: [summaryTitle, summaryDetail, summaryAction])
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = Design.Spacing.xs
        let leading = UIStackView(arrangedSubviews: [summaryIcon, summarySpinner])
        leading.alignment = .top
        summary.axis = .horizontal
        summary.alignment = .top
        summary.spacing = Design.Spacing.m
        summary.isLayoutMarginsRelativeArrangement = true
        summary.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
        summary.backgroundColor = Design.Color.surface
        summary.layer.cornerRadius = Design.Spacing.l
        summary.layer.cornerCurve = .continuous
        [leading, text].forEach(summary.addArrangedSubview)
        summary.accessibilityIdentifier = "generator_summary"
        summaryAction.accessibilityIdentifier = "generator_summary_action"
        summaryAction.addAction(UIAction { [weak self] _ in self?.summaryHandler?() }, for: .primaryActionTriggered)
    }

    // MARK: DeckGeneratorViewInterface

    func render(_ state: DeckGeneratorState) {
        let request = state.request
        levelControl.selectedSegmentIndex = GenerationLevel.allCases.firstIndex(of: request.level) ?? 0
        for (type, button) in contentButtons {
            button.isSelected = request.contentTypes.contains(type)
            button.accessibilityValue = button.isSelected ? NSLocalizedString("Selected", comment: "") : nil
        }
        renderDirection(request.direction)
        countSlider.value = Float(request.count)
        countLabel.text = String(format: NSLocalizedString("%lld cards", comment: ""), locale: AppLanguage.current.locale, request.count)
        countSlider.accessibilityValue = countLabel.text
        if nameField.text != request.name, !nameField.isFirstResponder { nameField.text = request.name }
        renderSummary(state)

        let busy = state.isBusy
        [levelControl, countSlider, nameField, directionButton].forEach { $0.isEnabled = !busy }
        contentButtons.values.forEach { $0.isEnabled = !busy }
        closeItem.isEnabled = !busy
        isModalInPresentation = busy
        navigationController?.isModalInPresentation = busy
        noticeLabel.show(state.notice)

        var configuration = Design.Button.primary(title: Self.primaryTitle(for: state))
        configuration.showsActivityIndicator = busy
        generateButton.configuration = configuration
        generateButton.isEnabled = state.canGenerate
    }

    static func primaryTitle(for state: DeckGeneratorState) -> String {
        switch state.phase {
        case .generating: return NSLocalizedString("Creating your deck…", comment: "")
        case .downloading: return NSLocalizedString("Downloading the cards…", comment: "")
        case .editing:
            if state.pendingDownload != nil { return NSLocalizedString("Download the cards", comment: "") }
            return NSLocalizedString("Generate deck", comment: "")
        }
    }

    private func renderDirection(_ direction: GenerationDirection) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = direction.title
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.xs, leading: 0, bottom: Design.Spacing.xs, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.TextRole.meaning.font
            return attributes
        }
        directionButton.configuration = configuration
        directionButton.menu = UIMenu(options: .singleSelection, children: GenerationDirection.allCases.map { option in
            UIAction(title: option.title, state: option == direction ? .on : .off) { [weak self] _ in self?.presenter.setDirection(option) }
        })
        directionButton.accessibilityLabel = String(format: NSLocalizedString("Card direction: %@", comment: ""), direction.title)
        directionNote.text = direction == .both
            ? NSLocalizedString("Cards alternate between the two directions, one word per card.", comment: "") : nil
        directionNote.isHidden = direction != .both
    }

    private func renderSummary(_ state: DeckGeneratorState) {
        summarySpinner.stopAnimating()
        summaryIcon.isHidden = false
        summaryAction.isHidden = true
        summaryDetail.isHidden = false
        let locale = AppLanguage.current.locale
        switch state.preview {
        case .loading:
            summaryIcon.isHidden = true
            summarySpinner.startAnimating()
            summaryTitle.text = NSLocalizedString("Counting cards…", comment: "")
            summaryDetail.isHidden = true
        case .ready(let available):
            if available < DeckGeneratorState.minimumUsableCards {
                setSummaryIcon("exclamationmark.circle", tint: Design.Color.warning)
                summaryTitle.text = NSLocalizedString("Not enough cards for these choices", comment: "")
                summaryDetail.text = NSLocalizedString("Choose another level or add more kinds of content.", comment: "")
            } else {
                setSummaryIcon("checkmark.circle.fill", tint: Design.Color.success)
                let expected = state.expectedCount ?? 0
                summaryTitle.text = String(format: NSLocalizedString("Your deck will have %lld cards", comment: ""), locale: locale, expected)
                summaryDetail.text = available < state.request.count
                    ? String(format: NSLocalizedString("Only %lld cards match these choices.", comment: ""), locale: locale, available)
                    : String(format: NSLocalizedString("%lld cards match these choices.", comment: ""), locale: locale, available)
            }
        case .signInRequired:
            setSummaryIcon("person.crop.circle", tint: Design.Color.accent)
            summaryTitle.text = NSLocalizedString("Sign in to generate a deck", comment: "")
            summaryDetail.text = NSLocalizedString("Generated decks come from your account. Creating decks by hand works without one.", comment: "")
            showSummaryAction(NSLocalizedString("Sign In", comment: "")) { [weak self] in self?.presenter.signIn() }
        case .failed(let message):
            setSummaryIcon("exclamationmark.triangle", tint: Design.Color.error)
            summaryTitle.text = NSLocalizedString("Couldn't count the cards", comment: "")
            summaryDetail.text = message
            showSummaryAction(NSLocalizedString("Try again", comment: "")) { [weak self] in self?.presenter.retryPreview() }
        }
        summary.accessibilityLabel = [summaryTitle.text, summaryDetail.isHidden ? nil : summaryDetail.text].compactMap { $0 }.joined(separator: ". ")
    }

    private func setSummaryIcon(_ symbol: String, tint: UIColor) {
        summaryIcon.image = UIImage(systemName: symbol)
        summaryIcon.tintColor = tint
    }

    private func showSummaryAction(_ title: String, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .small
        summaryAction.configuration = configuration
        summaryHandler = action
        summaryAction.isHidden = false
    }
}

extension DeckGeneratorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
