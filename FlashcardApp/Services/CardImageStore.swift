//
//  CardImageStore.swift
//  FlashcardApp
//
//  Local storage for card pictures chosen from Photos or imported from a URL. The backend's deck API
//  has no field that links an image to a card, so pictures live next to the offline decks: files in
//  Application Support, referenced from `CardEntity.imageUrl` as `local-image:<file>`. The reference is
//  relative, so it survives a changed app-container path.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum CardImageReference: Equatable {
    case none
    case local(fileName: String)
    case remote(URL)
    /// A stored value this version cannot display (kept untouched, never rewritten).
    case unsupported(String)

    static let localPrefix = "local-image:"

    init(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            self = .none
        } else if value.hasPrefix(Self.localPrefix) {
            let name = String(value.dropFirst(Self.localPrefix.count))
            // A file name only: no path components can escape the image directory.
            self = (name.isEmpty || name.contains("/") || name.contains("..")) ? .unsupported(value) : .local(fileName: name)
        } else if let url = URL(string: value), let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http", url.host?.isEmpty == false {
            self = .remote(url)
        } else {
            self = .unsupported(value)
        }
    }

    var raw: String {
        switch self {
        case .none: return ""
        case .local(let name): return Self.localPrefix + name
        case .remote(let url): return url.absoluteString
        case .unsupported(let value): return value
        }
    }
}

enum CardImageError: Error, Equatable, LocalizedError {
    case unreadable
    case tooLarge(maximumMegabytes: Int)
    case resolutionTooHigh
    case unsupportedType
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadable: return NSLocalizedString("That file could not be read as a picture.", comment: "")
        case .tooLarge(let megabytes):
            return String(format: NSLocalizedString("The picture is larger than %lld MB.", comment: ""), megabytes)
        case .resolutionTooHigh: return NSLocalizedString("The picture's resolution is too high. Choose a smaller picture.", comment: "")
        case .unsupportedType: return NSLocalizedString("Use a JPEG, PNG, HEIC, WebP or GIF picture.", comment: "")
        case .writeFailed(let reason):
            return String(format: NSLocalizedString("Couldn't save the picture: %@", comment: ""), reason)
        }
    }
}

final class CardImageStore {
    static let shared = CardImageStore()

    /// Longest edge kept on disk; plenty for a full-width card on any iPhone, small enough to stay fast.
    static let maximumPixelSize = 1600
    static let maximumInputBytes = 25 * 1024 * 1024
    static let allowedTypes: [UTType] = [.jpeg, .png, .heic, .heif, .gif, .webP]

    /// Decoding a thumbnail of PNG/GIF/WebP needs the whole bitmap in memory; refuse absurd resolutions before that.
    static let maximumPixels = 40_000_000

    let directory: URL
    private let fileManager: FileManager
    private let maximumPixels: Int

    init(directory: URL? = nil, maximumPixels: Int = CardImageStore.maximumPixels, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.maximumPixels = maximumPixels
        self.directory = directory ?? (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CardImages", isDirectory: true))
    }

    /// Validates, downsamples and stores picture bytes. Returns the reference to save on the card.
    func save(imageData data: Data) throws -> String {
        guard !data.isEmpty else { throw CardImageError.unreadable }
        guard data.count <= Self.maximumInputBytes else {
            throw CardImageError.tooLarge(maximumMegabytes: Self.maximumInputBytes / (1024 * 1024))
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw CardImageError.unreadable
        }
        guard let identifier = CGImageSourceGetType(source) as String?, let type = UTType(identifier),
              Self.allowedTypes.contains(where: { type.conforms(to: $0) }) else {
            throw CardImageError.unsupportedType
        }
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
           width * height > maximumPixels {
            throw CardImageError.resolutionTooHigh
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maximumPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CardImageError.unreadable
        }
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CardImageError.writeFailed("encoder unavailable")
        }
        CGImageDestinationAddImage(destination, Self.flattened(cgImage), [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CardImageError.writeFailed("encoding failed") }
        let name = UUID().uuidString.lowercased() + ".jpg"
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try (encoded as Data).write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            throw CardImageError.writeFailed(error.localizedDescription)
        }
        return CardImageReference.local(fileName: name).raw
    }

