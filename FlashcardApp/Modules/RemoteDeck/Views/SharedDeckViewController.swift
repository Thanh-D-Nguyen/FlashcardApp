import UIKit

/// The public preview of a shared deck and its one action.
final class SharedDeckViewController: BaseViewController, SharedDeckViewInterface {
    var presenter: SharedDeckPresenterInterface!

    private let scrollView = UIScrollView()
    private let stateView = StateView()
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let samplesCard = UIView()
    private let samplesLabel = UILabel()
    private let noticeLabel = UILabel()
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = NSLocalizedString("Shared deck", comment: "Title of the preview of a deck shared by link")

        titleLabel.apply(.headword)
        titleLabel.accessibilityIdentifier = "shared_deck_title"
        detailsLabel.apply(.metadata)
        samplesLabel.apply(.meaning)
        samplesLabel.accessibilityIdentifier = "shared_deck_samples"

        samplesCard.applyCardSurface(radius: Design.Radius.card)
        samplesLabel.translatesAutoresizingMaskIntoConstraints = false
        samplesCard.addSubview(samplesLabel)
        NSLayoutConstraint.activate([
            samplesLabel.topAnchor.constraint(equalTo: samplesCard.topAnchor, constant: Design.Spacing.l),
            samplesLabel.bottomAnchor.constraint(equalTo: samplesCard.bottomAnchor, constant: -Design.Spacing.l),
            samplesLabel.leadingAnchor.constraint(equalTo: samplesCard.leadingAnchor, constant: Design.Spacing.l),
            samplesLabel.trailingAnchor.constraint(equalTo: samplesCard.trailingAnchor, constant: -Design.Spacing.l)
        ])

        noticeLabel.apply(.metadata)
        noticeLabel.accessibilityIdentifier = "shared_deck_notice"

        saveButton.configuration = Design.Button.primary(title: "", traits: traitCollection)
        saveButton.enableAdaptiveCornerStyle()
        saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        saveButton.accessibilityIdentifier = "shared_deck_save"
        saveButton.addAction(UIAction { [weak self] _ in self?.presenter.save() }, for: .touchUpInside)

        [titleLabel, detailsLabel, samplesCard, noticeLabel, saveButton].forEach(stack.addArrangedSubview)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.l, after: samplesCard)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(scrollView)
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func render(_ state: SharedDeckState) {
        switch state.phase {
        case .loading:
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")))
        case .loaded:
            stateView.isHidden = true
            scrollView.isHidden = false
            titleLabel.text = state.title
            detailsLabel.text = state.details
            detailsLabel.isHidden = state.details.isEmpty
            samplesLabel.text = state.samples.joined(separator: "\n")
            samplesCard.isHidden = state.samples.isEmpty
        case .gone:
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.empty(title: NSLocalizedString("This link no longer works", comment: "Shared deck: revoked or unknown link"),
                                       message: NSLocalizedString("The owner may have stopped sharing the deck.", comment: "")))
        case .failed(let message):
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in
                self?.presenter.retry()
            }
        }
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        var config = Design.Button.primary(title: state.saveTitle, traits: traitCollection)
        config.showsActivityIndicator = state.isSaving
        saveButton.configuration = config
        saveButton.isHidden = state.phase != .loaded
        saveButton.isEnabled = state.canSave
    }
}
