//
//  DeskCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import GrowingTextView

protocol FocusTextFieldCellProtocol: AnyObject {
    var indexPath: IndexPath? { get }
    var isFocusedField: Bool { get }
    
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?)
    func resignFirstResponder()
}

class DeskCell: UITableViewCell {
    
    @IBOutlet private weak var deskButtonContainerView: UIView!
    @IBOutlet private weak var deskDescContainerView: UIView!
    
    @IBOutlet private weak var deskNameTextField: GrowingTextView!
    @IBOutlet private weak var deskDescTextField: GrowingTextView!
    
    weak var tableView: UITableView?
    var indexPath: IndexPath? {
        tableView?.indexPath(for: self)
    }
    var isFocusedField: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        deskButtonContainerView.isHidden = false
        deskDescContainerView.isHidden = true        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    @IBAction
    private func addDescriptionAction() {
        deskButtonContainerView.isHidden = true
        deskDescContainerView.isHidden = false
    }
   
    func updateName(_ name: String, description: String) {
        deskNameTextField.text = name
        deskDescTextField.text = description
    }
}

extension DeskCell: FocusTextFieldCellProtocol {
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?) {
        let needStartResponder = !deskNameTextField.isFirstResponder && !deskDescTextField.isFirstResponder
        if needStartResponder {
            deskNameTextField.becomeFirstResponder()
            return
        }
        if deskDescContainerView.isHidden {
            if deskNameTextField.isFirstResponder, let indexPath = indexPath {
                completion?(.focusNextFrom(indexPath))
            }
        } else {
            if deskNameTextField.isFirstResponder {
                deskDescTextField.becomeFirstResponder()
            } else if deskDescTextField.isFirstResponder, let indexPath = indexPath {
                completion?(.focusNextFrom(indexPath))
            }
        }
    }
    
    func resignFirstResponder() {
        self.endEditing(true)
    }
}

extension DeskCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isFocusedField = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        isFocusedField = false
    }
}
