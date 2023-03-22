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
    
    case reloadCard(_ index: Int)
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
    
    var wordsSearchResultRelay: BehaviorRelay<SearchResultEntity> { get }
    
    func viewDidLoad()
    func insertNewCardAfterUId(_ uId: String)
    func deleteCardAtIndex(_ index: Int)
    func moveCardAtIndex(_ index: Int, moveType: CardCellMoveType)
    
    func updateEditingCard(_ card: CardEntity)
    
    func saveDesk()
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let searchWordInteractor: SearchWordsInteractor
    private let wireframe: CreateDeskWireframeInterface
    
    private let dictionaryInteractor = DictionaryInteractor()
    
    private let disposeBag = DisposeBag()
    
    var desk = DeskDataModel()
    let deskChangedRelay = BehaviorRelay<DeskChangedEvent>(value: .default)
    let sortingLanguageRelay = BehaviorRelay<LanguageSortingType>(value: .normal)
    let wordsSearchResultRelay = BehaviorRelay<SearchResultEntity>(value: SearchResultEntity(face: .front, cards: []))
    
    private var editingCard: CardDataModel!
    
    init(interactor: CreateDeskInteractorInterface,
        wireframe: CreateDeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.searchWordInteractor = SearchWordsInteractor()
    }
    
    private func bind(_ card: CardDataModel) {
        // Search front
        let searchFront = card.frontRelay.throttle(.milliseconds(100), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
        let queryFront = searchFront.map({
            let words = self.searchWordInteractor.searchText($0, cardFace: .front)
            return words
        }).asDriver(onErrorJustReturn: self.searchWordInteractor.searchText("", cardFace: .front))
        queryFront.asObservable().subscribe(onNext: { [unowned self] obj in
            self.editingCard = card
            self.wordsSearchResultRelay.accept(obj)
        }).disposed(by: disposeBag)
        
        // Search back
        let searchBack = card.backRelay.throttle(.milliseconds(100), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
        let queryBack = searchBack.map({
            let words = self.searchWordInteractor.searchText($0, cardFace: .back)
            return words
        }).asDriver(onErrorJustReturn: self.searchWordInteractor.searchText("", cardFace: .back))
        queryBack.asObservable().subscribe(onNext: { [unowned self] obj in
            self.editingCard = card
            self.wordsSearchResultRelay.accept(obj)
        }).disposed(by: disposeBag)
    }
    
    private func searchText(_ text: String, cardFace: CardFace) {
        let words = self.searchWordInteractor.searchText(text, cardFace: cardFace)
        wordsSearchResultRelay.accept(words)
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
    
    func updateEditingCard(_ card: CardEntity) {
        guard self.editingCard != nil else { return }
        self.editingCard.backRelay.accept(card.backText)
        self.editingCard.frontRelay.accept(card.frontText + "(\(card.frontExtraText))")
        guard let index = desk.cards.firstIndex(where: { $0 == self.editingCard }) else { return }
        
        desk.cards[index] = self.editingCard
        deskChangedRelay.accept(.reloadCard(index))
    }
    
    func saveDesk() {
        let deskEntity = self.desk.toDeskEntity()
        do {
            defer {
                wireframe.close()
            }
            try DeskManagement.shared.add(deskEntity)
        } catch {
            print(error)
        }
    }
}
