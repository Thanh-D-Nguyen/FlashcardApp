//
//  CreateDeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import Foundation
import RxRelay

enum DeskChangedEvent {
    case `default`
    case cardInsert(_ indexPath: IndexPath)
    case cardDelete(_ indexPath: IndexPath)
    case cardSwap(_ fromIndexPath: IndexPath,_ toIndexPath: IndexPath)
    case focusNextFrom(_ indexPath: IndexPath)
}

enum CreateDeskTableSection: Int {
    case desk
    case cards
    
    static let sectionCount = 2
}

enum CardCellMoveType {
    case up, down
}

protocol CreateDeskPresenterInterface: AnyObject {
    
    var desk: DeskEntity { get }
    var deskChangedRelay: BehaviorRelay<DeskChangedEvent> { get }
    var sortingLanguageRelay: BehaviorRelay<LanguageSortingType> { get }
    
    func viewDidLoad()
    func insertNewCardAtIndexPath(_ indexPath: IndexPath)
    func deleteCardAtIndexPath(_ indexPath: IndexPath)
    func moveCardAtIndexPath(_ indexPath: IndexPath, moveType: CardCellMoveType)
    func didChangeLanguageSortingIndex(_ index: Int)
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let wireframe: CreateDeskWireframeInterface
    
    var desk: DeskEntity = DeskEntity.empty()
    let deskChangedRelay = BehaviorRelay<DeskChangedEvent>(value: .default)
    let sortingLanguageRelay = BehaviorRelay<LanguageSortingType>(value: .normal)
    
    init(interactor: CreateDeskInteractorInterface,
        wireframe: CreateDeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CreateDeskPresenter: CreateDeskPresenterInterface {
    func viewDidLoad() {
        
    }
    
    func insertNewCardAtIndexPath(_ indexPath: IndexPath) {
        var insertIndexPath = indexPath
        var newCard = CardEntity.empty()
        newCard.frontText = "\(indexPath.row)"
        if desk.cards.count == 0 {
            desk.cards.insert(newCard, at: 0)
            insertIndexPath.section = CreateDeskTableSection.cards.rawValue
            insertIndexPath.row = 0
        } else {
            desk.cards.insert(newCard, at: indexPath.row)
        }
        deskChangedRelay.accept(.cardInsert(insertIndexPath))
    }
    
    func deleteCardAtIndexPath(_ indexPath: IndexPath) {
        desk.cards.remove(at: indexPath.row)
        deskChangedRelay.accept(.cardDelete(indexPath))
    }
    
    func moveCardAtIndexPath(_ indexPath: IndexPath, moveType: CardCellMoveType) {
        guard desk.cards.indices.contains(indexPath.row) else { return }
        var toIndex = -1
        switch moveType {
            case .up:
                if desk.cards.indices.contains(indexPath.row - 1) {
                    toIndex = indexPath.row - 1
                }
            case .down:
                if desk.cards.indices.contains(indexPath.row + 1) {
                    toIndex = indexPath.row + 1
                }
        }
        if toIndex != -1 {
            desk.cards.swapAt(indexPath.row, toIndex)
            deskChangedRelay.accept(.cardSwap(indexPath, IndexPath(row: toIndex, section: indexPath.section)))
        }
    }
    
    func didChangeLanguageSortingIndex(_ index: Int) {
        guard let sortType = LanguageSortingType(rawValue: index) else { return }
        desk.sortingLanguage = sortType
        sortingLanguageRelay.accept(sortType)
    }
}
