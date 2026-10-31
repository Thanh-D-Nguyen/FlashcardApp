import Kingfisher
import UIKit

/// Shows a card's picture from its stored reference (`CardImageReference`): a local file or a remote https URL.
/// Has explicit loading and failure states, cancels in-flight work when reused, and never shows a stale
/// picture after the reference changes.
final class CardImageView: UIView {
    enum State: Equatable {
        case empty, loading, loaded, failed
    }

    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let failureIcon = UIImageView(image: UIImage(systemName: "photo.badge.exclamationmark"))
    private let failureLabel = UILabel()
    private let failureStack = UIStackView()

    private(set) var state: State = .empty
    private var reference = ""
    private var loadToken = UUID()
    private let store: CardImageStore
    /// Thumbnails show only the icon on failure; large presentations also say why and offer a retry by tap.
    var isCompact = false { didSet { failureLabel.isHidden = isCompact } }
    var onStateChange: ((State) -> Void)?

    init(store: CardImageStore = .shared) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = Design.Color.highlight
        clipsToBounds = true
        layer.cornerCurve = .continuous
        layer.cornerRadius = Design.Spacing.m
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        failureIcon.tintColor = Design.Color.textSecondary
        failureIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        failureLabel.apply(.metadata)
        failureLabel.textAlignment = .center
        failureLabel.text = NSLocalizedString("Picture unavailable. Tap to try again.", comment: "")
        failureStack.axis = .vertical
        failureStack.alignment = .center
        failureStack.spacing = Design.Spacing.xs
        failureStack.translatesAutoresizingMaskIntoConstraints = false
        failureStack.isHidden = true
        [failureIcon, failureLabel].forEach(failureStack.addArrangedSubview)
        [imageView, spinner, failureStack].forEach(addSubview)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            failureStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            failureStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            failureStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Design.Spacing.s),
            failureStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Design.Spacing.s)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(retryIfFailed)))
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }

    /// Loads `reference` (a stored `imageUrl`). An empty reference clears the view.
    func setReference(_ newReference: String) {
        guard newReference != reference || state == .failed else { return }
        cancel()
        reference = newReference
        let parsed = CardImageReference(newReference)
        switch parsed {
        case .none:
            apply(.empty)
        case .unsupported:
            apply(.failed)
        case .local:
            apply(.loading)
            let token = loadToken
            let target = maxPixelSize
            let store = store
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let image = store.image(for: parsed, maxPixelSize: target)
                DispatchQueue.main.async {
                    guard let self, self.loadToken == token else { return }
                    self.imageView.image = image
                    self.apply(image == nil ? .failed : .loaded)
                }
            }
        case .remote(let url):
            apply(.loading)
            let token = loadToken
            var options: KingfisherOptionsInfo = [
                .processor(DownsamplingImageProcessor(size: CGSize(width: maxPixelSize, height: maxPixelSize))),
                .scaleFactor(1),
                .cacheOriginalImage
            ]
            // The learner's own copy awaiting a rights review is served only with the session. It is attached to the API's
            // address alone, and such a picture is kept in memory only: it must not outlive the session on disk.
            if let authorization = APIImageAuthorization.header(for: url, token: AuthSession.shared.bearerToken) {
                options.append(.requestModifier(AnyModifier { request in
                    var request = request
                    request.setValue(authorization, forHTTPHeaderField: "Authorization")
                    return request
                }))
                options.append(.cacheMemoryOnly)
            }
            imageView.kf.setImage(with: url, options: options) { [weak self] result in
                guard let self, self.loadToken == token else { return }
                if case .failure(let error) = result, !error.isTaskCancelled, !error.isNotCurrentTask {
                    self.apply(.failed)
                } else if case .success = result {
                    self.apply(.loaded)
                }
            }
        }
    }

    /// Stops any work in flight; call when a cell is reused or the view goes away.
    func cancel() {
        loadToken = UUID()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        // Forget what was shown: the same reference set again afterwards (cell reuse, "Show pictures" toggled back on,
        // returning to a previous card) must load again instead of being skipped as "already displayed".
        reference = ""
        state = .empty
        spinner.stopAnimating()
        failureStack.isHidden = true
        imageView.isHidden = true
    }

    private var maxPixelSize: Int {
        let side = max(bounds.width, bounds.height, 320) * (window?.windowScene?.screen.scale ?? traitCollection.displayScale)
        return Int(min(side, CGFloat(CardImageStore.maximumPixelSize)))
    }

    private func apply(_ newState: State) {
        state = newState
        spinner.stopAnimating()
        failureStack.isHidden = newState != .failed
        imageView.isHidden = newState != .loaded
        if newState == .loading { spinner.startAnimating() }
        isHidden = false
        onStateChange?(newState)
    }

    @objc private func retryIfFailed() {
        guard state == .failed else { return }
        let current = reference
        reference = ""
        setReference(current)
    }
}

/// Decides whether a picture request carries the session: only to the API's own host, never to a third-party address.
enum APIImageAuthorization {
    static func isAPIAddress(_ url: URL, apiBase: String = EnvironmentConfig.baseUrl()) -> Bool {
        guard let base = URL(string: apiBase), let scheme = base.scheme?.lowercased(), let host = base.host?.lowercased() else { return false }
        return url.scheme?.lowercased() == scheme && url.host?.lowercased() == host && url.port == base.port
            && url.path.hasPrefix("/api/media/")
    }

    /// `Authorization` for `url`, or `nil` for any other address or when nobody is signed in.
    static func header(for url: URL, token: String?, apiBase: String = EnvironmentConfig.baseUrl()) -> String? {
        guard let token, !token.isEmpty, isAPIAddress(url, apiBase: apiBase) else { return nil }
        return "Bearer " + token
    }
}
