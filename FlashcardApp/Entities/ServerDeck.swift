//
//  ServerDeck.swift
//  FlashcardApp
//
//  Value types for the decks and due cards that live on the learner's account (the website's library),
//  as opposed to `DeskEntity`, which is a deck stored on this device.
//

import Foundation

/// How a learner judged a card they were due to review. The raw values are the server's.
enum ReviewRating: String, CaseIterable, Equatable {
    case again, hard, good, easy

    /// "Good" and "easy" count as remembered; "hard" keeps the streak going but is not a clean recall.
    var isRemembered: Bool { self == .good || self == .easy }
}

enum ServerDeckVisibility: String, Equatable {
    case `private`, `public`
}

/// The picture of a card that lives on the learner's account (`primaryImage` of the deck and review payloads).
/// Only an address the app may load is kept: https, or the API's own `/api/media/...` path resolved against the
/// configured API address (which is also the only host the session token is ever sent to).
struct CardPicture: Equatable {
    let url: URL
    let attribution: ImageAttribution?

    /// The value stored on a card / handed to `CardImageView`.
    var reference: String { url.absoluteString }
    var credit: String { attribution?.creditLine ?? "" }

    /// `nil` when the card has no picture the app can show. `apiBase` is the configured API address (`…/api`).
    static func make(_ dto: BJTCardImageDTO?, apiBase: String = EnvironmentConfig.baseUrl()) -> CardPicture? {
        guard let dto, let raw = dto.readUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = resolve(raw, apiBase: apiBase) else { return nil }
        return CardPicture(url: url, attribution: attribution(of: dto, url: url))
    }

    private static func resolve(_ raw: String, apiBase: String) -> URL? {
        if raw.hasPrefix("/api/media/") {
            guard let base = URL(string: apiBase), var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
            components.path = ""
            components.query = nil
            return URL(string: raw, relativeTo: components.url)?.absoluteURL
        }
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host?.isEmpty == false, url.user == nil else { return nil }
        return url
    }

    private static func attribution(of dto: BJTCardImageDTO, url: URL) -> ImageAttribution? {
        func secure(_ raw: String?) -> String? {
            guard let raw, let link = URL(string: raw), link.scheme?.lowercased() == "https", link.host?.isEmpty == false else { return nil }
            return raw
        }
        let author = dto.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let provider = dto.provider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !provider.isEmpty, !author.isEmpty else { return nil }
        return ImageAttribution(source: provider, imageURL: url.absoluteString, sourceURL: secure(dto.sourceUrl), author: author,
                                authorURL: secure(dto.authorUrl), license: dto.license, licenseURL: secure(dto.licenseUrl))
    }
}

/// A deck of the account: the learner's own, or a public deck of someone else.
struct ServerDeck: Equatable, Identifiable {
    let id: String
    let title: String
    let details: String
    let visibility: ServerDeckVisibility
    /// The server only reveals the owner of the caller's own decks.
    let isOwned: Bool
    let cardCount: Int
    let updatedAt: Date?

    init(id: String, title: String, details: String = "", visibility: ServerDeckVisibility = .private, isOwned: Bool,
         cardCount: Int, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.visibility = visibility
        self.isOwned = isOwned
        self.cardCount = cardCount
        self.updatedAt = updatedAt
    }
}

struct ServerDeckCard: Equatable, Identifiable {
    /// The `deck_card` row id, unique inside the deck; the local deck uses it as its card id when saved.
    let id: String
    let front: String
    let back: String
    let reading: String
    var picture: CardPicture? = nil
}

struct ServerDeckDetail: Equatable {
    let deck: ServerDeck
    let cards: [ServerDeckCard]
}

/// A card the schedule says is due.
struct DueCard: Equatable, Identifiable {
    enum State: String, Equatable {
        case new, learning, review, lapsed
    }

    /// The scheduling row; a rating is posted against it.
    let id: String
    let state: State
    let front: String
    let back: String
    let reading: String
    let lapses: Int
    let isLeech: Bool
    var picture: CardPicture? = nil
}

enum ServerDeckMapper {
    /// Backend text that exists in several languages follows the app language; Japanese falls back to the Vietnamese text.
    static func deck(from dto: BJTDeckSummaryDTO, language: AppLanguage = .current) -> ServerDeck {
        make(id: dto.id, owned: dto.ownerUserId != nil, titleVi: dto.titleVi, titleJa: dto.titleJa, descriptionVi: dto.descriptionVi,
             descriptionJa: dto.descriptionJa, visibility: dto.visibility, cardCount: dto.cardCount, updatedAt: dto.updatedAt ?? dto.createdAt,
             language: language)
    }

    static func detail(from dto: BJTRemoteDeckDTO, language: AppLanguage = .current) -> ServerDeckDetail {
        let cards = dto.cards.sorted { ($0.position, $0.id) < ($1.position, $1.id) }.compactMap { entry -> ServerDeckCard? in
            let front = entry.card.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = entry.card.backText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty else { return nil }
            return ServerDeckCard(id: entry.id, front: front, back: back,
                                  reading: entry.card.reading?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                  picture: CardPicture.make(entry.card.primaryImage))
        }
        let deck = make(id: dto.id, owned: dto.ownerUserId != nil, titleVi: dto.titleVi, titleJa: dto.titleJa, descriptionVi: dto.descriptionVi,
                        descriptionJa: dto.descriptionJa, visibility: dto.visibility ?? "private", cardCount: cards.count, updatedAt: nil,
                        language: language)
        return ServerDeckDetail(deck: deck, cards: cards)
    }

    static func dueCard(from dto: BJTDueCardDTO) -> DueCard? {
        let front = dto.card.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = dto.card.backText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: dto.id) != nil, !front.isEmpty, !back.isEmpty else { return nil }
        return DueCard(id: dto.id, state: DueCard.State(rawValue: dto.state) ?? .review, front: front, back: back,
                       reading: dto.card.reading?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                       lapses: dto.lapses, isLeech: dto.leeched, picture: CardPicture.make(dto.primaryImage))
    }

    static func date(from iso: String?) -> Date? {
        guard let iso else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return fractional.date(from: iso) ?? plain.date(from: iso)
    }

    private static func make(id: String, owned: Bool, titleVi: String, titleJa: String?, descriptionVi: String?, descriptionJa: String?,
                             visibility: String, cardCount: Int, updatedAt: String?, language: AppLanguage) -> ServerDeck {
        let japanese = language == .japanese
        let title = (japanese ? titleJa?.nonBlank : nil) ?? titleVi
        let details = (japanese ? descriptionJa?.nonBlank : nil) ?? descriptionVi?.nonBlank ?? ""
        return ServerDeck(id: id, title: title, details: details, visibility: ServerDeckVisibility(rawValue: visibility) ?? .private,
                          isOwned: owned, cardCount: max(cardCount, 0), updatedAt: date(from: updatedAt))
    }
}

private extension String {
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
