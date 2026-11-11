import RxSwift
import XCTest
@testable import FlashcardApp

/// A token of the production shape (32 random bytes, base64url, 43 characters). Not a real token.
private let token = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcd"

final class DeckShareLinkTests: XCTestCase {
    func test_theWebsitesLinksAndABareTokenAreRead() {
        XCTAssertEqual(DeckShareLink.parse("https://kiokoto.com/vi/decks/shared/\(token)", webHost: "kiokoto.com")?.token, token)
        XCTAssertEqual(DeckShareLink.parse("  https://www.kiokoto.com/ja/decks/shared/\(token)?utm=x \n", webHost: "kiokoto.com")?.token, token)
        XCTAssertEqual(DeckShareLink.parse("https://kiokoto.com/vi/flashcards?cloneToken=\(token)", webHost: "kiokoto.com")?.token, token)
        XCTAssertEqual(DeckShareLink.parse(token, webHost: "kiokoto.com")?.token, token)
    }

    func test_otherHostsAndMalformedTokensAreRefused() {
        XCTAssertNil(DeckShareLink.parse("https://kiokoto.com.evil.example/vi/decks/shared/\(token)", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse("https://evil.example/vi/decks/shared/\(token)", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse("https://kiokoto.com/vi/decks/shared/short", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse("https://kiokoto.com/vi/decks/shared/\(token)%2F..%2Fadmin", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse("javascript:alert(1)", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse("", webHost: "kiokoto.com"))
        XCTAssertNil(DeckShareLink.parse(String(repeating: "a", count: 65), webHost: "kiokoto.com"))
    }

    func test_theLinkIsTheWebsitesPageForTheAppLanguage() {
        let origin = DeckShareLink.webOrigin(apiBase: "https://kiokoto.com/api")
        XCTAssertEqual(origin?.absoluteString, "https://kiokoto.com")
        XCTAssertEqual(DeckShareLink(token: token).url(webOrigin: origin!, localeCode: "ja")?.absoluteString,
                       "https://kiokoto.com/ja/decks/shared/\(token)")
    }
}

private final class SignedOutTokens: AuthTokenManagerInterface {
    var accessToken: String? { nil }
    var userId: String? { nil }
    func save(accessToken: String, userId: String) throws {}
    func clear() throws {}
}

private final class UnusedNativeAuth: NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse> { fatalError() }
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> { fatalError() }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> { fatalError() }
    func logout(token: @escaping () -> String?) -> Single<Void> { fatalError() }
}

private final class FakeShareAPI: BJTDeckShareAPIInterface {
    var shareResult: Single<String> = .just(token)
    func shareDeck(id: String) -> Single<String> { shareResult }
    func unshareDeck(id: String) -> Single<Void> { .just(()) }
    func sharedDeckPreview(token: String) -> Single<BJTSharedDeckPreviewDTO> { .error(LearnerAPIError.notFound) }
    func cloneSharedDeck(token: String) -> Single<BJTClonedDeckDTO> { .error(LearnerAPIError.notFound) }
}

final class DeckSharingInteractorTests: XCTestCase {
    func test_theLinkUsesTheWebsiteOfTheAPIInUseAndOnlyItsHostIsAccepted() throws {
        let interactor = DeckSharingInteractor(api: FakeShareAPI(), auth: AuthSession(tokens: SignedOutTokens(), api: UnusedNativeAuth()),
                                               apiBase: { "https://kiokoto.com/api" }, language: { .vietnamese })
        var url: URL?
        _ = interactor.shareLink(deckId: "11111111-2222-4333-8444-555555555555").subscribe(onSuccess: { url = $0 })
        XCTAssertEqual(url?.absoluteString, "https://kiokoto.com/vi/decks/shared/\(token)")
        XCTAssertEqual(interactor.link(from: "https://kiokoto.com/en/decks/shared/\(token)"), DeckShareLink(token: token))
        XCTAssertNil(interactor.link(from: "https://localhost/en/decks/shared/\(token)"))
        XCTAssertFalse(interactor.isSignedIn)
    }
}

private final class FakeSharedDeckWireframe: SharedDeckWireframeInterface {
    private(set) var signIns = 0
    private(set) var opened: [String] = []
    private var finish: (() -> Void)?
    func showSignIn(onFinish: @escaping () -> Void) { signIns += 1; finish = onFinish }
    func showAccountDeck(id: String) { opened.append(id) }
}

private final class SpySharedDeckView: SharedDeckViewInterface {
    var states: [SharedDeckState] = []
    func render(_ state: SharedDeckState) { states.append(state) }
    var last: SharedDeckState { states.last ?? SharedDeckState() }
}

/// The production preview answer for the contract test deck (2026-11-11).
private let preview = BJTSharedDeckPreviewDTO(titleVi: "iOS share test", titleJa: nil, descriptionVi: nil, cardCount: 2, cloneCount: 0,
                                              sampleCards: [.init(frontText: "犬", reading: "いぬ"), .init(frontText: "猫", reading: "ねこ")])

final class SharedDeckPresenterTests: XCTestCase {
    private var sharing: FakeDeckSharing!
    private var wireframe: FakeSharedDeckWireframe!
    private var view: SpySharedDeckView!

    override func setUp() {
        super.setUp()
        sharing = FakeDeckSharing()
        sharing.previewResult = .just(preview)
        wireframe = FakeSharedDeckWireframe()
        view = SpySharedDeckView()
    }

    private func start() -> SharedDeckPresenter {
        let presenter = SharedDeckPresenter(link: DeckShareLink(token: token), interactor: sharing, wireframe: wireframe)
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    func test_anyoneSeesThePublicPreview() {
        sharing.isSignedIn = false
        _ = start()
        XCTAssertEqual(view.last.phase, .loaded)
        XCTAssertEqual(view.last.title, "iOS share test")
        XCTAssertEqual(view.last.samples, ["犬（いぬ）", "猫（ねこ）"])
        XCTAssertTrue(view.last.canSave)
        XCTAssertEqual(view.last.saveTitle, NSLocalizedString("Sign in to save", comment: ""))
    }

    func test_aGuestIsAskedToSignInAndNothingIsCopied() {
        sharing.isSignedIn = false
        let presenter = start()
        presenter.save()
        XCTAssertEqual(wireframe.signIns, 1)
        XCTAssertEqual(sharing.copies, 0)
    }

    func test_savingCopiesOnceAndOpensTheCopy() {
        let pending = PublishSubject<String>()
        sharing.copyResult = pending.take(1).asSingle()
        let presenter = start()
        presenter.save()
        presenter.save()
        XCTAssertEqual(sharing.copies, 1, "A second tap while saving sends nothing")
        XCTAssertTrue(view.last.isSaving)
        pending.onNext("99999999-2222-4333-8444-555555555555")
        let opened = expectation(description: "opened")
        DispatchQueue.main.async { opened.fulfill() }
        wait(for: [opened], timeout: 2)
        XCTAssertEqual(wireframe.opened, ["99999999-2222-4333-8444-555555555555"])
    }

    func test_anUnknownCopyOutcomeIsNotSavedAgain() {
        sharing.copyResult = .error(LearnerAPIError.interrupted)
        let presenter = start()
        presenter.save()
        XCTAssertNotNil(view.last.notice)
        XCTAssertFalse(view.last.canSave, "A second copy could be made")
        presenter.save()
        XCTAssertEqual(sharing.copies, 1)
    }

    func test_aRevokedLinkSaysItNoLongerWorks() {
        sharing.previewResult = .error(LearnerAPIError.notFound)
        _ = start()
        XCTAssertEqual(view.last.phase, .gone)
        XCTAssertFalse(view.last.canSave)
    }
}
