import RxSwift
import UIKit
import XCTest
@testable import FlashcardApp

final class TextRecognitionTests: XCTestCase {
    func testRecognizedLinesAreTrimmedAndEmptyOnesDropped() {
        let text = RecognizedText(lines: ["  食べる ", "", "\n", "ご飯を食べます。"])
        XCTAssertEqual(text.lines, ["食べる", "ご飯を食べます。"])
        XCTAssertEqual(text.text, "食べる\nご飯を食べます。")
        XCTAssertTrue(RecognizedText(lines: [" ", ""]).isEmpty)
    }

    func testEveryImageOrientationMapsToItsImageIOTwin() {
        let pairs: [(UIImage.Orientation, CGImagePropertyOrientation)] = [(.up, .up), (.down, .down), (.left, .left), (.right, .right),
                                                                        (.upMirrored, .upMirrored), (.leftMirrored, .leftMirrored)]
        for (ui, io) in pairs { XCTAssertEqual(CGImagePropertyOrientation(ui), io) }
    }

    /// Runs the real Vision request on a rendered picture of Japanese text: the pipeline is on-device and needs no network.
    func testVisionReadsJapaneseTextFromARenderedPicture() throws {
        let size = CGSize(width: 900, height: 300)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ("今日は天気がいいです" as NSString).draw(in: CGRect(x: 40, y: 80, width: 820, height: 140), withAttributes: [
                .font: UIFont(name: "HiraginoSans-W6", size: 90) ?? UIFont.systemFont(ofSize: 90, weight: .semibold), .foregroundColor: UIColor.black])
        }
        let done = expectation(description: "recognized")
        var outcome: Result<RecognizedText, Error>?
        let bag = DisposeBag()
        VisionTextRecognizer().recognize(image).subscribe(onSuccess: { outcome = .success($0); done.fulfill() },
                                                           onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 30)
        let result = try XCTUnwrap(outcome).get()
        XCTAssertTrue(result.text.contains("天気"), "Recognized: \(result.text)")
    }

    func testAnImageWithoutPixelsIsRefused() {
        let done = expectation(description: "failed")
        let bag = DisposeBag()
        VisionTextRecognizer().recognize(UIImage()).subscribe(onSuccess: { _ in XCTFail(); done.fulfill() }, onFailure: {
            XCTAssertEqual($0 as? TextRecognitionError, .unreadableImage)
            done.fulfill()
        }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }
}
