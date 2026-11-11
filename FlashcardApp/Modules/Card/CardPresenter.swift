//
//  CardPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation
import RxSwift

/// How the library orders decks. Persisted so the choice survives a relaunch.
enum CardLibrarySort: String, CaseIterable {
    case recent
    case name
    case cardCount

    var title: String {
        switch self {
        case .recent: return NSLocalizedString("Recently created", comment: "Deck sort option")
        case .name: return NSLocalizedString("Name", comment: "Deck sort option")
        case .cardCount: return NSLocalizedString("Most cards", comment: "Deck sort option")
        }
    }
}

/// Everything a deck row shows; plain values so the view never touches entities or Realm.
struct DeckRowModel: Equatable {
    let id: String
    let title: String
    /// The deck's own description, empty when none was written.
    let details: String
    /// First few fronts, e.g. "犬 · 猫 · 鳥 …": a glance at what is inside.
    let preview: String
    let cardCount: Int
    let direction: LanguageSortingType
    /// Large mark of the row: the first character of the first card (or of the name for an empty deck).
    let monogram: String
    let hasImages: Bool
}

/// The sections of the Cards tab, in the order the website lists them. Only `mine` works without an account.
enum CardLibraryScope: String, CaseIterable {
    case review
    case mine
    case publicDecks
    case recent

    var title: String {
        switch self {
        case .review: return NSLocalizedString("Review", comment: "Cards tab section: cards due for review")
        case .mine: return NSLocalizedString("My decks", comment: "Cards tab section")
        case .publicDecks: return NSLocalizedString("Public", comment: "Cards tab section: decks shared by everyone")
        case .recent: return NSLocalizedString("Recent", comment: "Cards tab section: recently changed decks")
        }
    }

    var needsAccount: Bool { self != .mine }
}

/// A deck of the account in a list. Plain values, like `DeckRowModel`.
struct RemoteDeckRowModel: Equatable {
    let id: String
    let title: String
    let details: String
    let cardCount: Int
    let visibility: ServerDeckVisibility
    let isOwned: Bool
    /// A copy of this deck is already stored on the device.
    let isOnDevice: Bool
    let updatedAt: Date?
    /// Large mark of the row: the first character of the title.
    let monogram: String
}

/// A list that comes from the server: it can still be loading, need an account or have failed, unlike the local one.
enum RemoteListContent: Equatable {
    case loading
    case signInRequired
    case failed(String)
    /// Nothing to show for this section (not because of a search).
    case empty
    case noMatches(query: String)
    case decks([RemoteDeckRowModel])
}

struct ReviewEntryModel: Equatable {
    enum Phase: Equatable {
        case loading
        case signInRequired
        case failed(String)
        /// `capped`: the server returned a full batch, so more may be due than `due`.
        case ready(due: Int, capped: Bool)
    }

    var phase: Phase
}

enum CardLibraryContent: Equatable {
    /// No deck exists yet.
    case empty
    /// Decks exist but none matches the search.
    case noMatches(query: String)
    case decks([DeckRowModel])
    case review(ReviewEntryModel)
    case remote(RemoteListContent)
}

struct CardLibraryState: Equatable {
    var content: CardLibraryContent
    var sort: CardLibrarySort
    var deckCount: Int
    var scope: CardLibraryScope = .mine
    /// Cards due for review right now, once known (shown on the "Review" section).
    var reviewDueCount: Int?
    /// "My decks" only: the account's own decks that are not on this device. `nil` hides the section (signed out, or not loaded yet).
    var accountDecks: RemoteListContent?
}

protocol CardViewInterface: AnyObject {
    func render(_ state: CardLibraryState)
}

protocol CardPresenterInterface: AnyObject {
    var sort: CardLibrarySort { get }
    var scope: CardLibraryScope { get }

    func viewWillAppear()
    func selectScope(_ scope: CardLibraryScope)
    /// Loads the section again from the server (pull to refresh, or "Try again").
    func refresh()
    func startReview()
    /// Opens the list of cards the learner keeps getting wrong on this device.
    func showOftenMissed()
    func openAccountDeck(id: String)
    func signIn()
    func updateQuery(_ query: String?)
    func setSort(_ sort: CardLibrarySort)
    func createDeck()
    func studyDeck(id: String)
    func editDeck(id: String)
    func requestDelete(id: String)
    /// The account deck made from this device deck, when it was saved to the account.
    func accountDeckId(forDeck id: String) -> String?
    /// Copies a device deck, with its pictures, to the learner's account.
    func uploadDeck(id: String)
}

