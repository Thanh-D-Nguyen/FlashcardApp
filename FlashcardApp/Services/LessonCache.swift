import Foundation

enum LessonCacheError: Error, Equatable {
    case invalidSlug
    /// The bytes are not a valid lesson with that slug, so they are never stored as one.
    case invalidPayload
}

protocol LessonCacheInterface: AnyObject {
    /// The stored copy, or nil when there is none or it can no longer be trusted.
    func lesson(slug: String) -> BJTLessonDetailDTO?
    func store(payload: Data, slug: String) throws
}

/// Lessons the learner has opened, kept for reading offline. Only the server's own bytes are stored, in a versioned
/// envelope, one file per slug. Nothing here is ever a credential: lessons are fetched anonymously.
final class LessonCache: LessonCacheInterface {
    static let shared = LessonCache()
    static let envelopeVersion = 1

    private struct Envelope: Codable {
        let version: Int
        let slug: String
        let savedAt: Date?
        let payload: Data
    }

    private let directory: URL
    private let fileManager = FileManager.default

    /// `directory` defaults to `Application Support/Lessons`; tests pass a temporary one.
    init(directory: URL? = nil) {
        self.directory = directory
            ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory).appendingPathComponent("Lessons", isDirectory: true)
    }

    func lesson(slug: String) -> BJTLessonDetailDTO? {
        guard BJTLessonAPI.isValid(slug: slug), let data = try? Data(contentsOf: file(for: slug)) else { return nil }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            // Not an envelope at all: it can never become readable, so it does not keep occupying the slot.
            try? fileManager.removeItem(at: file(for: slug))
            return nil
        }
        guard envelope.version == Self.envelopeVersion, envelope.slug == slug,
              let lesson = try? JSONDecoder().decode(BJTLessonDetailDTO.self, from: envelope.payload),
              lesson.slug == slug else { return nil }
        return lesson
    }

    func store(payload: Data, slug: String) throws {
        guard BJTLessonAPI.isValid(slug: slug) else { throw LessonCacheError.invalidSlug }
        guard let lesson = try? JSONDecoder().decode(BJTLessonDetailDTO.self, from: payload), lesson.slug == slug else {
            throw LessonCacheError.invalidPayload
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let envelope = Envelope(version: Self.envelopeVersion, slug: slug, savedAt: Date(), payload: payload)
        var target = file(for: slug)
        // Atomic: a crash mid-write leaves the previous copy, never a half-written one.
        try JSONEncoder().encode(envelope).write(to: target, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    private func file(for slug: String) -> URL { directory.appendingPathComponent(slug + ".json") }
}
