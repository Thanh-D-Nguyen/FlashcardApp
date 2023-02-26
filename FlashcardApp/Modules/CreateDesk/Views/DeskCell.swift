//
//  DeskCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit

protocol FocusTextFieldCellProtocol: AnyObject {
    var isFocusedField: Bool { get }
    var nextCellResponder: (() -> Void)? { get set }
    func becomeNextResponder()
}

class DeskCell: UITableViewCell {
    
    @IBOutlet private weak var deskButtonContainerView: UIView!
    @IBOutlet private weak var deskDescContainerView: UIView!
    
    @IBOutlet private weak var deskNameTextField: UITextField!
    @IBOutlet private weak var deskDescTextField: UITextField!
    
    var isFocusedField: Bool = false
    var nextCellResponder: (() -> Void)?
    
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
   
}

extension DeskCell: FocusTextFieldCellProtocol {
    func becomeNextResponder() {
        if deskNameTextField.isFirstResponder {
            deskDescTextField.becomeFirstResponder()
        } else {
            deskNameTextField.becomeFirstResponder()
        }
        if deskDescTextField.isFirstResponder {
            nextCellResponder?()
        }
    }
}

extension DeskCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        isFocusedField = true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        isFocusedField = false
    }
}
