import Foundation

protocol OftenMissedInteractorInterface: AnyObject {
    /// The learner's often-missed cards on this device. Throws when the saved history cannot be read: the learner is told, never shown an empty list.
    func queue(ownerKey: String) throws -> [OftenMissedCard]
}

final class OftenMissedInteractor: OftenMissedInteractorInterface {
    private let decks: DeskRepositoryInterface
    private let schedules: ReviewScheduleStoreInterface

    init(decks: DeskRepositoryInterface = DeskManagement.shared, schedules: ReviewScheduleStoreInterface = RealmReviewHistoryStore()) {
        self.decks = decks
        self.schedules = schedules
    }

    func queue(ownerKey: String) throws -> [OftenMissedCard] {
        // The schedules are derived from the saved attempts: make sure they exist before reading them, as Today does.
        try schedules.ensureSchedules(ownerKey: ownerKey)
        let missedDecks = decks.getAll().map { OftenMissedDeck(id: $0.id, name: $0.name, cards: $0.cards.map(StudyCard.init(entity:))) }
        return OftenMissedQueue.build(decks: missedDecks, schedules: schedules.schedules(ownerKey: ownerKey))
    }
}
