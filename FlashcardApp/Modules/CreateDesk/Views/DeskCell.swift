//
//  DeskCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import GrowingTextView
import RxSwift

protocol FocusTextFieldCellProtocol: AnyObject {
    var cellUniqueId: String? { get }
    var isFocusedField: Bool { get }
    
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?)
    func resignFirstResponder()
}

class DeskCell: UITableViewCell {
    
    private var disposeBag = DisposeBag()
    
    @IBOutlet private weak var deskButtonContainerView: UIView!
    @IBOutlet private weak var deskDescContainerView: UIView!
    
    @IBOutlet private weak var deskNameTextField: GrowingTextView!
    @IBOutlet private weak var deskDescTextField: GrowingTextView!
    
    var cellUniqueId: String?
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
   
    func update(_ desk: DeskDataModel) {
        cellUniqueId = desk.uuid
        deskNameTextField.text = desk.deskNameRelay.value
        deskDescTextField.text = desk.deskDescRelay.value
        disposeBag = DisposeBag()
        deskNameTextField.rx.didChange
            .map({ [unowned self] in self.deskNameTextField.text })
            .bind(to: desk.deskNameRelay).disposed(by: disposeBag)
        deskDescTextField.rx.didChange
            .map({ [unowned self] in self.deskDescTextField.text })
            .bind(to: desk.deskDescRelay).disposed(by: disposeBag)
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
            if deskNameTextField.isFirstResponder, let uId = cellUniqueId {
                completion?(.focusNextFrom(uId))
            }
        } else {
            if deskNameTextField.isFirstResponder {
                deskDescTextField.becomeFirstResponder()
            } else if deskDescTextField.isFirstResponder, let uId = cellUniqueId {
                completion?(.focusNextFrom(uId))
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
