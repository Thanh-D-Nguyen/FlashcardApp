//
//  CreateDeskViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import UIKit
import SwipeCellKit

final class CreateDeskViewController: BaseViewController {
    var presenter: CreateDeskPresenterInterface!

    @IBOutlet private weak var deskTableView: UITableView!
    @IBOutlet private weak var bottomConstraint: NSLayoutConstraint!
    
    lazy private var keyboardObserver = CommonKeyboardObserver()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        deskTableView.registerNib(cellClass: DeskCell.self)
        deskTableView.registerNib(cellClass: NewCardCell.self)
        deskTableView.registerHeaderFooterNib(aClass: DeskCardHeaderView.self)
                
        keyboardObserver.subscribe(events: [.willChangeFrame, .dragDown]) { [weak self] info in
            guard let self = self else { return }
            let bottom = info.isShowing
            ? (-info.visibleHeight) + self.view.safeAreaInsets.bottom
            : 0
            UIView.animate(info, animations: { [weak self] in
                self?.bottomConstraint.constant = bottom
                self?.view.layoutIfNeeded()
            })
        }
    }

    func subscribe() {

    }
    
    @IBAction
    private func bottomTapAction(_ sender: AddDeskBottomView) {
        if sender.action == .next {
            let visibleCells: [FocusTextFieldCellProtocol] = deskTableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol })
            if let focusCell = visibleCells.first(where: { $0.isFocusedField }) {
                focusCell.becomeNextResponder()
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
        return 2//presenter.cardsRelay.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == CreateDeskTableSection.desk.rawValue {
            let cell: DeskCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            cell.nextCellResponder = {
                let visibleCells: [FocusTextFieldCellProtocol] = tableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol })
                if let focusIndex = visibleCells.firstIndex(where: { $0.isFocusedField }) {
                    let nextIndex = focusIndex + 1
                    if nextIndex < visibleCells.count {
                        let nextCell = visibleCells[nextIndex]
                        nextCell.becomeNextResponder()
                    }
                }
            }
            return cell
        }
        let cell: NewCardCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        cell.nextCellResponder = {
            let visibleCells: [FocusTextFieldCellProtocol] = tableView.visibleCells.compactMap({ $0 as? FocusTextFieldCellProtocol })
            if let focusIndex = visibleCells.firstIndex(where: { $0.isFocusedField }) {
                let nextIndex = focusIndex + 1
                if nextIndex < visibleCells.count {
                    let nextCell = visibleCells[nextIndex]
                    nextCell.becomeNextResponder()
                }
            }
        }
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == CreateDeskTableSection.cards.rawValue {
            let view: DeskCardHeaderView = tableView.dequeueReusableHeaderFooterView()
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
}

extension CreateDeskViewController: SwipeTableViewCellDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeCellKit.SwipeActionsOrientation) -> [SwipeCellKit.SwipeAction]? {
        if orientation == .right {
            let deleteAction = SwipeAction(style: .destructive, title: "Delete") { action, indexPath in
                print("Delete...")
            }
            return [deleteAction]
        }
        
        let moveUpAction = SwipeAction(style: .default, title: nil) { action, indexPath in
            print("MoveUp...")
        }
        moveUpAction.image = AppImage.upImage
        let moveDownAction = SwipeAction(style: .default, title: nil) { action, indexPath in
            print("moveDownAction...")
        }
        moveDownAction.image = AppImage.downImage
        return [moveUpAction, moveDownAction]
    }
}

extension CreateDeskViewController: CommonKeyboardContainerProtocol {
    var scrollViewContainer: UIScrollView {
        return deskTableView
    }
}
