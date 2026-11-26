import UIKit

/// One Daily Radar card, read in the app: its visual header, title and summary, Japanese expressions with Listen & Save to deck actions,
/// usage note, and a Study now deep-link button when the card maps to an existing screen.
final class DailyRadarCardViewController: BaseViewController {
    private let item: DailyRadarItem
    private let speech: SpeechServiceInterface
    private let wordSaver: LessonWordSaverInterface
    private let onDeepLink: ((DailyRadarDeepLink) -> Void)?
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let toast = NoticeToastView()

    init(item: DailyRadarItem,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         wordSaver: LessonWordSaverInterface = LessonWordSaver(),
         onDeepLink: ((DailyRadarDeepLink) -> Void)? = nil) {
        self.item = item
        self.speech = speech
        self.wordSaver = wordSaver
        self.onDeepLink = onDeepLink
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        speech.stop()
    }

    func subscribe() {}

    private func label(_ text: String, style: Design.TextRole, color: UIColor? = nil, identifier: String? = nil) -> UILabel {
        let label = UILabel()
        label.apply(style)
        label.numberOfLines = 0
        label.text = text
        if let color { label.textColor = color }
        label.accessibilityIdentifier = identifier
        return label
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = item.moduleTitle.isEmpty ? NSLocalizedString("Daily Radar", comment: "Title of a Daily Radar card screen") : item.moduleTitle
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.accessibilityIdentifier = "radar_card_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])

        let visual = item.visualScene()
        let sceneBanner = LifeSceneView()
        sceneBanner.configure(scene: visual.scene, topic: visual.topic)
        sceneBanner.layer.cornerRadius = Design.Radius.card
        sceneBanner.layer.cornerCurve = .continuous
        sceneBanner.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(sceneBanner)

        let heading = label(item.title, style: .headword, identifier: "radar_card_title")
        heading.font = Design.TextRole.weighted(.title2, weight: .semibold)
        heading.accessibilityTraits = .header
        stack.addArrangedSubview(heading)
        let meta = [item.level, item.minutes.map { String.localizedStringWithFormat(NSLocalizedString("%lld minutes", comment: ""), $0) }]
            .compactMap { $0 }.joined(separator: " · ")
        if !meta.isEmpty { stack.addArrangedSubview(label(meta, style: .metadata)) }
        if let summary = item.summary { stack.addArrangedSubview(label(summary, style: .meaning)) }

        stack.addArrangedSubview(label(NSLocalizedString("JAPANESE TO USE", comment: "Daily Radar card: heading of its Japanese expressions"),
                                       style: .eyebrow, color: Design.Color.accent))
        for (index, expression) in item.expressions.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = Design.Spacing.xs
            column.addArrangedSubview(label(expression.japanese, style: .headword, identifier: "radar_expression_\(index)"))
            if let reading = expression.reading, reading != expression.japanese { column.addArrangedSubview(label(reading, style: .reading)) }
            if let meaning = expression.meaning { column.addArrangedSubview(label(meaning, style: .meaning)) }
            if let example = expression.example {
                column.addArrangedSubview(label(example, style: .meaning))
                if let exampleMeaning = expression.exampleMeaning { column.addArrangedSubview(label(exampleMeaning, style: .metadata)) }
            }

            let listenButton = UIButton(configuration: Design.Button.surfaceChip(
                title: NSLocalizedString("Listen", comment: ""),
                systemImage: "speaker.wave.2.fill",
                traits: traitCollection
            ))
            listenButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            listenButton.enableAdaptiveCornerStyle()
            listenButton.addAction(UIAction { [weak self] _ in
                self?.speech.speak(expression.japanese, languageCode: "ja-JP")
            }, for: .primaryActionTriggered)

            let saveButton = UIButton(configuration: Design.Button.surfaceChip(
                title: NSLocalizedString("Save to deck", comment: ""),
                systemImage: "plus.rectangle.on.folder",
                traits: traitCollection
            ))
            saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            saveButton.enableAdaptiveCornerStyle()
            saveButton.addAction(UIAction { [weak self] _ in
                self?.promptSave(expression)
            }, for: .primaryActionTriggered)

            let actionRow = UIStackView(arrangedSubviews: [listenButton, saveButton])
            actionRow.spacing = Design.Spacing.s
            actionRow.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
            actionRow.distribution = actionRow.axis == .vertical ? .fill : .fillEqually
            column.addArrangedSubview(actionRow)
            column.setCustomSpacing(Design.Spacing.m, after: column.arrangedSubviews[column.arrangedSubviews.count - 2])

            stack.addArrangedSubview(wrapCard(column))
        }
        if let note = item.usageNote {
            stack.addArrangedSubview(label(NSLocalizedString("HOW IT IS USED", comment: "Daily Radar card: heading of its usage note"),
                                           style: .eyebrow, color: Design.Color.accent))
            stack.addArrangedSubview(wrapCard(label(note, style: .meaning)))
        }
        if let reason = item.reason { stack.addArrangedSubview(label(reason, style: .metadata)) }
        if let destination = item.deepLink, let onDeepLink {
            let studyNow = UIButton(configuration: Design.Button.primary(
                title: NSLocalizedString("Study now", comment: ""),
                systemImage: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? nil : "arrow.right",
                traits: traitCollection
            ))
            studyNow.configuration?.imagePlacement = .trailing
            studyNow.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            studyNow.enableAdaptiveCornerStyle()
            studyNow.accessibilityIdentifier = "radar_card_study_now"
            studyNow.addAction(UIAction { _ in onDeepLink(destination) }, for: .primaryActionTriggered)
            stack.addArrangedSubview(studyNow)
        }
    }

    private func promptSave(_ expression: BJTRadarCardDTO.Expression) {
        let choices = wordSaver.choices()
        let sheet = UIAlertController(title: NSLocalizedString("Save words to", comment: "Deck chooser title"), message: nil, preferredStyle: .actionSheet)
        let hasDefaultDeck = choices.contains { $0.id == LessonWordSaver.lessonDeckID }
        if !hasDefaultDeck {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("Saved from lessons", comment: ""), style: .default) { [weak self] _ in
                self?.save(expression, to: .newDictionaryDeck)
            })
        }
        for choice in choices {
            let cards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), choice.cardCount)
            sheet.addAction(UIAlertAction(title: "\(choice.name) · \(cards)", style: .default) { [weak self] _ in
                self?.save(expression, to: .existing(deckID: choice.id))
            })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if traitCollection.userInterfaceIdiom == .pad {
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(sheet, animated: true)
    }

    private func save(_ expression: BJTRadarCardDTO.Expression, to target: DictionaryDeckTarget) {
        let meaning = expression.meaning ?? item.summary ?? item.title
        let word = LessonWord(japanese: expression.japanese, reading: expression.reading ?? "", meaning: meaning)
        do {
            let outcome = try wordSaver.save([word], fromLesson: "radar-\(item.slug)", to: target)
            if outcome.added > 0 {
                toast.show(String.localizedStringWithFormat(NSLocalizedString("Saved %lld new words to “%@”.", comment: ""), outcome.added, outcome.deckName), in: view)
            } else {
                toast.show(String(format: NSLocalizedString("Already in “%@”. Nothing was added twice.", comment: ""), outcome.deckName), in: view)
            }
        } catch {
            toast.show(NSLocalizedString("Couldn't save the words", comment: ""), in: view)
        }
    }

    private func wrapCard(_ content: UIView) -> UIView {
        let container = UIView()
        container.applyCardSurface(radius: Design.Radius.card)
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return container
    }
}
