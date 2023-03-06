//
//  NewCardCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import SwipeCellKit
import GrowingTextView

enum NewCardFieldType {
    case keyword, mean, reading
}

protocol NewCardCellDelegate: AnyObject {
    func newCardCell(_ cell: NewCardCell, type: NewCardFieldType, didTextChange text: String)
    func newCardCellDidSelectImage(_ cell: NewCardCell)
    func newCardCellDidEditReading(_ cell: NewCardCell)
}

class NewCardCell: SwipeTableViewCell {
    
    weak var dataChangeDelegate: NewCardCellDelegate?
    
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var wordViewContainer: UIView!
    @IBOutlet private weak var seperateViewContainer: UIView!
    @IBOutlet private weak var meanViewContainer: UIView!
    
    @IBOutlet private weak var backImageView: UIImageView!
    @IBOutlet private weak var frontImageView: UIImageView!

    @IBOutlet private weak var wordTextField: GrowingTextView!
    @IBOutlet private weak var meanTextField: GrowingTextView!
    
    @IBOutlet private weak var imageButton: UIButton!
    
    weak var tableView: UITableView?
    
    var indexPath: IndexPath? {
        tableView?.indexPath(for: self)
    }
    var isFocusedField: Bool = false

    private var currentSortingLanguage: LanguageSortingType = .normal
        
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func updateCard(_ card: CardEntity, sortingLanguage: LanguageSortingType) {
        wordTextField.text = card.frontText
        meanTextField.text = card.backText
        updateSortingLanguage(sortingLanguage)
    }
    
    func updateSortingLanguage(_ sortingLang: LanguageSortingType) {
        if currentSortingLanguage != sortingLang {
            let arrangedViews: [UIView] = sortingLang == .normal ?
            [wordViewContainer, seperateViewContainer, meanViewContainer] :
            [meanViewContainer, seperateViewContainer, wordViewContainer]
            
            stackView.removeAllArrangedSubviews()
            
            for arrangedView in arrangedViews {
                stackView.addArrangedSubview(arrangedView)
            }
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            }
        }
        currentSortingLanguage = sortingLang
    }
    
    @IBAction
    private func selectImageAction(_ sender: UIButton) {
        dataChangeDelegate?.newCardCellDidSelectImage(self)
    }
    
    @IBAction
    private func editReadingAction(_ sender: UIButton) {
        dataChangeDelegate?.newCardCellDidEditReading(self)
    }
}

extension NewCardCell: FocusTextFieldCellProtocol {
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?) {
        let needStartResponder = !wordTextField.isFirstResponder &&
                                !meanTextField.isFirstResponder
        if needStartResponder {
            wordTextField.becomeFirstResponder()
        } else if wordTextField.isFirstResponder {
            meanTextField.becomeFirstResponder()
        } else if meanTextField.isFirstResponder, let indexPath = indexPath {
            completion?(.focusNextFrom(indexPath))
        }
    }

    func resignFirstResponder() {
        self.endEditing(true)
    }
}

extension NewCardCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isFocusedField = true
        print("Editting indexPath", indexPath ?? "Unknow")
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        isFocusedField = false
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let type: NewCardFieldType
        if textView == wordTextField {
            type = .keyword
        } else {
            type = .mean
        }
        dataChangeDelegate?.newCardCell(self, type: type, didTextChange: textView.text)
    }
}
