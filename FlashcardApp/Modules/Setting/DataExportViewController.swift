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

    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let noticeLabel = UILabel()
    private let button = UIButton(configuration: .borderedProminent())
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
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "data_export_title"
        messageLabel.apply(.meaning)
        messageLabel.numberOfLines = 0
        messageLabel.accessibilityIdentifier = "data_export_message"
        noticeLabel.apply(.metadata)
        noticeLabel.numberOfLines = 0
        noticeLabel.accessibilityIdentifier = "data_export_notice"
        button.accessibilityIdentifier = "data_export_action"
        // In the failed state the button reads the list again instead of performing an action.
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.failed ? self.presenter.retry() : self.presenter.performAction()
        }, for: .touchUpInside)
        spinner.hidesWhenStopped = true

        [titleLabel, messageLabel, noticeLabel, button, spinner].forEach(stack.addArrangedSubview)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    func render(_ state: DataExportState) {
        switch state.phase {
        case .loading:
            titleLabel.text = nil
            messageLabel.text = nil
        case .loaded, .failed:
            titleLabel.text = state.title
            messageLabel.text = state.message
        }
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        let title = state.phase == .failed ? NSLocalizedString("Try again", comment: "") : state.actionTitle
        button.configuration?.title = title
        button.isHidden = title == nil
        button.isEnabled = !state.isWorking
        failed = state.phase == .failed
        state.isWorking ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private var failed = false
}
