import UIKit

/// Pushed detail screen for a BJT level vocabulary, kanji, or grammar entry.
/// Displays all content from the level DTO and links directly to the full `DictionaryEntry` screen when available.
final class LevelEntryDetailViewController: BaseViewController, LevelEntryDetailViewInterface {
    var presenter: LevelEntryDetailPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let toast = NoticeToastView()
    private var currentState: LevelEntryDetailState?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = makeMoreMenu()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "level_entry_detail"

        stack.axis = .vertical
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xxl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: LevelEntryDetailViewController, _) in
            if let state = controller.currentState { controller.render(state) }
        }
    }

    private func makeMoreMenu() -> UIBarButtonItem {
        let copyAction = UIAction(title: NSLocalizedString("Copy", comment: ""), image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            self?.presenter.copySummary()
        }
        let shareAction = UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.presenter.share()
        }
        let item = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [copyAction, shareAction]))
        item.accessibilityLabel = NSLocalizedString("More", comment: "")
        item.accessibilityIdentifier = "level_entry_more"
        return item
    }

    // MARK: LevelEntryDetailViewInterface

    func render(_ state: LevelEntryDetailState) {
        currentState = state
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stack.addArrangedSubview(makeHeaderCard(state))

        if state.onyomi != nil || state.kunyomi != nil {
            stack.addArrangedSubview(makeKanjiReadingsCard(onyomi: state.onyomi, kunyomi: state.kunyomi))
        }

        if let sectionTitle = state.detailSectionTitle, !state.detailItems.isEmpty {
            stack.addArrangedSubview(makeDetailsCard(title: sectionTitle, items: state.detailItems))
        }

        if !state.hasBodyContent {
            stack.addArrangedSubview(makeEmptyCard())
        }

        if state.canOpenDictionary || state.lessonsButtonTitle != nil {
            stack.addArrangedSubview(makeActionsStack(state))
        }
    }

    func showToast(_ message: String) {
        toast.show(message, in: view)
    }

    func showVoiceUnavailable() {
        let alert = UIAlertController(
            title: NSLocalizedString("No Japanese voice on this device", comment: ""),
            message: NSLocalizedString("Download a Japanese voice in Settings ▸ Accessibility ▸ Read & Speak ▸ Voices.", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: ""), style: .default) { [weak self] _ in
            self?.presenter.openSystemSettings()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: Sections

    private func makeHeaderCard(_ state: LevelEntryDetailState) -> UIView {
        let card = UIView()
        card.applyCardSurface(radius: Design.Radius.card)

        let eyebrow = UILabel()
        eyebrow.apply(.eyebrow)
        eyebrow.textColor = Design.Color.accent
        eyebrow.text = state.eyebrow
        eyebrow.accessibilityIdentifier = "level_entry_eyebrow"

        let headword = UILabel()
        headword.apply(state.isKanjiGlyph ? .kanjiGlyph : .entryHeadword)
        headword.text = state.title
        headword.textAlignment = state.isKanjiGlyph ? .center : .natural
        headword.accessibilityTraits = .header
        headword.accessibilityLanguage = "ja"
        headword.accessibilityIdentifier = "level_entry_title"

        let content = UIStackView(arrangedSubviews: [eyebrow, headword])
        content.axis = .vertical
        content.spacing = Design.Spacing.s
        content.translatesAutoresizingMaskIntoConstraints = false

        if let reading = state.reading {
            let readingLabel = UILabel()
            readingLabel.apply(.reading)
            readingLabel.text = reading
            readingLabel.accessibilityLanguage = "ja"
            readingLabel.accessibilityIdentifier = "level_entry_reading"
            content.addArrangedSubview(readingLabel)
        }

        if let shortMeaning = state.shortMeaning {
            let meaningLabel = UILabel()
            meaningLabel.apply(.answer)
            meaningLabel.font = meaningLabel.font.withWeight(.medium)
            meaningLabel.text = shortMeaning
            meaningLabel.textAlignment = state.isKanjiGlyph ? .center : .natural
            meaningLabel.accessibilityIdentifier = "level_entry_meaning"
            content.addArrangedSubview(meaningLabel)
            content.setCustomSpacing(Design.Spacing.m, after: state.reading == nil ? headword : content.arrangedSubviews[content.arrangedSubviews.count - 2])
        }

        if state.canSpeak {
            let listen = UIButton(type: .system)
            listen.configuration = Design.Button.surfaceChip(
                title: NSLocalizedString("Listen", comment: ""),
                systemImage: "speaker.wave.2",
                traits: traitCollection
            )
            listen.enableAdaptiveCornerStyle()
            listen.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            listen.accessibilityIdentifier = "level_entry_listen"
            listen.addAction(UIAction { [weak self] _ in self?.presenter.speak() }, for: .primaryActionTriggered)

            let row = UIStackView(arrangedSubviews: [listen, UIView()])
            row.axis = .horizontal
            row.alignment = .center
            content.addArrangedSubview(row)
            content.setCustomSpacing(Design.Spacing.l, after: content.arrangedSubviews[content.arrangedSubviews.count - 2])
        }

        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: Design.Spacing.xl),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Design.Spacing.xl),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return card
    }

    private func makeKanjiReadingsCard(onyomi: String?, kunyomi: String?) -> UIView {
        let card = UIView()
        card.applyCardSurface(radius: Design.Radius.card)

        let heading = UILabel()
        heading.apply(.sectionTitle)
        heading.text = NSLocalizedString("Readings", comment: "Section title")
        heading.accessibilityTraits = .header

        let content = UIStackView(arrangedSubviews: [heading])
        content.axis = .vertical
        content.spacing = Design.Spacing.m
        content.translatesAutoresizingMaskIntoConstraints = false

        func addReading(title: String, value: String, identifier: String) {
            let label = UILabel()
            label.apply(.metadata)
            label.font = Design.TextRole.weighted(.footnote, weight: .semibold)
            label.text = title
            let valueLabel = UILabel()
            valueLabel.apply(.headword)
            valueLabel.text = value
            valueLabel.accessibilityLanguage = "ja"
            valueLabel.accessibilityIdentifier = identifier
            let group = UIStackView(arrangedSubviews: [label, valueLabel])
            group.axis = .vertical
            group.spacing = Design.Spacing.xs
            content.addArrangedSubview(group)
        }

        if let onyomi {
            addReading(title: NSLocalizedString("On’yomi (Chinese reading)", comment: ""), value: onyomi, identifier: "level_entry_onyomi")
        }
        if let kunyomi {
            addReading(title: NSLocalizedString("Kun’yomi (Japanese reading)", comment: ""), value: kunyomi, identifier: "level_entry_kunyomi")
        }

        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return card
    }

    private func makeDetailsCard(title: String, items: [String]) -> UIView {
        let card = UIView()
        card.applyCardSurface(radius: Design.Radius.card)

        let heading = UILabel()
        heading.apply(.sectionTitle)
        heading.text = title
        heading.accessibilityTraits = .header

        let content = UIStackView(arrangedSubviews: [heading])
        content.axis = .vertical
        content.spacing = Design.Spacing.m
        content.translatesAutoresizingMaskIntoConstraints = false

        for (index, item) in items.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = Design.Color.separator
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                content.addArrangedSubview(divider)
            }
            let body = UILabel()
            body.apply(.explanation)
            body.text = items.count > 1 ? "\(index + 1). \(item)" : item
            body.accessibilityIdentifier = "level_entry_explanation_\(index)"
            content.addArrangedSubview(body)
        }

        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return card
    }

    private func makeEmptyCard() -> UIView {
        let card = UIView()
        card.applyCardSurface(radius: Design.Radius.card)
        let empty = StateView()
        empty.configure(.empty(title: NSLocalizedString("No meaning available yet.", comment: ""), message: nil))
        empty.translatesAutoresizingMaskIntoConstraints = false
        empty.accessibilityIdentifier = "level_entry_empty"
        card.addSubview(empty)
        NSLayoutConstraint.activate([
            empty.topAnchor.constraint(equalTo: card.topAnchor, constant: Design.Spacing.m),
            empty.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Design.Spacing.m),
            empty.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            empty.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
        return card
    }

    private func makeActionsStack(_ state: LevelEntryDetailState) -> UIView {
        let actions = UIStackView()
        actions.axis = .vertical
        actions.spacing = Design.Spacing.m

        if state.canOpenDictionary {
            let button = UIButton(type: .system)
            button.configuration = Design.Button.primary(
                title: NSLocalizedString("Open full dictionary entry", comment: "Level entry detail: push DictionaryEntry"),
                systemImage: "book.pages",
                traits: traitCollection
            )
            button.enableAdaptiveCornerStyle()
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            button.accessibilityIdentifier = "level_entry_open_dictionary"
            button.addAction(UIAction { [weak self] _ in self?.presenter.openDictionaryEntry() }, for: .primaryActionTriggered)
            actions.addArrangedSubview(button)
        }

        if let lessonsTitle = state.lessonsButtonTitle {
            let button = UIButton(type: .system)
            button.configuration = Design.Button.secondary(
                title: lessonsTitle,
                systemImage: "list.bullet.rectangle",
                traits: traitCollection
            )
            button.enableAdaptiveCornerStyle()
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            button.accessibilityIdentifier = "level_entry_open_lessons"
            button.addAction(UIAction { [weak self] _ in self?.presenter.openLessons() }, for: .primaryActionTriggered)
            actions.addArrangedSubview(button)
        }

        return actions
    }
}
