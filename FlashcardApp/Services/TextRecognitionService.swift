//
//  TextRecognitionService.swift
//  FlashcardApp
//
//  Reads Japanese text from a photo with Apple's Vision framework. Recognition runs on the device; the image is never
//  uploaded, written to disk or kept after the request. Nothing is invented: what Vision cannot read is simply absent.
//

import Foundation
import ImageIO
import RxSwift
import UIKit
import Vision

struct RecognizedText: Equatable {
    let lines: [String]

    /// Lines as Vision returned them (top to bottom for horizontal text), trimmed, without empty lines.
    init(lines: [String]) {
        self.lines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var text: String { lines.joined(separator: "\n") }
    var isEmpty: Bool { lines.isEmpty }
}

enum TextRecognitionError: Error, Equatable, LocalizedError {
    /// This iOS version has no Japanese text recognition.
    case japaneseUnsupported
    case unreadableImage
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .japaneseUnsupported: return NSLocalizedString("This device can’t recognize Japanese text.", comment: "")
        case .unreadableImage: return NSLocalizedString("The photo could not be read.", comment: "")
        case .failed(let reason): return String(format: NSLocalizedString("Text recognition failed: %@", comment: ""), reason)
        }
    }
}

protocol TextRecognizing: AnyObject {
    func recognize(_ image: UIImage) -> Single<RecognizedText>
}

final class VisionTextRecognizer: TextRecognizing {
    static let languages = ["ja-JP", "en-US"]

    func recognize(_ image: UIImage) -> Single<RecognizedText> {
        Single.create { observer in
            guard let cgImage = image.cgImage else {
                observer(.failure(TextRecognitionError.unreadableImage))
                return Disposables.create()
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            guard supported.contains("ja-JP") else {
                observer(.failure(TextRecognitionError.japaneseUnsupported))
                return Disposables.create()
            }
            request.recognitionLanguages = Self.languages.filter(supported.contains)
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
                    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    observer(.success(RecognizedText(lines: lines)))
                } catch {
                    observer(.failure(TextRecognitionError.failed(error.localizedDescription)))
                }
            }
            return Disposables.create { request.cancel() }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
