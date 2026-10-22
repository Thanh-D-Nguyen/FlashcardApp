//
//  CardPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation

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

enum CardLibraryContent: Equatable {
    /// No deck exists yet.
    case empty
    /// Decks exist but none matches the search.
    case noMatches(query: String)
    case decks([DeckRowModel])
}

struct CardLibraryState: Equatable {
    var content: CardLibraryContent
    var sort: CardLibrarySort
    var deckCount: Int
}

protocol CardViewInterface: AnyObject {
    func render(_ state: CardLibraryState)
}

protocol CardPresenterInterface: AnyObject {
    var sort: CardLibrarySort { get }

    func viewWillAppear()
    func updateQuery(_ query: String?)
    func setSort(_ sort: CardLibrarySort)
    func createDeck()
    func studyDeck(id: String)
    func editDeck(id: String)
    func requestDelete(id: String)
}

class CardPresenter {
    static let sortKey = "com.flashcardapp.cards.librarySort"
    private static let previewCount = 3

    private let interactor: CardInteractorInterface
    private let deskInteractor: DeskInteractorInterface
    private let wireframe: CardWireframeInterface
    private let defaults: UserDefaults
    weak var view: CardViewInterface?

    private var query = ""
    private(set) var sort: CardLibrarySort

    init(interactor: CardInteractorInterface,
         deskInteractor: DeskInteractorInterface,
         wireframe: CardWireframeInterface,
         defaults: UserDefaults = .standard) {
        self.interactor = interactor
        self.deskInteractor = deskInteractor
        self.wireframe = wireframe
        self.defaults = defaults
        self.sort = defaults.string(forKey: Self.sortKey).flatMap(CardLibrarySort.init(rawValue:)) ?? .recent
    }

    private func reload() {
        view?.render(Self.makeState(desks: deskInteractor.desks, query: query, sort: sort))
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
        wireframe.showEditor(deckId: nil) { [weak self] in self?.reload() }
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
}
