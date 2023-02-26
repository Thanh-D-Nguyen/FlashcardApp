//
//  NewCardCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import SwipeCellKit

class NewCardCell: SwipeTableViewCell {

    @IBOutlet private weak var wordTextField: UITextField!
    @IBOutlet private weak var readingTextField: UITextField!
    @IBOutlet private weak var meanTextField: UITextField!
    
    var isFocusedField: Bool = false
    
    var nextCellResponder: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
   
}

extension NewCardCell: FocusTextFieldCellProtocol {
    func becomeNextResponder() {
        if !wordTextField.isFirstResponder {
            wordTextField.becomeFirstResponder()
        }
        if readingTextField.isFirstResponder {
            meanTextField.becomeFirstResponder()
        }
        if meanTextField.becomeFirstResponder() {
            nextCellResponder?()
        }
    }
}

extension NewCardCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        isFocusedField = true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        isFocusedField = false
    }
}
