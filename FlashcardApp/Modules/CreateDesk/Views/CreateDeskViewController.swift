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
    }
    
    func subscribe() {
        keyboard.toolbar(scrollView: deskTableView).on(event: .willShow, do: { [weak self] options in
            guard let self else { return }
            self.bottomConstraint.constant = -options.endFrame.height
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }).on(event: .willHide, do: { options in
            self.bottomConstraint.constant = 0
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }).start()
        
        subscribe(presenter.deskChangedRelay) { [weak self] event in
            guard let self else { return }
            switch event {
                case .default:
                    self.deskTableView.reloadData()
                case .cardInsert(let indexPath):
                    self.insertCardRowAt(indexPath)
                case .cardDelete(let index):
                    self.deleteCardRowAt(index)
                case .cardSwap(let fromIndex, let toIndex):
                    self.swapCardRow(fromIndex, toIndex)
                case .focusNextFrom(let indexPath):
                    self.focusOrAddNewCardRowFrom(indexPath)
            }
        }
        
        subscribe(presenter.sortingLanguageRelay) { [weak self] _ in
            guard let self else { return }
            self.deskTableView.reloadData()
        }
    }
    
    @IBAction
    private func bottomTapAction(_ sender: AddDeskBottomView) {
        if sender.action == .next {
            handleNextResponder()
        } else if sender.action == .insert {
            presenter.insertNewCardAtIndexPath(IndexPath(row: 0, section: CreateDeskTableSection.cards.rawValue))
        }
    }
    
    private func handleNextResponder() {
        guard let focusedCell = deskTableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol }).first(where: { $0.isFocusedField == true }) else { return }
        focusedCell.becomeNextResponder { [weak self] event in
            guard let self else { return }
            switch event {
                case .focusNextFrom(let indexPath):
                    self.focusOrAddNewCardRowFrom(indexPath)
                default: break
            }
        }
    }
    
    private func updateVisibleCellsIndexPath() {
     
    }
    
    private func insertCardRowAt(_ indexPath: IndexPath) {
        deskTableView.beginUpdates()
        deskTableView.insertRows(at: [indexPath], with: .left)
        deskTableView.endUpdates()
        deskTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        if let focusCell = deskTableView.cellForRow(at: indexPath) as? FocusTextFieldCellProtocol {
            focusCell.indexPath = indexPath
            focusCell.becomeNextResponder(nil)
        }
        updateVisibleCellsIndexPath()
    }
    
    private func deleteCardRowAt(_ indexPath: IndexPath) {
        if let unFocusCell = deskTableView.cellForRow(at: indexPath) as? FocusTextFieldCellProtocol {
            unFocusCell.resignFirstResponder()
        }
        deskTableView.beginUpdates()
        deskTableView.deleteRows(at: [indexPath], with: .fade)
        deskTableView.endUpdates()
        updateVisibleCellsIndexPath()
    }
    
    private func swapCardRow(_ fromIndexPath: IndexPath,_ toIndexPath: IndexPath) {
        deskTableView.beginUpdates()
        deskTableView.moveRow(at: fromIndexPath, to: toIndexPath)
        deskTableView.endUpdates()
        deskTableView.scrollToRow(at: toIndexPath, at: .top, animated: true)
        updateVisibleCellsIndexPath()
    }
    
    private func focusOrAddNewCardRowFrom(_ indexPath: IndexPath) {
        var nextIndexPath = indexPath
        if indexPath.section == CreateDeskTableSection.desk.rawValue {
            nextIndexPath.section = CreateDeskTableSection.cards.rawValue
        } else {
            nextIndexPath.row = indexPath.row + 1
        }
        
        if let nextCell = deskTableView.cellForRow(at: nextIndexPath) as? FocusTextFieldCellProtocol {
            deskTableView.scrollToRow(at: nextIndexPath, at: .top, animated: true)
            nextCell.becomeNextResponder(nil)
        } else {
            presenter.insertNewCardAtIndexPath(nextIndexPath)
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
            cell.indexPath = indexPath
            cell.tableView = tableView
            let desk = presenter.desk
            cell.updateName(desk.name, description: desk.description)
            return cell
        }
        let cell: NewCardCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        cell.indexPath = indexPath
        cell.delegate = self
        cell.dataChangeDelegate = self
        let cards = presenter.desk.cards
        if cards.indices.contains(indexPath.row) {
            cell.updateCard(cards[indexPath.row], sortingLanguage: presenter.desk.sortingLanguage)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == CreateDeskTableSection.cards.rawValue {
            let view: DeskCardHeaderView = tableView.dequeueReusableHeaderFooterView()
            view.updateSortingLanguage(presenter.desk.sortingLanguage)
            view.didChangeLanguageSorting = { [weak self] index in
                guard let self else { return }
                self.presenter.didChangeLanguageSortingIndex(index)
            }
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
                self.presenter.deleteCardAtIndexPath(indexPath)
            }
            configure(action: deleteAction, with: .trash)
            return [deleteAction]
        }
        
        let moveUpAction = SwipeAction(style: .default, title: nil) { [weak self] _, indexPath in
            guard let self else { return }
            self.presenter.moveCardAtIndexPath(indexPath, moveType: .up)
        }
        configure(action: moveUpAction, with: .up)
        let moveDownAction = SwipeAction(style: .default, title: nil) { [weak self] _, indexPath in
            guard let self else { return }
            self.presenter.moveCardAtIndexPath(indexPath, moveType: .down)
        }
        configure(action: moveDownAction, with: .down)
        return [moveUpAction, moveDownAction]
    }

    func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        options.buttonSpacing = 4
        options.backgroundColor = #colorLiteral(red: 0.9467939734, green: 0.9468161464, blue: 0.9468042254, alpha: 1)
        return options
    }
}

extension CreateDeskViewController: NewCardCellDelegate {
    func newCardCell(_ cell: NewCardCell, type: NewCardFieldType, didTextChange text: String) {
        print("newCardCell", cell, type, text)
    }
    
    func newCardCellDidSelectImage(_ cell: NewCardCell) {
        print("newCardCellDidSelectImage", cell)
    }
    
    func newCardCellDidEditReading(_ cell: NewCardCell) {
        print("newCardCellDidEditReading", cell)
    }
}

extension CreateDeskViewController {
    private func configure(action: SwipeAction, with descriptor: ActionDescriptor) {
        let buttonStyle = ButtonStyle.circular
        action.title = descriptor.title(forDisplayMode: .imageOnly)
        action.image = descriptor.image(forStyle: buttonStyle, displayMode: .imageOnly)
        action.backgroundColor = AppColor.white
        action.textColor = descriptor.color(forStyle: buttonStyle)
        action.font = .systemFont(ofSize: 13)
        action.transitionDelegate = ScaleTransition.default
    }
}
