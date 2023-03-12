//
//  CreateDeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import Foundation
import RxRelay
import RxSwift

enum DeskChangedEvent {
    case `default`
    case cardInsert(_ afterUId: String,_ insertIndex: Int)
    case cardDelete(_ atUId: String,_ deleteIndex: Int)
    case cardSwap(_ fromUId: String,_ fromIndex: Int,_ toUId: String,_ toIndex: Int)
    case focusNextFrom(_ uId: String)
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
    
    var desk: DeskDataModel { get }
    var deskChangedRelay: BehaviorRelay<DeskChangedEvent> { get }
    var sortingLanguageRelay: BehaviorRelay<LanguageSortingType> { get }
    
    func viewDidLoad()
    func insertNewCardAfterUId(_ uId: String)
    func deleteCardAtIndex(_ index: Int)
    func moveCardAtIndex(_ index: Int, moveType: CardCellMoveType)
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let wireframe: CreateDeskWireframeInterface
    
    private let dictionaryInteractor = DictionaryInteractor()
    
    private let disposeBag = DisposeBag()
    
    var desk = DeskDataModel()
    let deskChangedRelay = BehaviorRelay<DeskChangedEvent>(value: .default)
    let sortingLanguageRelay = BehaviorRelay<LanguageSortingType>(value: .normal)
    
    init(interactor: CreateDeskInteractorInterface,
        wireframe: CreateDeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
    
    private func bind(_ card: CardDataModel) {
        card.frontRelay.bind(onNext: { [unowned self] text in
            self.searchText(text)
        }).disposed(by: disposeBag)
        
        card.backRelay.bind(onNext: { [unowned self] text in
            self.searchText(text)
        }).disposed(by: disposeBag)
    }
    
    private func searchText(_ text: String) {
        guard text.count > 0 else { return }
        if sortingLanguageRelay.value == .normal {
            print("search JA text", text)
        }
    }
}

extension CreateDeskPresenter: CreateDeskPresenterInterface {
    func viewDidLoad() {
        self.desk.sortingLanguageRelay.bind { [unowned self] type in
            self.sortingLanguageRelay.accept(type)
        }.disposed(by: disposeBag)
    }
    
    func insertNewCardAfterUId(_ uId: String) {
        let newCard = CardDataModel()
        self.bind(newCard)
        var insertIndex = 0
        if let currentIndex = desk.cards.firstIndex(where: { $0.uuid == uId }) {
            insertIndex = currentIndex + 1
        }
        desk.cards.insert(newCard, at: insertIndex)
        deskChangedRelay.accept(.cardInsert(uId, insertIndex))
    }
    
    func deleteCardAtIndex(_ index: Int) {
        let card = desk.cards.remove(at: index)
        deskChangedRelay.accept(.cardDelete(card.uuid, index))
    }
    
    func moveCardAtIndex(_ index: Int, moveType: CardCellMoveType) {
        var toIndex = -1
        switch moveType {
            case .up:
                if desk.cards.indices.contains(index - 1) {
                    toIndex = index - 1
                }
            case .down:
                if desk.cards.indices.contains(index + 1) {
                    toIndex = index + 1
                }
        }
        if toIndex != -1 {
            desk.cards.swapAt(index, toIndex)
            let uid = desk.cards[index].uuid
            deskChangedRelay.accept(.cardSwap(uid, index, desk.cards[toIndex].uuid, toIndex))
        }
    }
}
