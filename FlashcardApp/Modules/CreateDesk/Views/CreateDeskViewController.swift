//
//  CreateDeskViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import UIKit
import SwipeCellKit
import Typist

final class CreateDeskViewController: BaseViewController {
    var presenter: CreateDeskPresenterInterface!
    
    @IBOutlet private weak var deskTableView: UITableView!
    
    @IBOutlet private weak var bottomView: AddDeskBottomView!
    @IBOutlet private weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var doneButton: RoundCornerButton!
    
    private let keyboard = Typist.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        deskTableView.keyboardDismissMode = .interactive
        deskTableView.registerNib(cellClass: DeskCell.self)
        deskTableView.registerNib(cellClass: NewCardCell.self)
        deskTableView.registerHeaderFooterNib(aClass: DeskCardHeaderView.self)
        bottomView.updateKeyboardHidden(true)
    }
    
    func subscribe() {
        keyboard.toolbar(scrollView: deskTableView).on(event: .willShow, do: { [weak self] options in
            guard let self else { return }
            self.updateBottomConstraint(-options.endFrame.height)
        }).on(event: .willHide, do: { [weak self] _ in
            guard let self else { return }
            self.updateBottomConstraint(0)
        }).start()
        doneButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let self else { return }
            self.presenter.saveDesk()
        }).disposed(by: disposeBag)
        subscribe(presenter.deskChangedRelay) { [weak self] event in
            guard let self else { return }
            switch event {
                case .default:
                    self.deskTableView.reloadData()
                case .cardInsert(_, let index):
                    self.insertCardRowAt(index)
                case .cardDelete(_, let index):
                    self.deleteCardRowAt(index)
                case .cardSwap(_, let fromIndex, _, let toIndex):
                    self.swapCardRow(fromIndex, toIndex)
                case .focusNextFrom(let uId):
                    self.focusOrAddNewCardRowFrom(uId)
                case .reloadCard(let index):
                    self.reloadCardCellAtIndex(index)
            }
        }
        subscribe(presenter.sortingLanguageRelay) { [weak self] _ in
            guard let self else { return }
            self.deskTableView.reloadData()
        }
        
        subscribe(presenter.wordsSearchResultRelay) { [weak self] searchResult in
            guard let self else { return }
            self.bottomView.setSearchResult(searchResult)
        }
        
        bottomView.didSelectCard = { [weak self] card in
            guard let self else { return }
            self.presenter.updateEditingCard(card)
        }
    
        subscribe(presenter.focusIndexRelay) { focusString in
            self.bottomView.updateNumOfItems(focusString)
        }
        
    }
    
    private func updateBottomConstraint(_ constant: CGFloat) {
        self.bottomConstraint.constant = constant
        let isKeyboardHidden = constant == 0
        if isKeyboardHidden {
            self.bottomView.setSearchResult(SearchResultEntity(face: .front, cards: []))
        }
        bottomView.updateKeyboardHidden(isKeyboardHidden)
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
            self.bottomView.layoutIfNeeded()
        }
    }
    
    @IBAction
    private func bottomTapAction(_ sender: AddDeskBottomView) {
        if sender.action == .next {
            handleNextResponder()
        } else if sender.action == .insert {
            let focusedCell = deskTableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol }).first(where: { $0.isFocusedField == true })
            if let uId = focusedCell?.cellUniqueId {
                presenter.insertNewCardAfterUId(uId)
            } else {
                presenter.insertNewCardAfterUId(nil)
            }
        }
    }
    
    private func handleNextResponder() {
        if let focusedCell = deskTableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol }).first(where: { $0.isFocusedField == true }) {
            focusedCell.becomeNextResponder { [weak self] event in
                guard let self else { return }
                switch event {
                    case .focusNextFrom(let uId):
                        self.focusOrAddNewCardRowFrom(uId)
                    default: break
                }
            }
        }
    }
    
    private func insertCardRowAt(_ index: Int) {
        let indexPath = IndexPath(row: index, section: CreateDeskTableSection.cards.rawValue)
        deskTableView.beginUpdates()
        deskTableView.insertRows(at: [indexPath], with: .left)
        deskTableView.endUpdates()
        deskTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        if let focusCell = deskTableView.cellForRow(at: indexPath) as? FocusTextFieldCellProtocol {
            focusCell.becomeNextResponder(nil)
        }
    }
    
    private func deleteCardRowAt(_ index: Int) {
        let indexPath = IndexPath(row: index, section: CreateDeskTableSection.cards.rawValue)
        if let unFocusCell = deskTableView.cellForRow(at: indexPath) as? FocusTextFieldCellProtocol {
            unFocusCell.resignFirstResponder()
        }
        deskTableView.beginUpdates()
        deskTableView.deleteRows(at: [indexPath], with: .fade)
        deskTableView.endUpdates()
    }
    
    private func swapCardRow(_ fromIndex: Int,_ toIndex: Int) {
        let fromIndexPath = IndexPath(row: fromIndex, section: CreateDeskTableSection.cards.rawValue)
        let toIndexPath = IndexPath(row: toIndex, section: CreateDeskTableSection.cards.rawValue)
        deskTableView.beginUpdates()
        deskTableView.moveRow(at: fromIndexPath, to: toIndexPath)
        deskTableView.endUpdates()
        deskTableView.scrollToRow(at: toIndexPath, at: .top, animated: true)
    }
    
    private func focusOrAddNewCardRowFrom(_ uId: String) {
        guard let focusCellIndex = deskTableView.visibleCells
            .compactMap({ $0 as? FocusTextFieldCellProtocol })
            .firstIndex(where: { $0.isFocusedField == true && $0.cellUniqueId == uId }) else { return }
        let nextCellIndex = focusCellIndex + 1
        if deskTableView.visibleCells.indices.contains(nextCellIndex) {
            if let nextCell = deskTableView.visibleCells[nextCellIndex] as? FocusTextFieldCellProtocol {
                if let indexPath = deskTableView.indexPath(for: nextCell as! UITableViewCell) {
                    deskTableView.scrollToRow(at: indexPath, at: .top, animated: true)
                }
                nextCell.becomeNextResponder(nil)
            }
        } else {
            presenter.insertNewCardAfterUId(uId)
        }
    }
    
    private func reloadCardCellAtIndex(_ index: Int) {
        let indexPath = IndexPath(row: index, section: CreateDeskTableSection.cards.rawValue)
        if let cell = deskTableView.cellForRow(at: indexPath) as? NewCardCell {
            let cards = presenter.desk.cards
            if cards.indices.contains(indexPath.row) {
                cell.updateCard(cards[indexPath.row])
            }
        }
    }
}

