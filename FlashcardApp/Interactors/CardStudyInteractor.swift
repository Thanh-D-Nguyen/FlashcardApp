import Foundation

protocol CardStudyInteractorInterface: AnyObject {
    /// A value copy of the stored deck, or `nil` when it no longer exists.
    func deck(withId id: String) -> DeskEntity?
}

final class CardStudyInteractor: CardStudyInteractorInterface {
    private let repository: DeskRepositoryInterface

    init(repository: DeskRepositoryInterface = DeskManagement.shared) {
        self.repository = repository
    }

    func deck(withId id: String) -> DeskEntity? {
        repository.desk(withId: id)
    }
}
