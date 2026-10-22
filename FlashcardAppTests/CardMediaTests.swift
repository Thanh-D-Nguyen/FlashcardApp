import Alamofire
import RxSwift
import UIKit
import XCTest
@testable import FlashcardApp

final class CardImageReferenceTests: XCTestCase {
    func test_parsesEveryStoredShape() {
        XCTAssertEqual(CardImageReference(""), .none)
        XCTAssertEqual(CardImageReference("  "), .none)
        XCTAssertEqual(CardImageReference("local-image:a.jpg"), .local(fileName: "a.jpg"))
        XCTAssertEqual(CardImageReference("https://example.com/a.png"), .remote(URL(string: "https://example.com/a.png")!))
        XCTAssertEqual(CardImageReference("http://localhost:18081/a.png"), .remote(URL(string: "http://localhost:18081/a.png")!))
    }

    func test_localReferenceCannotEscapeTheImageDirectory() {
        XCTAssertEqual(CardImageReference("local-image:../secret.realm"), .unsupported("local-image:../secret.realm"))
        XCTAssertEqual(CardImageReference("local-image:a/b.jpg"), .unsupported("local-image:a/b.jpg"))
        XCTAssertEqual(CardImageReference("local-image:"), .unsupported("local-image:"))
    }

    func test_unknownLegacyValuesAreKeptVerbatim() {
        XCTAssertEqual(CardImageReference("ftp://x/y.png").raw, "ftp://x/y.png")
        XCTAssertEqual(CardImageReference("not a url").raw, "not a url")
        XCTAssertEqual(CardImageReference("local-image:a.jpg").raw, "local-image:a.jpg")
    }
}

final class CardImageStoreTests: XCTestCase {
    private var directory: URL!
    private var store: CardImageStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("card-images-\(UUID().uuidString)")
        store = CardImageStore(directory: directory)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    private func pngData(width: Int, height: Int, color: UIColor = .systemTeal, opaque: Bool = true) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func test_savedPictureIsReadableAgainFromItsReference() throws {
        let reference = try store.save(imageData: pngData(width: 200, height: 100))
        XCTAssertTrue(reference.hasPrefix("local-image:"))
        XCTAssertTrue(store.exists(CardImageReference(reference)))
        let image = try XCTUnwrap(store.image(for: CardImageReference(reference)))
        XCTAssertEqual(image.size.width * image.scale, 200, accuracy: 1)
    }

    func test_pictureIsStillThereForANewStoreInstanceAsAfterARelaunch() throws {
        let reference = try store.save(imageData: pngData(width: 50, height: 50))
        let relaunched = CardImageStore(directory: directory)
        XCTAssertNotNil(relaunched.image(for: CardImageReference(reference)))
    }

    func test_largePicturesAreDownsampledToTheStorageLimit() throws {
        let reference = try store.save(imageData: pngData(width: 4000, height: 2000))
        let image = try XCTUnwrap(store.image(for: CardImageReference(reference), maxPixelSize: 5000))
        XCTAssertEqual(max(image.size.width, image.size.height) * image.scale, CGFloat(CardImageStore.maximumPixelSize), accuracy: 1)
    }

    func test_nonImageBytesAreRejected() {
        XCTAssertThrowsError(try store.save(imageData: Data("hello".utf8))) { XCTAssertEqual($0 as? CardImageError, .unreadable) }
        XCTAssertThrowsError(try store.save(imageData: Data())) { XCTAssertEqual($0 as? CardImageError, .unreadable) }
    }

    func test_oversizedInputIsRejectedBeforeDecoding() {
        let data = Data(count: CardImageStore.maximumInputBytes + 1)
        XCTAssertThrowsError(try store.save(imageData: data)) {
            XCTAssertEqual($0 as? CardImageError, .tooLarge(maximumMegabytes: 25))
        }
    }

    func test_transparentPicturesAreFlattenedOnWhiteNotBlack() throws {
        let clear = pngData(width: 20, height: 20, color: .clear, opaque: false)
        let reference = try store.save(imageData: clear)
        let image = try XCTUnwrap(store.image(for: CardImageReference(reference)))
        let pixel = try XCTUnwrap(image.cgImage.flatMap { Self.firstPixel($0) })
        XCTAssertGreaterThan(pixel.red, 240)
        XCTAssertGreaterThan(pixel.green, 240)
    }

    func test_absurdResolutionsAreRefusedBeforeDecoding() {
        let small = CardImageStore(directory: directory, maximumPixels: 1_000)
        XCTAssertThrowsError(try small.save(imageData: pngData(width: 100, height: 100))) { XCTAssertEqual($0 as? CardImageError, .resolutionTooHigh) }
        XCTAssertNoThrow(try small.save(imageData: pngData(width: 20, height: 20)))
    }

