import RxSwift
import UIKit

/// One screen for the four kinds of entry. It draws `DictionaryEntryState` and forwards every tap to the presenter; the
/// content of each kind is assembled in the `+Vocabulary`, `+Kanji`, `+Grammar` and `+Sentence` files.
final class DictionaryEntryViewController: BaseVC, UITextViewDelegate {
    var presenter: DictionaryEntryPresenterInterface!

    let scroll = UIScrollView()
    let stack = UIStackView()
    private let toast = NoticeToastView()
    private var renderedState: DictionaryEntryState?
    /// Kept across renders so a stroke animation is not restarted every time something else on the screen changes.
    var strokeView: StrokeOrderView?
    var strokeKanjiID: String?
    var strokeControls: StrokeControls?
    var expandedExplanation = false
    var expandedWords = false

    var current: DictionaryEntryState { presenter.state.value }
    var useVerticalActions: Bool { traitCollection.preferredContentSizeCategory.isAccessibilityCategory }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.contentInsetAdjustmentBehavior = .automatic
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Design.Spacing.xxl),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Design.Spacing.gutter),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * Design.Spacing.gutter)
        ])
        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
        presenter.notices.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.show($0) }).disposed(by: disposeBag)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: DictionaryEntryViewController, _) in
            controller.rebuild()
        }
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
    }

    #if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // `-EntryScrollTo <points>`: scroll once the content has loaded, so lower sections can be screenshotted.
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-EntryScrollTo"), index + 1 < arguments.count, let offset = Double(arguments[index + 1]) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        }
    }
    #endif

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        strokeView?.pause()
    }

    // MARK: Rendering

    func rebuild() { render(current, force: true) }

    private func render(_ state: DictionaryEntryState, force: Bool = false) {
        guard force || state != renderedState else { return }
        renderedState = state
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        navigationItem.rightBarButtonItem = moreButton(for: state)
        // The stroke canvas is kept alive, so it is detached by the removal above and added back where it belongs.
        for view in contents(for: state) { stack.addArrangedSubview(view) }
        accessibilityIdentifierForScreen(state)
    }

    private func accessibilityIdentifierForScreen(_ state: DictionaryEntryState) {
        view.accessibilityIdentifier = "entry_\(state.item.kind.rawValue)"
    }

    private func contents(for state: DictionaryEntryState) -> [UIView] {
        switch state.detail {
        case .idle, .loading:
            return placeholderHeader(for: state.item) + [loadingRow()]
        case .failed(let message):
            return placeholderHeader(for: state.item) + [errorBlock(message: message, retry: { [weak self] in self?.presenter.retry() })]
        case .loaded(let detail):
            switch detail {
            case .vocabulary(let vocabulary): return vocabularyContents(vocabulary, state: state)
            case .kanji(let kanji): return kanjiContents(kanji, state: state)
            case .grammar(let grammar): return grammarContents(grammar, state: state)
            case .sentence(let sentence): return sentenceContents(sentence, state: state)
            }
        }
    }

    /// The little the search row already told us, shown at once while the detail loads.
    private func placeholderHeader(for item: DictionaryItem) -> [UIView] {
        var views: [UIView] = []
        if let reading = item.reading, item.kind != .sentence {
            views.append(label(.reading, reading))
        }
        let title = label(item.kind == .kanji ? .kanjiGlyph : (item.kind == .sentence ? .sentence : .entryHeadword), item.title)
        title.accessibilityIdentifier = "entry_title"
        title.accessibilityTraits = .header
        views.append(title)
        if let meaning = item.meaning, item.kind != .sentence { views.append(label(.meaning, meaning)) }
        return views
    }

    // MARK: Building blocks

    func label(_ role: Design.TextRole, _ text: String?, color: UIColor? = nil) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = text
        if let color { label.textColor = color }
        return label
    }

    func spaced(_ view: UIView, before: CGFloat) -> UIView {
        let wrapper = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: before),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])
        return wrapper
    }

    func section(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil, actionIdentifier: String? = nil,
                 _ body: [UIView]) -> [UIView] {
        let heading = spaced(SectionTitleView(title: title, actionTitle: actionTitle, action: action, actionIdentifier: actionIdentifier),
                             before: Design.Spacing.xxl)
        let content = UIStackView(arrangedSubviews: body)
        content.axis = .vertical
        content.spacing = Design.Spacing.s
        return [heading, spaced(content, before: Design.Spacing.s)]
    }

    func loadingRow() -> UIView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.accessibilityLabel = NSLocalizedString("Loading…", comment: "")
        let holder = UIView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.topAnchor.constraint(equalTo: holder.topAnchor, constant: Design.Spacing.xl),
            spinner.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -Design.Spacing.xl),
            spinner.centerXAnchor.constraint(equalTo: holder.centerXAnchor)
        ])
        return holder
    }

    func errorBlock(message: String, retry: @escaping () -> Void, identifier: String = "entry_retry") -> UIView {
        let text = label(.reading, message, color: Design.Color.error)
        let button = UIButton(type: .system)
        button.configuration = Design.Button.secondary(title: NSLocalizedString("Try again", comment: ""), traits: traitCollection)
        button.enableAdaptiveCornerStyle()
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.addAction(UIAction { _ in retry() }, for: .touchUpInside)
        button.accessibilityIdentifier = identifier
        let box = UIStackView(arrangedSubviews: [text, button])
        box.axis = .vertical
        box.alignment = .leading
        box.spacing = Design.Spacing.m
        return spaced(box, before: Design.Spacing.xl)
    }

    func quietNote(_ text: String) -> UIView {
        label(.reading, text)
    }

    func separatedRows(_ rows: [UIView]) -> [UIView] {
        rows.enumerated().flatMap { index, row -> [UIView] in index == 0 ? [row] : [HairlineView(), row] }
    }

    // MARK: Actions

    /// Speak / save / add to flashcards, as equal buttons that stack vertically at accessibility text sizes.
    func actionRow(speak: String?, state: DictionaryEntryState) -> UIView {
        var buttons: [UIButton] = []
        if let speak {
            buttons.append(actionButton(title: NSLocalizedString("Listen", comment: "Speak the word aloud"), symbol: "speaker.wave.2",
                                        identifier: "entry_speak") { [weak self] in self?.presenter.speak(speak) })
        }
        if state.favorite != .unavailable {
            let on = state.favorite.isOn
            let button = actionButton(title: on ? NSLocalizedString("Saved", comment: "") : NSLocalizedString("Save", comment: "Bookmark the entry"),
                                      symbol: on ? "bookmark.fill" : "bookmark", identifier: "entry_favorite") { [weak self] in self?.presenter.toggleFavorite() }
            if case .updating = state.favorite { button.configuration?.showsActivityIndicator = true; button.isEnabled = false }
            if state.favorite == .checking { button.isEnabled = false }
            if state.favorite == .unknown { button.accessibilityHint = NSLocalizedString("Couldn’t check whether this is saved. Tap to check again.", comment: "") }
            button.accessibilityTraits = on ? [.button, .selected] : .button
            if state.favorite == .signedOut { button.accessibilityHint = NSLocalizedString("Sign in to save entries to your account.", comment: "") }
            buttons.append(button)
        }
        buttons.append(actionButton(title: NSLocalizedString("Add to flashcards", comment: ""), symbol: "rectangle.stack.badge.plus",
                                    identifier: "entry_add_deck") { [weak self] in self?.presenter.addToDeck() })
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = useVerticalActions ? .vertical : .horizontal
        row.distribution = .fillEqually
        row.spacing = Design.Spacing.s
        return spaced(row, before: Design.Spacing.l)
    }

    private func actionButton(title: String, symbol: String, identifier: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePlacement = useVerticalActions ? .leading : .top
        configuration.imagePadding = Design.Spacing.xs + 2
        configuration.cornerStyle = .large
        configuration.background.cornerRadius = Design.Radius.control
        configuration.background.strokeColor = Design.Color.border
        configuration.background.strokeWidth = 1
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.accent
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.s, bottom: Design.Spacing.m, trailing: Design.Spacing.s)
        configuration.titleAlignment = .center
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.TextRole.weighted(.footnote, weight: .semibold)
            return attributes
        }
        button.configuration = configuration
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.accessibilityIdentifier = identifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        return button
    }

    private func moreButton(for state: DictionaryEntryState) -> UIBarButtonItem? {
        guard case .loaded(let detail) = state.detail else { return nil }
        var copies: [UIAction] = []
        func add(_ title: String, _ text: String?, what: String) {
            guard let text, !text.isEmpty else { return }
            copies.append(UIAction(title: title, image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in self?.presenter.copy(text, what: what) })
        }
        let item = detail.item
        switch detail {
        case .vocabulary(let vocabulary):
            add(NSLocalizedString("Copy word", comment: ""), vocabulary.headword, what: NSLocalizedString("Word", comment: ""))
            add(NSLocalizedString("Copy reading", comment: ""), vocabulary.reading, what: NSLocalizedString("Reading", comment: ""))
            add(NSLocalizedString("Copy meaning", comment: ""), vocabulary.meanings.map(\.text).joined(separator: "; "), what: NSLocalizedString("Meaning", comment: ""))
        case .kanji(let kanji):
            add(NSLocalizedString("Copy kanji", comment: ""), kanji.character, what: NSLocalizedString("Kanji", comment: ""))
            add(NSLocalizedString("Copy meaning", comment: ""), kanji.meaning, what: NSLocalizedString("Meaning", comment: ""))
        case .grammar(let grammar):
            add(NSLocalizedString("Copy pattern", comment: ""), grammar.pattern, what: NSLocalizedString("Pattern", comment: ""))
            add(NSLocalizedString("Copy meaning", comment: ""), grammar.meaning, what: NSLocalizedString("Meaning", comment: ""))
        case .sentence(let sentence):
            add(NSLocalizedString("Copy sentence", comment: ""), sentence.japanese, what: NSLocalizedString("Sentence", comment: ""))
            add(NSLocalizedString("Copy reading", comment: ""), sentence.reading, what: NSLocalizedString("Reading", comment: ""))
            add(NSLocalizedString("Copy translation", comment: ""), sentence.translation, what: NSLocalizedString("Translation", comment: ""))
        }
        add(NSLocalizedString("Copy all", comment: ""), item.summary, what: NSLocalizedString("Entry", comment: ""))
        let share = UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.presenter.share(item.summary)
        }
        let button = UIBarButtonItem(title: NSLocalizedString("More", comment: ""), image: UIImage(systemName: "ellipsis"),
                                     menu: UIMenu(children: [UIMenu(options: .displayInline, children: copies), share]))
        button.accessibilityIdentifier = "entry_more"
        return button
    }

    // MARK: Feedback

    private func show(_ notice: EntryNotice) {
        switch notice {
        case .voiceUnavailable:
            let alert = UIAlertController(title: NSLocalizedString("No Japanese voice on this device", comment: ""),
                                          message: NSLocalizedString("Download a Japanese voice in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices.", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: ""), style: .default) { [weak self] _ in self?.presenter.openVoiceSettings() })
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
            present(alert, animated: true)
            return
        case .failure(let message):
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast.show(message, in: view, duration: 3.6)
        case .copied(let what):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toast.show(String(format: NSLocalizedString("%@ copied", comment: "Toast; %@ is what was copied, e.g. Word"), what), in: view)
        case .savedToDeck(let name):
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toast.show(String(format: NSLocalizedString("Added to “%@”", comment: "Toast; %@ is a deck name"), name), in: view)
        case .alreadyInDeck(let name):
            toast.show(String(format: NSLocalizedString("Already in “%@”", comment: "Toast; %@ is a deck name"), name), in: view)
        case .nothingToSave:
            toast.show(NSLocalizedString("This entry has no meaning to put on a card.", comment: ""), in: view)
        case .favoriteAdded:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toast.show(NSLocalizedString("Saved to your account", comment: ""), in: view)
        case .favoriteRemoved:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toast.show(NSLocalizedString("Removed from saved", comment: ""), in: view)
        case .notFound(let text):
            toast.show(String(format: NSLocalizedString("No dictionary entry for “%@”", comment: ""), text), in: view)
        }
    }

    // MARK: Selected text

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard range.length > 0, let swiftRange = Range(range, in: textView.text) else { return UIMenu(children: suggestedActions) }
        let selected = String(textView.text[swiftRange])
        let lookUp = UIAction(title: NSLocalizedString("Look up in dictionary", comment: ""), image: UIImage(systemName: "character.book.closed.ja")) { [weak self] _ in
            self?.presenter.lookUp(selected)
        }
        return UIMenu(children: [lookUp] + suggestedActions)
    }
}

/// The buttons under the stroke canvas, kept so they can be refreshed while the canvas animates.
struct StrokeControls {
    let play: UIButton
    let back: UIButton
    let forward: UIButton
    let replay: UIButton
    let progress: UILabel
}
