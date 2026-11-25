import UIKit

/// Hands the downloaded export to the system share sheet (save to Files, AirDrop, mail).
final class DataExportWireframe: DataExportWireframeInterface {
    weak var viewController: UIViewController?

    func share(file: URL) {
        guard let viewController else { return }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = viewController.view
        viewController.present(sheet, animated: true)
    }
}

/// "Get a copy of your data": what the server knows about the learner's export request and the one thing to do next.
final class DataExportViewController: BaseViewController, DataExportViewInterface {
    var presenter: DataExportPresenterInterface!

    private let scrollView = UIScrollView()
    private let stateView = StateView()
    private let cardView = UIView()
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let noticeLabel = UILabel()
    private let button = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    static func make() -> DataExportViewController {
        let controller = DataExportViewController()
        controller.hidesBottomBarWhenPushed = true
        let wireframe = DataExportWireframe()
        wireframe.viewController = controller
        let presenter = DataExportPresenter(wireframe: wireframe)
        presenter.view = controller
        controller.presenter = presenter
        controller.retainedWireframe = wireframe
        return controller
    }

    /// The wireframe holds the controller weakly; the controller keeps it alive.
    private var retainedWireframe: DataExportWireframe?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = NSLocalizedString("Your data", comment: "Settings section about the account's data")

        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.weighted(.title3, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityIdentifier = "data_export_title"
        messageLabel.apply(.meaning)
        messageLabel.numberOfLines = 0
        messageLabel.accessibilityIdentifier = "data_export_message"
        noticeLabel.apply(.metadata)
        noticeLabel.numberOfLines = 0
        noticeLabel.accessibilityIdentifier = "data_export_notice"

        cardView.applyCardSurface(radius: Design.Radius.card)
        let cardStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, noticeLabel])
        cardStack.axis = .vertical
        cardStack.spacing = Design.Spacing.s
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Design.Spacing.l),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Design.Spacing.l),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Design.Spacing.l),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Design.Spacing.l)
        ])

        button.configuration = Design.Button.primary(title: "", traits: traitCollection)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        button.enableAdaptiveCornerStyle()
        button.accessibilityIdentifier = "data_export_action"
        // In the failed state the button reads the list again instead of performing an action.
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.failed ? self.presenter.retry() : self.presenter.performAction()
        }, for: .touchUpInside)
        spinner.hidesWhenStopped = true

        [cardView, button, spinner].forEach(stack.addArrangedSubview)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.l
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(scrollView)
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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

    func render(_ state: DataExportState) {
        failed = state.phase == .failed
        if state.phase == .loading {
            scrollView.isHidden = true
            stateView.isHidden = false
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")))
            spinner.stopAnimating()
            return
        }
        stateView.isHidden = true
        scrollView.isHidden = false
        titleLabel.text = state.title
        messageLabel.text = state.message
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        let title = state.phase == .failed ? NSLocalizedString("Try again", comment: "") : state.actionTitle
        button.configuration?.title = title
        button.isHidden = title == nil
        button.isEnabled = !state.isWorking
        state.isWorking ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private var failed = false
}
