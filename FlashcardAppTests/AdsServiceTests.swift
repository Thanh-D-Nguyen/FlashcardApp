import XCTest
import UIKit
import GoogleMobileAds
@testable import FlashcardApp

@MainActor
final class AdsServiceTests: XCTestCase {
    private func makeWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        return UIWindow(windowScene: scene)
    }

    func testFormFailureCanRetry() async throws {
        let controller = UIViewController()
        let window = try makeWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        var attempts = 0
        let service = AdsService(enabled: true, update: { $0(nil) }, form: { _ in
            attempts += 1
            if attempts == 1 { throw NSError(domain: "test", code: 1) }
        })
        let first = expectation(forNotification: AdsService.stateDidChange, object: nil)
        service.prepare(from: controller)
        await fulfillment(of: [first], timeout: 2)
        let second = expectation(forNotification: AdsService.stateDidChange, object: nil)
        service.prepare(from: controller)
        await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(attempts, 2)
        _ = window
    }

    func testLatestControllerIsUsedAfterUpdate() async throws {
        let first = UIViewController()
        let second = UIViewController()
        let window = try makeWindow()
        window.rootViewController = first
        window.makeKeyAndVisible()
        var finish: ((Error?) -> Void)?
        var presented: UIViewController?
        let service = AdsService(enabled: true, update: { finish = $0 }, form: { presented = $0 })
        service.prepare(from: first)
        window.rootViewController = second
        service.prepare(from: second)
        let completed = expectation(forNotification: AdsService.stateDidChange, object: nil)
        finish?(nil)
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertTrue(presented === second)
        _ = window
    }

    func testLateBannerCallbackDoesNotShowAfterConsentRevoked() {
        var allowed = true
        let view = AdsBannerView(owner: UIViewController(), canLoadAds: { allowed })
        let banner = BannerView()
        banner.adSize = AdSizeBanner
        view.bannerViewDidReceiveAd(banner)
        XCTAssertGreaterThan(view.bannerHeight, 0)
        allowed = false
        view.refresh()
        view.bannerViewDidReceiveAd(banner)
        XCTAssertEqual(view.bannerHeight, 0)
    }
}