    func test_garbageCollectionKeepsOnlyReferencedPictures() throws {
        let kept = try store.save(imageData: pngData(width: 10, height: 10))
        let dropped = try store.save(imageData: pngData(width: 11, height: 11))
        let removed = store.removeUnreferenced(keeping: [kept, "https://example.com/remote.png"])
        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(store.exists(CardImageReference(kept)))
        XCTAssertFalse(store.exists(CardImageReference(dropped)))
    }

    private static func firstPixel(_ image: CGImage) -> (red: Int, green: Int, blue: Int)? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }
}

final class ChipButtonTests: XCTestCase {
    func test_aSmallChipStillHasAFortyFourPointTouchArea() {
        let chip = ChipButton(frame: CGRect(x: 0, y: 0, width: 70, height: 30))
        XCTAssertTrue(chip.point(inside: CGPoint(x: 35, y: -6), with: nil), "Just above the drawn capsule is still a hit")
        XCTAssertTrue(chip.point(inside: CGPoint(x: 35, y: 36), with: nil))
        XCTAssertFalse(chip.point(inside: CGPoint(x: 35, y: -9), with: nil), "But not beyond 44 pt")
    }
}

final class CardImageViewTests: XCTestCase {
    private var directory: URL!
    private var store: CardImageStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("card-image-view-\(UUID().uuidString)")
        store = CardImageStore(directory: directory)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    private func storedPicture() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30))
        return try store.save(image: renderer.image { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 30, height: 30)) })
    }

    private func waitFor(_ view: CardImageView, _ state: CardImageView.State) {
        let deadline = Date().addingTimeInterval(3)
        while view.state != state, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertEqual(view.state, state)
    }

    func test_aLocalPictureLoads() throws {
        let view = CardImageView(store: store)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.setReference(try storedPicture())
        waitFor(view, .loaded)
    }

    func test_theSamePictureLoadsAgainAfterCancelInsteadOfStayingBlank() throws {
        let view = CardImageView(store: store)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let reference = try storedPicture()
        view.setReference(reference)
        waitFor(view, .loaded)
        view.cancel()                       // what cell reuse / "Show pictures" off does
        XCTAssertEqual(view.state, .empty)
        view.setReference(reference)        // the same card comes back
        waitFor(view, .loaded)
    }

    func test_cancelDuringLoadingDoesNotLeaveASpinnerBehind() throws {
        let view = CardImageView(store: store)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.setReference(try storedPicture())
        view.cancel()
        XCTAssertEqual(view.state, .empty)
    }

    func test_aMissingFileShowsTheFailureState() {
        let view = CardImageView(store: store)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.setReference("local-image:missing.jpg")
        waitFor(view, .failed)
    }
}

final class DeckDraftStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: DeckDraftStore!

    override func setUp() {
        super.setUp()
        let suite = "deck-draft-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = DeckDraftStore(defaults: defaults)
    }

    func test_draftsAreKeptPerDeckAndSurviveANewStoreInstance() {
        store.save(DeckDraft(name: "New one"))
        store.save(DeckDraft(deckId: "abc", name: "Edited"))
        let relaunched = DeckDraftStore(defaults: defaults)
        XCTAssertEqual(relaunched.draft(forDeckId: nil)?.name, "New one")
        XCTAssertEqual(relaunched.draft(forDeckId: "abc")?.name, "Edited")
        XCTAssertNil(relaunched.draft(forDeckId: "other"))
    }

    func test_discardRemovesOnlyThatDraft() {
        store.save(DeckDraft(name: "New one"))
        store.save(DeckDraft(deckId: "abc", name: "Edited"))
        store.discard(forDeckId: nil)
        XCTAssertNil(store.draft(forDeckId: nil))
        XCTAssertNotNil(store.draft(forDeckId: "abc"))
    }

    func test_corruptDraftIsDroppedInsteadOfBlockingTheEditor() {
        defaults.set(Data("{broken".utf8), forKey: "com.flashcardapp.cards.draft.new")
        XCTAssertNil(store.draft(forDeckId: nil))
        XCTAssertNil(defaults.data(forKey: "com.flashcardapp.cards.draft.new"))
    }

    func test_pictureReferencesOfDraftsAreReportedSoTheyAreNotCollected() {
        store.save(DeckDraft(name: "N", cards: [CardDraft(front: "a", back: "b", imageReference: "local-image:one.jpg")]))
        store.save(DeckDraft(deckId: "x", name: "N", cards: [CardDraft(front: "a", back: "b", imageReference: "local-image:two.jpg")]))
        XCTAssertEqual(store.referencedImages(), ["local-image:one.jpg", "local-image:two.jpg"])
    }
}

