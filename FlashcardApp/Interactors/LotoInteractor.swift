//
//  LotoInteractor.swift
//
//  Loto: finds the next draw of each game among the public Loto articles and maps its number sets. Read-only.
//

import Foundation
import RxSwift

protocol LotoInteractorInterface: AnyObject {
    /// The next draw of each game. Fails when the list cannot be read; a game that has no article is left out.
    func load() -> Single<LotoOverview>
}

final class LotoInteractor: LotoInteractorInterface {
    static let listSize = 50

    private let api: BJTLotoAPIInterface
    private let now: () -> Date

    init(api: BJTLotoAPIInterface = BJTMagazineAPI.shared, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    func load() -> Single<LotoOverview> {
        let today = MagazineDay.today(now: now())
        return api.lotoArticles(page: 1, limit: Self.listSize).flatMap { [api] list in
            let items = Self.items(from: list)
            let next = LotoGame.allCases.compactMap { Self.nextItem(of: $0, in: items, today: today) }
            guard !next.isEmpty else { return .just(LotoOverview(draws: [])) }
            // One request per game. A game whose article cannot be read is left out when the other one can be shown.
            let loads: [Single<LotoDraw?>] = next.map { item in
                api.lotoArticle(slug: item.slug).map { Self.draw(from: $0, item: item) }.catchAndReturn(nil)
            }
            return Single.zip(loads).flatMap { draws in
                let found = draws.compactMap { $0 }
                return found.isEmpty ? .error(LearnerAPIError.invalidResponse) : .just(LotoOverview(draws: found))
            }
        }
    }

    // MARK: Mapping

    static func items(from list: BJTMagazineListDTO) -> [LotoListItem] {
        list.data.compactMap { dto in
            guard let game = LotoGame(widgetKind: dto.widgetKind), let day = MagazineDay(key: dto.publishDate), !dto.slug.isEmpty else { return nil }
            return LotoListItem(slug: dto.slug, game: game, day: day)
        }
    }

    /// The first draw of the game that has not happened yet (today counts), or the latest one when all are past.
    static func nextItem(of game: LotoGame, in items: [LotoListItem], today: MagazineDay) -> LotoListItem? {
        let own = items.filter { $0.game == game }.sorted { $0.day < $1.day }
        return own.first { !($0.day < today) } ?? own.last
    }

    static func draw(from dto: BJTLotoArticleDTO, item: LotoListItem, language: AppLanguage = .current) -> LotoDraw? {
        guard let content = dto.contentJson else { return nil }
        let sets = content.sets.compactMap { set -> LotoSet? in
            let main = set.mainNumbers.filter { (1...item.game.poolSize).contains($0) }
            // A set that is not a whole ticket is not shown: a half set would read as a real combination.
            guard main.count == item.game.pickCount, Set(main).count == main.count else { return nil }
            let explanation = set.explanation
            let shape = explanation?.shape.flatMap { shape -> LotoShape? in
                guard let odd = shape.odd, let even = shape.even, let low = shape.low, let high = shape.high, let sum = shape.sum else { return nil }
                return LotoShape(odd: odd, even: even, low: low, high: high, sum: sum, consecutivePairs: shape.consecutivePairs ?? 0)
            }
            let numbers = (explanation?.numbers ?? []).map {
                LotoNumber(number: $0.number, count: $0.count, gap: $0.gap, tags: $0.tags.compactMap(LotoTag.init(rawValue:)))
            }
            return LotoSet(rank: set.rank ?? 0, main: main.sorted(), bonus: set.bonusNumbers, score: set.score, shape: shape, numbers: numbers)
        }.sorted { $0.rank < $1.rank }
        guard !sets.isEmpty else { return nil }

        let signals = content.sets.first?.explanation?.signals
        let day = content.targetDrawDate.flatMap(MagazineDay.init(key:)) ?? item.day
        let weights = LotoWeightKind.allCases.compactMap { kind -> LotoWeight? in
            guard let value = content.algorithmWeights[kind.rawValue], value > 0 else { return nil }
            return LotoWeight(kind: kind, value: min(value, 1))
        }
        return LotoDraw(
            slug: item.slug, game: item.game, day: day, drawTime: content.drawTime ?? "",
            drawInstant: drawInstant(day: day, time: content.drawTime),
            drawNumber: content.drawNumber, drawNumberIsEstimate: content.drawNumberEstimated ?? false,
            sets: sets,
            signals: LotoSignals(hot: signals?.hotNumbers ?? [], cold: signals?.coldNumbers ?? [], overdue: signals?.overdueNumbers ?? []),
            weights: weights, historyDraws: content.sets.first?.explanation?.historyDraws,
            disclaimer: disclaimer(content.riskDisclaimer, language: language),
            officialURL: officialURL(content.source?.officialVerificationUrl),
            schedule: schedule(content, language: language))
    }

    /// "18:45 JST" on a day in Japan.
    static func drawInstant(day: MagazineDay, time: String?) -> Date? {
        guard let time else { return nil }
        let digits = time.split(separator: " ").first.map(String.init) ?? time
        let parts = digits.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return MagazineDay.japan.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))
    }

    /// The statement in the learner's language, falling back to the others. Never empty: the app's own sentence replaces a missing one,
    /// so the numbers are not shown without it.
    static func disclaimer(_ source: BJTLotoArticleDTO.Disclaimer?, language: AppLanguage) -> String {
        let preferred: [String?]
        switch language {
        case .vietnamese: preferred = [source?.vi, source?.en, source?.ja]
        case .japanese: preferred = [source?.ja, source?.en, source?.vi]
        default: preferred = [source?.en, source?.vi, source?.ja]
        }
        let text = preferred.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        return text ?? NSLocalizedString("Every valid number combination has the same chance. This content is for studying probability and Japanese, not a recommendation to buy lottery tickets.", comment: "Loto disclaimer")
    }

    /// Only an https link to the lottery operator's own site is opened.
    static func officialURL(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), url.scheme == "https", let host = url.host?.lowercased(),
              host == "mizuhobank.co.jp" || host.hasSuffix(".mizuhobank.co.jp") else { return nil }
        return url
    }

    private static func schedule(_ content: BJTLotoArticleDTO.Content, language: AppLanguage) -> String? {
        let preferred: [String?]
        switch language {
        case .vietnamese: preferred = [content.scheduleVi, content.scheduleEn]
        case .japanese: preferred = [content.scheduleJp, content.scheduleEn]
        default: preferred = [content.scheduleEn, content.scheduleVi]
        }
        return preferred.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }
}
