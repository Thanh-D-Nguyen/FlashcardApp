import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// Owns the UMP decision for this launch. No ad requests happen before UMP allows them.
final class AdsService {
    static let shared = AdsService()
    static let stateDidChange = Notification.Name("AdsServiceStateDidChange")

    private var updatingConsent = false
    private var consentUpdated = false
    private var started = false
    private weak var consentController: UIViewController?
    private let enabledOverride: Bool?
    private let update: (@escaping (Error?) -> Void) -> Void
    private let form: (UIViewController) async throws -> Void

    init(enabled: Bool? = nil,
         update: @escaping (@escaping (Error?) -> Void) -> Void = { ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters(), completionHandler: $0) },
         form: @escaping (UIViewController) async throws -> Void = { try await ConsentForm.loadAndPresentIfRequired(from: $0) }) {
        enabledOverride = enabled
        self.update = update
        self.form = form
    }

    private var enabled: Bool {
        enabledOverride ?? (!ProcessInfo.processInfo.arguments.contains("-disableAds") &&
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil)
    }

    var privacyOptionsRequired: Bool {
        enabled && ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    var canLoadAds: Bool {
        enabled && started && ConsentInformation.shared.canRequestAds
    }

    func prepare(from controller: UIViewController) {
        guard enabled, !consentUpdated, controller.view.window != nil else { return }
        consentController = controller
        guard !updatingConsent else { return }
        updatingConsent = true
        update { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.updatingConsent = false
                    NSLog("Ad consent update failed: %@", error.localizedDescription)
                    self.startIfAllowed() // UMP may allow the consent cached from an earlier session.
                    self.publish()
                    return
                }
                guard let controller = self.consentController, controller.view.window != nil else {
                    self.updatingConsent = false
                    return
                }
                Task { @MainActor in
                    do {
                        try await self.form(controller)
                        self.consentUpdated = true
                    } catch {
                        NSLog("Ad consent form failed: %@", error.localizedDescription)
                    }
                    self.updatingConsent = false
                    self.startIfAllowed()
                    self.publish()
                }
            }
        }
    }

    func presentPrivacyOptions(from controller: UIViewController) {
        guard privacyOptionsRequired else { return }
        Task { @MainActor in
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: controller)
            } catch {
                NSLog("Ad privacy options failed: %@", error.localizedDescription)
            }
            startIfAllowed()
            publish()
        }
    }

    private func startIfAllowed() {
        guard enabled, ConsentInformation.shared.canRequestAds, !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        MobileAds.shared.start()
    }

    private func publish() {
        NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
    }
}

/// Collapses on a failed request and reserves exactly one ad height when an ad arrives.
final class AdsBannerView: UIView, BannerViewDelegate {
    var onHeightChange: ((CGFloat) -> Void)?

    private weak var owner: UIViewController?
    private let banner = BannerView()
    private var heightConstraint: NSLayoutConstraint!
    private var requestedWidth: CGFloat = 0
    private var observer: NSObjectProtocol?
    private let canLoadAds: () -> Bool

    var bannerHeight: CGFloat { heightConstraint.constant }

    init(owner: UIViewController, canLoadAds: @escaping () -> Bool = { AdsService.shared.canLoadAds }) {
        self.owner = owner
        self.canLoadAds = canLoadAds
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.rootViewController = owner
        banner.delegate = self
        banner.adUnitID = Bundle.main.object(forInfoDictionaryKey: "AdMobBannerUnitID") as? String ?? ""
        banner.isHidden = true
        addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        observer = NotificationCenter.default.addObserver(forName: AdsService.stateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.requestedWidth = 0
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    func refresh() {
        guard canLoadAds() else {
            requestedWidth = 0
            banner.isHidden = true
            setHeight(0)
            return
        }
        let width = bounds.width
        guard width > 0, owner?.view.window != nil,
              banner.adUnitID?.hasPrefix("ca-app-pub-") == true, abs(width - requestedWidth) > 1 else { return }
        requestedWidth = width
        banner.isHidden = true
        setHeight(0)
        banner.adSize = largeAnchoredAdaptiveBanner(width: width)
        banner.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard canLoadAds() else {
            refresh()
            return
        }
        banner.isHidden = false
        setHeight(bannerView.adSize.size.height)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        banner.isHidden = true
        setHeight(0)
        NSLog("Ad banner failed: %@", error.localizedDescription)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.banner.isHidden else { return }
            self.requestedWidth = 0
            self.refresh()
        }
    }

    private func setHeight(_ value: CGFloat) {
        guard heightConstraint.constant != value else { return }
        heightConstraint.constant = value
        onHeightChange?(value)
    }
}