final class RemoteImageLoaderTests: XCTestCase {
    private var loader: RemoteImageLoader!
    private var session: Session!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageURLProtocol.self]
        session = Session(configuration: configuration)
        loader = RemoteImageLoader(session: session)
        bag = DisposeBag()
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        ImageURLProtocol.handler = nil
        ImageURLProtocol.requests = []
        super.tearDown()
    }

    private let url = URL(string: "https://images.test/cat.png")!

    private func result(_ single: Single<Data>) -> Result<Data, Error> {
        let done = expectation(description: "image")
        var captured: Result<Data, Error>?
        single.subscribe(onSuccess: { captured = .success($0); done.fulfill() },
                         onFailure: { captured = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 5)
        return captured!
    }

    func test_inputMustBeAnHTTPSAddress() {
        XCTAssertNoThrow(try RemoteImageLoader.validatedURL(" https://example.com/a.jpg "))
        XCTAssertThrowsError(try RemoteImageLoader.validatedURL("http://example.com/a.jpg")) { XCTAssertEqual($0 as? RemoteImageError, .insecureScheme) }
        XCTAssertThrowsError(try RemoteImageLoader.validatedURL("javascript:alert(1)")) { XCTAssertEqual($0 as? RemoteImageError, .invalidURL) }
        XCTAssertThrowsError(try RemoteImageLoader.validatedURL("")) { XCTAssertEqual($0 as? RemoteImageError, .invalidURL) }
        XCTAssertThrowsError(try RemoteImageLoader.validatedURL("https://")) { XCTAssertEqual($0 as? RemoteImageError, .invalidURL) }
    }

    func test_downloadsPictureBytesWithoutCredentials() throws {
        ImageURLProtocol.handler = { _ in (200, ["Content-Type": "image/png"], Data([1, 2, 3])) }
        XCTAssertEqual(try result(loader.fetch(url)).get(), Data([1, 2, 3]))
        XCTAssertNil(ImageURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(ImageURLProtocol.requests.first?.value(forHTTPHeaderField: "Cookie"))
    }

    func test_httpStatusErrorsArePropagated() {
        ImageURLProtocol.handler = { _ in (404, ["Content-Type": "text/html"], Data()) }
        guard case .failure(let error) = result(loader.fetch(url)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? RemoteImageError, .server(404))
    }

    func test_htmlPagesAreRejectedAsNotAnImage() {
        ImageURLProtocol.handler = { _ in (200, ["Content-Type": "text/html"], Data("<html>".utf8)) }
        guard case .failure(let error) = result(loader.fetch(url)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? RemoteImageError, .notAnImage)
    }

    func test_declaredOversizedPicturesAreRejected() {
        ImageURLProtocol.handler = { _ in
            (200, ["Content-Type": "image/jpeg", "Content-Length": "\(RemoteImageLoader.maximumBytes + 1)"], Data(count: 16))
        }
        guard case .failure(let error) = result(loader.fetch(url)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? RemoteImageError, .tooLarge(maximumMegabytes: 10))
    }

    func test_plainHTTPIsNeverRequested() {
        guard case .failure(let error) = result(loader.fetch(URL(string: "http://images.test/a.png")!)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? RemoteImageError, .insecureScheme)
        XCTAssertTrue(ImageURLProtocol.requests.isEmpty)
    }

    func test_onlyHTTPSRedirectsAreFollowed() {
        XCTAssertNotNil(RemoteImageLoader.allowedRedirect(URLRequest(url: URL(string: "https://cdn.test/cat.png")!)))
        XCTAssertNil(RemoteImageLoader.allowedRedirect(URLRequest(url: URL(string: "http://192.168.0.5/secret.png")!)))
        XCTAssertNil(RemoteImageLoader.allowedRedirect(URLRequest(url: URL(string: "http://localhost:18081/api/x")!)))
        XCTAssertNil(RemoteImageLoader.allowedRedirect(URLRequest(url: URL(string: "file:///etc/passwd")!)))
    }

    func test_offlineIsReportedDistinctly() {
        ImageURLProtocol.failure = URLError(.notConnectedToInternet)
        defer { ImageURLProtocol.failure = nil }
        guard case .failure(let error) = result(loader.fetch(url)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? RemoteImageError, .offline)
    }
}

private final class ImageURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, [String: String], Data))?
    static var failure: Error?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let (status, headers, body) = Self.handler?(request) ?? (500, [:], Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