class CardPresenter {
    static let sortKey = "com.flashcardapp.cards.librarySort"
    private static let previewCount = 3
    /// Server data younger than this is shown as it is when the tab appears again.
    static let staleAfter: TimeInterval = 60
    static let recentLimit = 24

    private enum Load<Value> {
        case idle
        case loading
        case loaded(Value, at: Date)
        case failed(String)
        case signInRequired

        var value: Value? {
            if case .loaded(let value, _) = self { return value }
            return nil
        }
    }

    private let interactor: CardInteractorInterface
    private let deskInteractor: DeskInteractorInterface
    private let server: CardLibraryServerInteractorInterface
    private let publisher: DeckPublishInteractorInterface
    private let wireframe: CardWireframeInterface
    private let defaults: UserDefaults
    private let now: () -> Date
    weak var view: CardViewInterface?

    private var query = ""
    private(set) var sort: CardLibrarySort
    private(set) var scope: CardLibraryScope = .mine

    private var decksLoad: Load<[ServerDeck]> = .idle
    private var dueLoad: Load<[DueCard]> = .idle
    /// Whose data is cached: a different account must never see the previous one's decks or due cards.
    private var cachedAccount: String?
    /// Something the learner did on another screen (reviewing, saving, archiving) changed the server data.
    private var decksChanged = false
    private var dueChanged = false
    private let decksRequest = SerialDisposable()
    private let dueRequest = SerialDisposable()
    private let uploadRequest = SerialDisposable()

    init(interactor: CardInteractorInterface,
         deskInteractor: DeskInteractorInterface,
         wireframe: CardWireframeInterface,
         defaults: UserDefaults = .standard,
         server: CardLibraryServerInteractorInterface = CardLibraryServerInteractor(),
         publisher: DeckPublishInteractorInterface = DeckPublishInteractor(),
         now: @escaping () -> Date = Date.init) {
        self.interactor = interactor
        self.deskInteractor = deskInteractor
        self.wireframe = wireframe
        self.defaults = defaults
        self.server = server
        self.publisher = publisher
        self.now = now
        self.sort = defaults.string(forKey: Self.sortKey).flatMap(CardLibrarySort.init(rawValue:)) ?? .recent
    }

    deinit {
        decksRequest.dispose()
        dueRequest.dispose()
        uploadRequest.dispose()
    }

    private func reload() {
        var state = Self.makeState(desks: deskInteractor.desks, query: query, sort: sort)
        state.scope = scope
        state.reviewDueCount = dueLoad.value?.count
        switch scope {
        case .mine: state.accountDecks = accountSection()
        case .review: state.content = .review(reviewEntry())
        case .publicDecks, .recent: state.content = .remote(remoteList(for: scope))
        }
        view?.render(state)
    }

    // MARK: Server data

    private func resetCachesIfAccountChanged() {
        let account = server.accountId
        guard account != cachedAccount else { return }
        cachedAccount = account
        decksLoad = .idle
        dueLoad = .idle
        decksRequest.disposable = Disposables.create()
        dueRequest.disposable = Disposables.create()
    }

    /// Starts whatever the visible section (and the Review badge) needs and is missing or old.
    private func loadServerData(force: Bool = false) {
        resetCachesIfAccountChanged()
        loadDue(force: force || dueChanged)
        if scope != .review { loadDecks(force: force || decksChanged) }
        dueChanged = false
        if scope != .review { decksChanged = false }
        reload()
    }

    private func isFresh<Value>(_ load: Load<Value>) -> Bool {
        switch load {
        case .loading: return true
        case .loaded(_, let at): return now().timeIntervalSince(at) < Self.staleAfter
        default: return false
        }
    }