extension CreateDeskViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return CreateDeskTableSection.sectionCount
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == CreateDeskTableSection.desk.rawValue {
            return 1
        }
        return presenter.desk.cards.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == CreateDeskTableSection.desk.rawValue {
            let cell: DeskCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            cell.tableView = tableView
            let desk = presenter.desk
            cell.update(desk)
            return cell
        }
        let cell: NewCardCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        cell.tableView = tableView
        cell.delegate = self
        let cards = presenter.desk.cards
        if cards.indices.contains(indexPath.row) {
            cell.updateCard(cards[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == CreateDeskTableSection.cards.rawValue {
            let view: DeskCardHeaderView = tableView.dequeueReusableHeaderFooterView()
            view.updateSortingLanguage(presenter.desk)
            return view
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}

extension CreateDeskViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == CreateDeskTableSection.cards.rawValue {
            return 50.0
        }
        return 0.0
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension CreateDeskViewController: SwipeTableViewCellDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeCellKit.SwipeActionsOrientation) -> [SwipeCellKit.SwipeAction]? {
        if orientation == .right {
            let deleteAction = SwipeAction(style: .destructive, title: nil) { [weak self] _, indexPath in
                guard let self else { return }
                
                self.presenter.deleteCardAtIndex(indexPath.row)
            }
            configure(action: deleteAction, with: .trash)
            return [deleteAction]
        }
        if presenter.desk.cards.count == 1 {
            return nil
        }
        let moveUpAction = SwipeAction(style: .default, title: nil) { [weak self] _, indexPath in
            guard let self else { return }
            self.presenter.moveCardAtIndex(indexPath.row, moveType: .up)
        }
        configure(action: moveUpAction, with: .up)
        let moveDownAction = SwipeAction(style: .default, title: nil) { [weak self] _, indexPath in
            guard let self else { return }
            self.presenter.moveCardAtIndex(indexPath.row, moveType: .down)
        }
        configure(action: moveDownAction, with: .down)
        return [moveUpAction, moveDownAction]
    }

    func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        options.buttonSpacing = 4
        options.backgroundColor = UIColor.clear
        return options
    }
}

extension CreateDeskViewController {
    private func configure(action: SwipeAction, with descriptor: ActionDescriptor) {
        let buttonStyle = ButtonStyle.circular
        action.title = descriptor.title(forDisplayMode: .imageOnly)
        action.image = descriptor.image(forStyle: buttonStyle, displayMode: .imageOnly)
        action.backgroundColor = AppColor.whiteSmoke
        action.textColor = descriptor.color(forStyle: buttonStyle)
        action.font = .systemFont(ofSize: 13)
        action.transitionDelegate = ScaleTransition.default
    }
}