    func save(image: UIImage) throws -> String {
        guard let data = image.pngData() else { throw CardImageError.unreadable }
        return try save(imageData: data)
    }

    func fileURL(for reference: CardImageReference) -> URL? {
        guard case .local(let name) = reference else { return nil }
        return directory.appendingPathComponent(name)
    }

    func exists(_ reference: CardImageReference) -> Bool {
        fileURL(for: reference).map { fileManager.fileExists(atPath: $0.path) } ?? false
    }

    /// Decodes a stored picture at no more than `maxPixelSize` on its longest edge.
    func image(for reference: CardImageReference, maxPixelSize: Int = CardImageStore.maximumPixelSize) -> UIImage? {
        guard let url = fileURL(for: reference),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }

    // MARK: Upload

    /// Smaller and smaller renditions tried until one fits: (longest edge in pixels, JPEG quality).
    static let uploadRenditions: [(pixels: Int, quality: CGFloat)] = [(1280, 0.7), (1024, 0.6), (800, 0.5)]

    /// JPEG bytes of a stored picture that fit in `maximumBytes`, for uploading to the account. The stored file is sent as it is
    /// when it already fits; otherwise it is re-encoded smaller. `nil` when the picture is missing, unreadable or still too large.
    func uploadData(for reference: CardImageReference, maximumBytes: Int) -> Data? {
        guard let url = fileURL(for: reference), let stored = try? Data(contentsOf: url), !stored.isEmpty else { return nil }
        if stored.count <= maximumBytes { return stored }
        guard let source = CGImageSourceCreateWithData(stored as CFData, nil) else { return nil }
        for rendition in Self.uploadRenditions {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: rendition.pixels
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let encoded = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, Self.flattened(image), [kCGImageDestinationLossyCompressionQuality: rendition.quality] as CFDictionary)
            if CGImageDestinationFinalize(destination), encoded.length <= maximumBytes { return encoded as Data }
        }
        return nil
    }

    // MARK: Attribution

    static let attributionSuffix = ".attribution.json"

    /// Records where a downloaded picture came from, next to the picture file.
    func saveAttribution(_ attribution: ImageAttribution, for reference: String) throws {
        guard case .local(let name) = CardImageReference(reference) else { return }
        do {
            try JSONEncoder().encode(attribution).write(to: directory.appendingPathComponent(name + Self.attributionSuffix), options: .atomic)
        } catch {
            throw CardImageError.writeFailed(error.localizedDescription)
        }
    }

    func attribution(for reference: String) -> ImageAttribution? {
        guard case .local(let name) = CardImageReference(reference),
              let data = try? Data(contentsOf: directory.appendingPathComponent(name + Self.attributionSuffix)) else { return nil }
        return try? JSONDecoder().decode(ImageAttribution.self, from: data)
    }

    /// Deletes every stored picture whose reference is not in `referenced`, with its attribution record. Returns the removed file names.
    @discardableResult
    func removeUnreferenced(keeping referenced: Set<String>) -> [String] {
        let kept = Set(referenced.compactMap { raw -> String? in
            if case .local(let name) = CardImageReference(raw) { return name }
            return nil
        })
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        var removed: [String] = []
        for name in files {
            let owner = name.hasSuffix(Self.attributionSuffix) ? String(name.dropLast(Self.attributionSuffix.count)) : name
            guard !kept.contains(owner) else { continue }
            if (try? fileManager.removeItem(at: directory.appendingPathComponent(name))) != nil { removed.append(name) }
        }
        return removed
    }

    /// JPEG has no alpha: composite transparent PNG/GIF/WebP on white so they do not turn black.
    private static func flattened(_ image: CGImage) -> CGImage {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipFirst, image.alphaInfo != .noneSkipLast else { return image }
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
