import UIKit

/// The public preview of a shared deck and its one action.
final class SharedDeckViewController: BaseViewController, SharedDeckViewInterface {
    var presenter: SharedDeckPresenterInterface!

    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let samplesLabel = UILabel()
    private let noticeLabel = UILabel()
    private let saveButton = UIButton(configuration: .borderedProminent())
    private let retryButton = UIButton(configuration: .bordered())
    private let spinner = UIActivityIndicatorView(style: .medium)

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
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "shared_deck_title"
        detailsLabel.apply(.metadata)
        samplesLabel.apply(.meaning)
        samplesLabel.numberOfLines = 0
        samplesLabel.accessibilityIdentifier = "shared_deck_samples"
        noticeLabel.apply(.metadata)
        noticeLabel.numberOfLines = 0
        noticeLabel.accessibilityIdentifier = "shared_deck_notice"
        saveButton.accessibilityIdentifier = "shared_deck_save"
        saveButton.addAction(UIAction { [weak self] _ in self?.presenter.save() }, for: .touchUpInside)
        retryButton.configuration?.title = NSLocalizedString("Try again", comment: "")
        retryButton.addAction(UIAction { [weak self] _ in self?.presenter.retry() }, for: .touchUpInside)
        spinner.hidesWhenStopped = true
        [titleLabel, detailsLabel, samplesLabel, noticeLabel, saveButton, retryButton, spinner].forEach(stack.addArrangedSubview)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    func render(_ state: SharedDeckState) {
        retryButton.isHidden = true
        switch state.phase {
        case .loading:
            titleLabel.text = nil
            detailsLabel.text = nil
            samplesLabel.text = nil
            spinner.startAnimating()
        case .loaded:
            spinner.stopAnimating()
            titleLabel.text = state.title
            detailsLabel.text = state.details
            samplesLabel.text = state.samples.joined(separator: "\n")
        case .gone:
            spinner.stopAnimating()
            titleLabel.text = NSLocalizedString("This link no longer works", comment: "Shared deck: revoked or unknown link")
            detailsLabel.text = NSLocalizedString("The owner may have stopped sharing the deck.", comment: "")
            samplesLabel.text = nil
        case .failed(let message):
            spinner.stopAnimating()
            titleLabel.text = message
            detailsLabel.text = nil
            samplesLabel.text = nil
            retryButton.isHidden = false
        }
        state.isSaving ? spinner.startAnimating() : (state.phase == .loading ? () : spinner.stopAnimating())
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        saveButton.configuration?.title = state.saveTitle
        saveButton.isHidden = state.phase != .loaded
        saveButton.isEnabled = state.canSave
    }
}
