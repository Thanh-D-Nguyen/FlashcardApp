import Foundation

struct OftenMissedRow: Equatable {
    let cardID: String
    let deckID: String
    let front: String
    let reading: String
    let back: String
    let deckName: String
    /// "Missed 3 times in 7 answers", with the real numbers.
    let detail: String
}

enum OftenMissedState: Equatable {
    case idle
    case empty
    case failed(String)
    case rows([OftenMissedRow])
}

protocol OftenMissedPresenterInterface: AnyObject {
    var state: OftenMissedState { get }
    var onChange: (() -> Void)? { get set }
    func viewWillAppear()
    func retry()
    /// Opens the deck of this row for study; only that: the list never starts a review by itself.
    func selectRow(at index: Int)
}

protocol OftenMissedWireframeInterface: AnyObject {
    func showStudy(deckId: String)
}

final class OftenMissedPresenter: OftenMissedPresenterInterface {
    private let interactor: OftenMissedInteractorInterface
    private let ownerKey: () -> String

    private(set) var state: OftenMissedState = .idle
    var onChange: (() -> Void)?
    /// Held strongly: nothing else keeps the wireframe alive once its controller is pushed.
    var wireframe: OftenMissedWireframeInterface?

    init(interactor: OftenMissedInteractorInterface, ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" }) {
        self.interactor = interactor
        self.ownerKey = ownerKey
    }

    /// Read again every time the screen appears: answers given since the last visit change the list.
    func viewWillAppear() { load() }

    func retry() { load() }

    func selectRow(at index: Int) {
        guard case .rows(let rows) = state, rows.indices.contains(index) else { return }
        wireframe?.showStudy(deckId: rows[index].deckID)
    }

    private func load() {
        do {
            let cards = try interactor.queue(ownerKey: ownerKey())
            state = cards.isEmpty ? .empty : .rows(cards.map(Self.row(for:)))
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        onChange?()
    }

    private static func row(for card: OftenMissedCard) -> OftenMissedRow {
        OftenMissedRow(cardID: card.cardID, deckID: card.deckID, front: card.front, reading: card.reading, back: card.back, deckName: card.deckName,
                       detail: String.localizedStringWithFormat(NSLocalizedString("Missed %1$lld times in %2$lld answers", comment: "Often-missed card: wrong answers after the first, and all answers"),
                                                                card.lapses, card.answers))
    }
}
