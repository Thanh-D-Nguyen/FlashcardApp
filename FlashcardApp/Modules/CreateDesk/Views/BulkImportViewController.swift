import UIKit

/// Paste a list of cards ("front | back | optional picture address", or tab-separated from a spreadsheet).
/// The website's composer accepts the same format.
final class BulkImportViewController: UIViewController, UITextViewDelegate {
    /// Returns the number of imported cards, or the reason the text was rejected.
    private let onImport: (String) -> Result<Int, BulkDeckImport.Failure>
    private let textView = PlaceholderTextView(role: .meaning)
    private let errorLabel = ErrorMessageLabel()
    private lazy var importItem = UIBarButtonItem(title: NSLocalizedString("Import", comment: ""), primaryAction: UIAction { [weak self] _ in self?.runImport() })

    init(onImport: @escaping (String) -> Result<Int, BulkDeckImport.Failure>) {
        self.onImport = onImport
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Import cards", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        importItem.style = .prominent
        importItem.isEnabled = false
        importItem.accessibilityIdentifier = "bulk_import_confirm"
        navigationItem.rightBarButtonItem = importItem

        let help = UILabel()
        help.apply(.reading)
        help.text = String.localizedStringWithFormat(
            NSLocalizedString("One card per line: front | back, or front, back and a picture address (https) separated by a tab or |. Up to %lld cards.", comment: "Bulk import help"),
            BulkDeckImport.maximumRows)
        // An example of the format itself, not interface copy, so it is not translated.
        textView.placeholder = "犬 | chó\n猫 | mèo | https://example.com/cat.jpg"
        textView.delegate = self
        textView.accessibilityIdentifier = "bulk_import_text"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true
        textView.backgroundColor = Design.Color.surface
        textView.layer.cornerRadius = Design.Spacing.m
        textView.layer.cornerCurve = .continuous
        textView.textContainerInset = UIEdgeInsets(top: Design.Spacing.m, left: Design.Spacing.m, bottom: Design.Spacing.m, right: Design.Spacing.m)
        let stack = UIStackView(arrangedSubviews: [help, textView, errorLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Design.Spacing.l),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    func textViewDidChange(_ textView: UITextView) {
        importItem.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        errorLabel.show(nil)
    }

    private func runImport() {
        switch onImport(textView.text) {
        case .success: dismiss(animated: true)
        case .failure(let failure): errorLabel.show(Self.message(for: failure))
        }
    }

    static func message(for failure: BulkDeckImport.Failure) -> String {
        switch failure {
        case .invalidLine(let line):
            return String(format: NSLocalizedString("Line %lld is not valid. Use: front | back", comment: ""), line)
        case .invalidImageUrl(let line):
            return String(format: NSLocalizedString("Line %lld has a picture address that is not https.", comment: ""), line)
        case .tooManyRows:
            return String.localizedStringWithFormat(NSLocalizedString("A deck can hold up to %lld cards.", comment: ""), DeckDraft.maximumCards)
        }
    }
}
