import RxSwift
import UIKit
import XCTest
@testable import FlashcardApp

final class DictionaryScanPresenterTests: XCTestCase {
    private var interactor: FakeScanInteractor!
    private var wireframe: FakeScanWireframe!
    private var presenter: DictionaryScanPresenter!

    override func setUp() {
        super.setUp()
        interactor = FakeScanInteractor()
        wireframe = FakeScanWireframe()
        presenter = DictionaryScanPresenter(interactor: interactor, wireframe: wireframe)
    }

    private func pump() { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    private let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }

    func testItStartsByOfferingThePhotoSources() {
        XCTAssertEqual(presenter.state.value, .choosing(camera: .available))
    }

    func testTheCameraOpensOnlyWhenPermissionAllowsIt() {
        presenter.takePhoto()
        XCTAssertEqual(wireframe.cameraOpened, 1)

        interactor.access = .denied
        presenter.takePhoto()
        XCTAssertEqual(wireframe.cameraOpened, 1)
        XCTAssertEqual(presenter.state.value, .choosing(camera: .denied), "The screen explains how to allow the camera")

        interactor.access = .unavailable
        presenter.takePhoto()
        XCTAssertEqual(presenter.state.value, .choosing(camera: .unavailable))
        XCTAssertEqual(wireframe.cameraOpened, 1)
    }

    func testTheFirstUseAsksThePermissionThenOpensTheCameraOnlyIfGranted() {
        interactor.access = .notDetermined
        interactor.permissionResult = false
        presenter.takePhoto()
        pump()
        XCTAssertEqual(interactor.permissionRequests, 1)
        XCTAssertEqual(wireframe.cameraOpened, 0)

        interactor.access = .notDetermined
        interactor.permissionResult = true
        presenter.takePhoto()
        pump()
        XCTAssertEqual(wireframe.cameraOpened, 1)
    }

    func testAPhotoIsRecognizedAndTheTextShownForCorrection() {
        interactor.result = .just(RecognizedText(lines: ["食べる", "飲む"]))
        presenter.imagePicked(image)
        pump()
        XCTAssertEqual(presenter.state.value, .recognized("食べる\n飲む"))
        XCTAssertEqual(interactor.recognizeCalls, 1)
    }

    func testNoTextAndFailuresAreReportedHonestly() {
        interactor.result = .just(RecognizedText(lines: [" "]))
        presenter.imagePicked(image)
        pump()
        XCTAssertEqual(presenter.state.value, .noText, "No text is never turned into fake text")
        interactor.result = .error(TextRecognitionError.japaneseUnsupported)
        presenter.imagePicked(image)
        pump()
        XCTAssertEqual(presenter.state.value, .failed(TextRecognitionError.japaneseUnsupported.errorDescription!))
    }

    func testAnUnfinishedRecognitionIsAbandonedWhenANewPhotoOrScanAnotherArrives() {
        let pending = PublishSubject<RecognizedText>()
        interactor.result = pending.asSingle()
        presenter.imagePicked(image)
        XCTAssertEqual(presenter.state.value, .recognizing)
        presenter.scanAnother()
        pending.onNext(RecognizedText(lines: ["遅い"]))
        pending.onCompleted()
        pump()
        XCTAssertEqual(presenter.state.value, .choosing(camera: .available), "A late result of an abandoned photo is ignored")
    }

    func testOnlyTextASearchAcceptsIsLookedUp() {
        presenter.lookUp("  食べる \n")
        XCTAssertEqual(wireframe.lookedUp, ["食べる"])
        presenter.lookUp("   ")
        presenter.lookUp("a")
        presenter.lookUp(String(repeating: "日", count: 70))
        XCTAssertEqual(wireframe.lookedUp.count, 1)
    }

    func testClosingAndSettingsAreRoutedThroughTheWireframe() {
        presenter.close()
        presenter.openSettings()
        XCTAssertEqual(wireframe.closed, 1)
        XCTAssertEqual(wireframe.settingsOpened, 1)
    }
}

private final class FakeScanInteractor: DictionaryScanInteractorInterface {
    var access: CameraAccess = .available
    var permissionResult = true
    var permissionRequests = 0
    var result: Single<RecognizedText> = .never()
    var recognizeCalls = 0
    var cameraAccess: CameraAccess { access }
    func requestCamera() -> Single<Bool> { permissionRequests += 1; return .just(permissionResult) }
    func recognize(_ image: UIImage) -> Single<RecognizedText> { recognizeCalls += 1; return result }
}

private final class FakeScanWireframe: DictionaryScanWireframeInterface {
    var cameraOpened = 0
    var photoOpened = 0
    var lookedUp: [String] = []
    var closed = 0
    var settingsOpened = 0
    func showCamera() { cameraOpened += 1 }
    func showPhotoPicker() { photoOpened += 1 }
    func finish(lookingUp text: String) { lookedUp.append(text) }
    func close() { closed += 1 }
    func openSystemSettings() { settingsOpened += 1 }
}
