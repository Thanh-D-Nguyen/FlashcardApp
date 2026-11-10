import SafariServices
import UIKit

/// Loto: the next draw of Loto 6 and Loto 7 with the number sets the server prepared and why it chose them.
final class LotoViewController: BaseVC, LotoViewInterface {
    var presenter: LotoPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let stateView = StateView()
    private let refreshControl = UIRefreshControl()
    private var lastRendered: LotoViewState?
    private var lastAnimatedSlug: String?
    /// Where the lab's slider was left; it starts at the limit, as on the website.
    private var labRandomness = 1.0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    #if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // `-LotoScroll <points>` scrolls the screen once the numbers are shown, for screenshots of the lower sections.
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-LotoScroll"), index + 1 < arguments.count, let offset = Double(arguments[index + 1]) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.scrollView.setContentOffset(CGPoint(x: 0, y: min(offset, max(self.scrollView.contentSize.height - self.scrollView.bounds.height, 0))), animated: false)
        }
    }
    #endif

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "loto_screen"
        scrollView.refreshControl = refreshControl
        refreshControl.addAction(UIAction { [weak self] _ in self?.presenter.refresh() }, for: .valueChanged)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.s),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stateView.topAnchor.constraint(equalTo: view.topAnchor), stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor), stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func endRefreshing() { refreshControl.endRefreshing() }

    func render(_ state: LotoViewState) {
        defer { lastRendered = state }
        switch state.phase {
        case .loading:
            show(state: .loading(NSLocalizedString("Loading the numbers…", comment: "Loto loading")))
        case .failed(let message):
            show(state: .error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")))
        case .empty:
            show(state: .empty(title: NSLocalizedString("No numbers yet", comment: "Loto empty title"),
                               message: NSLocalizedString("The numbers for the next draw have not been published. Check again later.", comment: "Loto empty message")))
        case .ready:
            stateView.isHidden = true
            scrollView.isHidden = false
            guard let draw = state.draw else { return }
            // The countdown and the cards are rebuilt only when the draw changes; the same state again changes nothing.
            if lastRendered == state { return }
            rebuild(state: state, draw: draw)
        }
    }

    private func show(state: StateView.State) {
        scrollView.isHidden = true
        stateView.isHidden = false
        stateView.configure(state) { [weak self] in self?.presenter.retry() }
    }

    private func rebuild(state: LotoViewState, draw: LotoDraw) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if state.games.count > 1 {
            let control = UISegmentedControl(items: state.games.map(\.title))
            control.selectedSegmentIndex = state.games.firstIndex(of: draw.game) ?? 0
            control.accessibilityIdentifier = "loto_games"
            control.addAction(UIAction { [weak self, weak control] _ in
                guard let self, let control, state.games.indices.contains(control.selectedSegmentIndex) else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                self.presenter.select(state.games[control.selectedSegmentIndex])
            }, for: .valueChanged)
            stack.addArrangedSubview(control)
        }

        stack.addArrangedSubview(LotoHeroView(draw: draw))
        // The statement comes before the numbers: nobody reads a set without having seen it.
        stack.addArrangedSubview(LotoNoticeView(draw: draw))

        let lab = LotoLabView(game: draw.game, signals: draw.signals, randomness: labRandomness, presenter: presenter) { [weak self] numbers in self?.copyLab(numbers) }
        lab.onRandomnessChange = { [weak self] value in self?.labRandomness = value }
        stack.addArrangedSubview(lab)
        let chaos = LotoChaosPanelView(game: draw.game)
        lab.onResult = { [weak chaos] result in chaos?.show(result) }
        stack.addArrangedSubview(chaos)

        var cards: [LotoSetCardView] = []
        for set in draw.sets {
            let card = LotoSetCardView(set: set, draw: draw) { [weak self] set in self?.copy(set) }
            cards.append(card)
            stack.addArrangedSubview(card)
        }
        if !draw.signals.isEmpty { stack.addArrangedSubview(LotoSignalsView(signals: draw.signals, historyDraws: draw.historyDraws)) }
        if !draw.weights.isEmpty { stack.addArrangedSubview(LotoMethodView(weights: draw.weights)) }
        stack.addArrangedSubview(legend())
        if draw.officialURL != nil { stack.addArrangedSubview(officialButton()) }
        if let schedule = draw.schedule {
            let label = UILabel()
            label.apply(.metadata)
            label.textColor = Design.Color.textSecondary
            label.textAlignment = .center
            label.text = schedule
            stack.addArrangedSubview(label)
        }

        if lastAnimatedSlug != draw.slug {
            lastAnimatedSlug = draw.slug
            view.layoutIfNeeded()
            cards.forEach { $0.animateBalls() }
        }
    }

    private func legend() -> UIView {
        let panel = LotoPanel(spacing: Design.Spacing.s)
        let title = UILabel()
        title.apply(.title)
        title.text = NSLocalizedString("What the marks mean", comment: "Loto legend title")
        panel.content.addArrangedSubview(title)
        for tag in [LotoTag.hot, .overdue, .cold, .recent] {
            let image = UIImageView(image: UIImage(systemName: tag.symbol))
            image.tintColor = tag.ballColor
            image.setContentHuggingPriority(.required, for: .horizontal)
            image.widthAnchor.constraint(equalToConstant: 24).isActive = true
            image.contentMode = .scaleAspectFit
            let name = UILabel()
            name.apply(.metadata)
            name.text = "\(tag.title) — \(tag.explanation)"
            let row = UIStackView(arrangedSubviews: [image, name])
            row.spacing = Design.Spacing.m
            row.alignment = .firstBaseline
            row.isAccessibilityElement = true
            row.accessibilityLabel = name.text
            panel.content.addArrangedSubview(row)
        }
        return panel
    }

    private func officialButton() -> UIView {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = NSLocalizedString("Check the official result", comment: "Loto: open the operator's site")
        configuration.image = UIImage(systemName: "checkmark.seal")
        configuration.imagePadding = Design.Spacing.s
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "loto_official"
        button.addAction(UIAction { [weak self] _ in self?.presenter.openOfficialSite() }, for: .touchUpInside)
        return button
    }

    private func copy(_ set: LotoSet) {
        guard let text = presenter.copyText(for: set) else { return }
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Numbers copied", comment: "VoiceOver: copied"))
        showToast(NSLocalizedString("Numbers copied", comment: "Loto: confirmation after copy"))
    }

    private func copyLab(_ numbers: [Int]) {
        guard let text = presenter.labCopyText(for: numbers) else { return }
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Numbers copied", comment: "VoiceOver: copied"))
        showToast(NSLocalizedString("Numbers copied", comment: "Loto: confirmation after copy"))
    }

    private func showToast(_ text: String) {
        let label = PaddedToastLabel()
        label.text = text
        label.apply(.metadata)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        label.textAlignment = .center
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl)
        ])
        UIView.animate(withDuration: 0.2, delay: 1.4, options: [], animations: { label.alpha = 0 }, completion: { _ in label.removeFromSuperview() })
    }
}

private final class PaddedToastLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + Design.Spacing.xl, height: size.height + Design.Spacing.m)
    }
}