    private func loadDecks(force: Bool) {
        guard server.isSignedIn else { decksLoad = .signInRequired; return }
        if !force, isFresh(decksLoad) { return }
        let hadData = decksLoad.value != nil
        if !hadData { decksLoad = .loading }
        decksRequest.disposable = server.decks()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] decks in
                guard let self else { return }
                self.decksLoad = .loaded(decks, at: self.now())
                self.reload()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.signInRequired = error { self.decksLoad = .signInRequired } else if case LearnerAPIError.staleSession = error {
                    self.decksLoad = .idle
                } else if hadData {
                    // Keep what is on screen and say that it could not be refreshed.
                    self.wireframe.showAlert(with: NSLocalizedString("Error", comment: ""), message: Self.message(for: error))
                } else {
                    self.decksLoad = .failed(Self.message(for: error))
                }
                self.reload()
            })
        if !hadData { reload() }
    }

    private func loadDue(force: Bool) {
        guard server.isSignedIn else { dueLoad = .signInRequired; return }
        if !force, isFresh(dueLoad) { return }
        let hadData = dueLoad.value != nil
        if !hadData { dueLoad = .loading }
        dueRequest.disposable = server.dueCards(limit: CardReviewPresenter.batchSize)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] cards in
                guard let self else { return }
                self.dueLoad = .loaded(cards, at: self.now())
                self.reload()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.signInRequired = error { self.dueLoad = .signInRequired } else if case LearnerAPIError.staleSession = error {
                    self.dueLoad = .idle
                } else if hadData {
                    self.wireframe.showAlert(with: NSLocalizedString("Error", comment: ""), message: Self.message(for: error))
                } else {
                    self.dueLoad = .failed(Self.message(for: error))
                }
                self.reload()
            })
        if !hadData { reload() }
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func reviewEntry() -> ReviewEntryModel {
        switch dueLoad {
        case .idle, .loading: return ReviewEntryModel(phase: .loading)
        case .signInRequired: return ReviewEntryModel(phase: .signInRequired)
        case .failed(let message): return ReviewEntryModel(phase: .failed(message))
        case .loaded(let cards, _):
            return ReviewEntryModel(phase: .ready(due: cards.count, capped: cards.count >= CardReviewPresenter.batchSize))
        }
    }

    private func remoteList(for scope: CardLibraryScope) -> RemoteListContent {
        switch decksLoad {
        case .idle, .loading: return .loading
        case .signInRequired: return .signInRequired
        case .failed(let message): return .failed(message)
        case .loaded(let decks, _):
            let newestFirst = { (lhs: ServerDeck, rhs: ServerDeck) -> Bool in
                (lhs.updatedAt ?? .distantPast, rhs.title) > (rhs.updatedAt ?? .distantPast, lhs.title)
            }
            let base: [ServerDeck]
            switch scope {
            case .publicDecks: base = decks.filter { $0.visibility == .public && !$0.isOwned }.sorted(by: newestFirst)
            case .recent: base = Array(decks.sorted(by: newestFirst).prefix(Self.recentLimit))
            default: base = []
            }
            guard !base.isEmpty else { return .empty }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matching = trimmed.isEmpty ? base : base.filter { Self.matches($0, query: trimmed) }
            return matching.isEmpty ? .noMatches(query: trimmed) : .decks(matching.map(row(for:)))
        }
    }

    private func accountSection() -> RemoteListContent? {
        guard server.isSignedIn else { return nil }
        switch decksLoad {
        case .failed(let message): return .failed(message)
        case .loaded(let decks, _):
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let rows = decks.filter { $0.isOwned && !server.hasDeviceCopy(deckId: $0.id) && (trimmed.isEmpty || Self.matches($0, query: trimmed)) }
            return rows.isEmpty ? nil : .decks(rows.map(row(for:)))
        default: return nil
        }
    }

    private func row(for deck: ServerDeck) -> RemoteDeckRowModel {
        RemoteDeckRowModel(id: deck.id, title: deck.title, details: deck.details, cardCount: deck.cardCount, visibility: deck.visibility,
                           isOwned: deck.isOwned, isOnDevice: server.hasDeviceCopy(deckId: deck.id), updatedAt: deck.updatedAt,
                           monogram: deck.title.first.map { String($0).uppercased() } ?? "札")
    }

    private static func matches(_ deck: ServerDeck, query: String) -> Bool {
        deck.title.localizedStandardContains(query) || deck.details.localizedStandardContains(query)
    }

    // MARK: State building (pure)

    static func makeState(desks: [DeskEntity], query: String, sort: CardLibrarySort) -> CardLibraryState {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desks.isEmpty else { return CardLibraryState(content: .empty, sort: sort, deckCount: 0) }
        let matching = trimmed.isEmpty ? desks : desks.filter { matches($0, query: trimmed) }
        guard !matching.isEmpty else {
            return CardLibraryState(content: .noMatches(query: trimmed), sort: sort, deckCount: desks.count)
        }
        return CardLibraryState(content: .decks(sorted(matching, by: sort).map(row(for:))), sort: sort, deckCount: desks.count)
    }

    private static func matches(_ desk: DeskEntity, query: String) -> Bool {
        if desk.name.localizedStandardContains(query) || desk.description.localizedStandardContains(query) { return true }
        return desk.cards.contains {
            $0.frontText.localizedStandardContains(query) || $0.backText.localizedStandardContains(query)
                || $0.frontExtraText.localizedStandardContains(query)
        }
    }

    private static func sorted(_ desks: [DeskEntity], by sort: CardLibrarySort) -> [DeskEntity] {
        switch sort {
        case .recent: return desks.sorted { $0.date > $1.date }
        case .name: return desks.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .cardCount:
            return desks.sorted {
                $0.cards.count != $1.cards.count ? $0.cards.count > $1.cards.count
                    : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }

    static func row(for desk: DeskEntity) -> DeckRowModel {
        let fronts = desk.cards.prefix(previewCount).map(\.frontText).filter { !$0.isEmpty }
        var preview = fronts.joined(separator: " · ")
        if desk.cards.count > previewCount, !preview.isEmpty { preview += " …" }
        let monogramSource = desk.cards.first?.frontText.nonEmpty ?? desk.name
        return DeckRowModel(id: desk.id, title: desk.name, details: desk.description, preview: preview,
                            cardCount: desk.cards.count, direction: desk.sortingLanguage,
                            monogram: monogramSource.first.map { String($0).uppercased() } ?? "札",
                            hasImages: desk.cards.contains { !$0.imageUrl.isEmpty })
    }
}

private extension String {
    var nonEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

extension CardPresenter: CardPresenterInterface {

    func viewWillAppear() {
        reload()
        loadServerData()
    }

    func selectScope(_ scope: CardLibraryScope) {
        guard self.scope != scope else { return }
        self.scope = scope
        // The search belongs to the list being looked at: it does not follow the learner to the Review section.
        if scope == .review { query = "" }
        reload()
        loadServerData()
    }

    func refresh() {
        resetCachesIfAccountChanged()
        switch scope {
        case .review: loadDue(force: true)
        case .mine, .publicDecks, .recent:
            loadDecks(force: true)
            if scope != .mine { loadDue(force: dueChanged) }
        }
        reload()
    }

    func showOftenMissed() {
        wireframe.showOftenMissed()
    }

    func startReview() {
        guard let cards = dueLoad.value, !cards.isEmpty else { return refresh() }
        dueChanged = true
        wireframe.showReview(cards: cards)
    }

    func openAccountDeck(id: String) {
        decksChanged = true
        wireframe.showRemoteDeck(deckId: id)
    }

    func signIn() {
        wireframe.showSignIn { [weak self] in
            guard let self else { return }
            self.resetCachesIfAccountChanged()
            self.loadServerData(force: true)
            self.reload()
        }
    }

    func updateQuery(_ query: String?) {
        self.query = query ?? ""
        reload()
    }

    func setSort(_ sort: CardLibrarySort) {
        self.sort = sort
        defaults.set(sort.rawValue, forKey: Self.sortKey)
        reload()
    }

    func createDeck() {
        wireframe.showNewDeckOptions { [weak self] method in
            guard let self else { return }
            switch method {
            case .manual:
                self.wireframe.showEditor(deckId: nil) { [weak self] in self?.reload() }
            case .automatic:
                self.wireframe.showDeckGenerator { [weak self] deckId in
                    guard let self else { return }
                    // The deck is already stored on the device: list it, then open it for review and editing.
                    self.reload()
                    self.wireframe.showEditor(deckId: deckId) { [weak self] in self?.reload() }
                }
            }
        }
    }

    func studyDeck(id: String) {
        guard deskInteractor.desk(withId: id) != nil else { return reload() }
        wireframe.showStudy(deckId: id)
    }

    func editDeck(id: String) {
        guard deskInteractor.desk(withId: id) != nil else { return reload() }
        wireframe.showEditor(deckId: id) { [weak self] in self?.reload() }
    }

    func requestDelete(id: String) {
        guard let desk = deskInteractor.desk(withId: id) else { return reload() }
        wireframe.confirmDelete(deckName: desk.name) { [weak self] in
            guard let self else { return }
            do {
                try self.deskInteractor.deleteDesk(withId: id)
            } catch {
                self.wireframe.showAlert(with: NSLocalizedString("Error", comment: ""),
                                         message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            self.reload()
        }
    }

    func accountDeckId(forDeck id: String) -> String? { publisher.accountDeckId(forDevice: id) }

    func uploadDeck(id: String) {
        guard let desk = deskInteractor.desk(withId: id) else { return reload() }
        guard publisher.isSignedIn else {
            return wireframe.showSignIn { [weak self] in self?.uploadDeck(id: id) }
        }
        guard publisher.accountDeckId(forDevice: id) == nil else {
            return wireframe.showAlert(with: nil, message: DeckPublishError.alreadySaved.errorDescription)
        }
        wireframe.confirmUpload(deckName: desk.name, cardCount: desk.cards.count, pictureCount: publisher.pictureCount(ofDeck: id)) { [weak self] in
            self?.startUpload(deckId: id)
        }
    }

    private func startUpload(deckId: String) {
        var creating = false
        wireframe.showUploadProgress(message: NSLocalizedString("Preparing…", comment: "Saving a deck to the account"),
                                     onCancel: { [weak self] in self?.uploadRequest.disposable = Disposables.create() })
        uploadRequest.disposable = publisher.publish(deckId: deckId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] update in
                guard let self else { return }
                switch update {
                case .uploading(let done, let total):
                    self.wireframe.showUploadProgress(
                        message: String(format: NSLocalizedString("Uploading pictures… %1$lld of %2$lld", comment: ""), done, total),
                        onCancel: { [weak self] in self?.uploadRequest.disposable = Disposables.create() })
                case .creating:
                    creating = true
                    // Past this point a cancel would leave it unknown whether the deck was created.
                    self.wireframe.showUploadProgress(message: NSLocalizedString("Saving the deck…", comment: ""), onCancel: nil)
                case .finished(let report):
                    self.finishUpload(title: NSLocalizedString("Saved to your account", comment: ""), message: Self.summary(of: report), refresh: true)
                }
            }, onError: { [weak self] error in
                var message = Self.uploadMessage(for: error)
                if creating, case LearnerAPIError.interrupted = error {
                    message = NSLocalizedString("The connection was interrupted. The deck may already be on your account: check “On your account” before saving it again.", comment: "")
                }
                self?.finishUpload(title: NSLocalizedString("Couldn't save the deck", comment: ""), message: message, refresh: creating)
            })
    }

    private func finishUpload(title: String, message: String, refresh shouldRefresh: Bool) {
        wireframe.hideUploadProgress { [weak self] in
            self?.wireframe.showAlert(with: title, message: message)
        }
        if shouldRefresh {
            decksChanged = true
            refresh()
        }
    }

    static func uploadMessage(for error: Error) -> String {
        if let error = error as? DeckPublishError { return error.errorDescription ?? error.localizedDescription }
        return message(for: error)
    }

    static func summary(of report: DeckPublishReport) -> String {
        var lines = [String.localizedStringWithFormat(NSLocalizedString("%lld cards saved as a private deck.", comment: ""), report.cardCount)]
        let pictures = report.uploaded + report.reused
        if pictures > 0 {
            lines.append(String.localizedStringWithFormat(NSLocalizedString("%lld pictures saved with the cards.", comment: ""), pictures))
        }
        if report.skipped > 0 {
            lines.append(String.localizedStringWithFormat(NSLocalizedString("%lld pictures were left out because they were missing or too large.", comment: ""), report.skipped))
        }
        return lines.joined(separator: "\n")
    }
}
