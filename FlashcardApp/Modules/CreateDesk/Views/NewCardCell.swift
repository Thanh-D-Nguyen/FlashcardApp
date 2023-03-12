//
//  NewCardCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import SwipeCellKit
import GrowingTextView
import RxSwift

class NewCardCell: SwipeTableViewCell {
    private var disposeBag = DisposeBag()
    
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var wordViewContainer: UIView!
    @IBOutlet private weak var seperateViewContainer: UIView!
    @IBOutlet private weak var meanViewContainer: UIView!
    
    @IBOutlet private weak var backImageView: UIImageView!
    @IBOutlet private weak var frontImageView: UIImageView!

    @IBOutlet private weak var wordTextField: GrowingTextView!
    @IBOutlet private weak var meanTextField: GrowingTextView!
    
    @IBOutlet private weak var imageButton: UIButton!
    
    var cellUniqueId: String?
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
    
    func updateCard(_ card: CardDataModel, sortingLanguage: LanguageSortingType) {
        cellUniqueId = card.uuid
        wordTextField.text = card.frontRelay.value
        meanTextField.text = card.backRelay.value
        updateSortingLanguage(sortingLanguage)
        disposeBag = DisposeBag()
        wordTextField.rx.didChange
            .map({ [unowned self] in self.wordTextField.text })
            .bind(to: card.frontRelay).disposed(by: disposeBag)
        meanTextField.rx.didChange
            .map({ [unowned self] in self.meanTextField.text })
            .bind(to: card.backRelay).disposed(by: disposeBag)
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
            UIView.animate(withDuration: 0.20) {
                self.layoutIfNeeded()
            }
        }
        currentSortingLanguage = sortingLang
    }
}

extension NewCardCell: FocusTextFieldCellProtocol {
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?) {
        let needStartResponder = !wordTextField.isFirstResponder &&
                                !meanTextField.isFirstResponder
        if currentSortingLanguage == .normal {
            if needStartResponder {
                wordTextField.becomeFirstResponder()
            } else if wordTextField.isFirstResponder {
                meanTextField.becomeFirstResponder()
            } else if meanTextField.isFirstResponder, let uuid = cellUniqueId {
                completion?(.focusNextFrom(uuid))
            }
        } else {
            if needStartResponder {
                meanTextField.becomeFirstResponder()
            } else if meanTextField.isFirstResponder {
                wordTextField.becomeFirstResponder()
            } else if wordTextField.isFirstResponder, let uuid = cellUniqueId {
                completion?(.focusNextFrom(uuid))
            }
        }
        
    }

    func resignFirstResponder() {
        self.endEditing(true)
    }
}

extension NewCardCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isFocusedField = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        isFocusedField = false
    }
}
