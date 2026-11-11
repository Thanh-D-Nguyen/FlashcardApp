import Foundation

/// What Today shows of a Daily Radar card, and what its detail screen shows. Every text is the server's own; nothing is added.
struct DailyRadarItem: Equatable {
    let id: String
    let slug: String
    let moduleTitle: String
    let title: String
    let summary: String?
    let expressions: [BJTRadarCardDTO.Expression]
    let usageNote: String?
    let reason: String?
    let minutes: Int?
    let level: String?
}

/// Chooses the one Radar card of the day. Production cards are all seeded editorial content, so cards of modules that read as
/// current news (`news_bjt`, `market_watch`, `weather_japanese`, `japan_today`) are left out unless the server marks them as not seeded:
/// an October seed must not be shown as today's news. "Coming soon" cards and cards without a Japanese expression to learn are
/// left out too. The card opens in the app (the website routes in `targetRoute` do not exist here).
enum DailyRadarPicker {
    static let timeSensitiveModules: Set<String> = ["news_bjt", "market_watch", "weather_japanese", "japan_today"]

    static func item(from card: BJTRadarCardDTO, language: AppLanguage) -> DailyRadarItem? {
        let metadata = card.metadata
        guard metadata?.comingSoon != true else { return nil }
        if timeSensitiveModules.contains(card.module.moduleKey), metadata?.seed != false { return nil }
        let expressions = (metadata?.japaneseExpressions ?? []).filter { !$0.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let title = (language == .japanese ? card.titleJa.nonEmpty : nil) ?? card.titleVi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expressions.isEmpty, !title.isEmpty, !card.slug.isEmpty else { return nil }
        let moduleTitle = (language == .japanese ? card.module.titleJa.nonEmpty : nil) ?? card.module.titleVi.nonEmpty ?? ""
        return DailyRadarItem(id: card.id, slug: card.slug, moduleTitle: moduleTitle, title: title, summary: card.descriptionVi.nonEmpty,
                              expressions: expressions, usageNote: metadata?.usageNote.nonEmpty, reason: card.recommendationReasonVi.nonEmpty,
                              minutes: card.estimatedMinutes.flatMap { $0 > 0 ? $0 : nil }, level: card.levelLabel.nonEmpty)
    }

    /// The same card all day, another one the next day: the usable cards in slug order, indexed by the learner's day number.
    static func pick(_ cards: [BJTRadarCardDTO], on date: Date, calendar: Calendar, language: AppLanguage) -> DailyRadarItem? {
        let items = cards.compactMap { item(from: $0, language: language) }.sorted { $0.slug < $1.slug }
        guard !items.isEmpty else { return nil }
        let start = calendar.startOfDay(for: date)
        let epoch = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let day = calendar.dateComponents([.day], from: epoch, to: start).day ?? 0
        return items[((day % items.count) + items.count) % items.count]
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nonEmpty: String? { Optional(self).nonEmpty }
}

protocol DailyRadarCacheInterface: AnyObject {
    func load() -> (data: Data, savedAt: Date)?
    func save(_ data: Data, at date: Date) throws
}

/// The last answer of the list, as the server sent it, with when it arrived. One small file; nothing else is cached.
final class FileDailyRadarCache: DailyRadarCacheInterface {
    static let shared = FileDailyRadarCache()

    private struct Envelope: Codable {
        let version: Int
        let savedAt: Date
        let payload: Data
    }

    private let url: URL

    init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        url = base.appendingPathComponent("DailyRadar", isDirectory: true).appendingPathComponent("cards.json")
    }

    func load() -> (data: Data, savedAt: Date)? {
        guard let raw = try? Data(contentsOf: url), let envelope = try? JSONDecoder().decode(Envelope.self, from: raw), envelope.version == 1 else { return nil }
        return (envelope.payload, envelope.savedAt)
    }

    func save(_ data: Data, at date: Date) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Envelope(version: 1, savedAt: date, payload: data)).write(to: url, options: [.atomic])
    }
}
