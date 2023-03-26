//
//  NewCardCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import SwipeCellKit
import RxSwift

class NewCardCell: SwipeTableViewCell {
    private var disposeBag = DisposeBag()
    
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var wordViewContainer: UIView!
    @IBOutlet private weak var seperateViewContainer: UIView!
    @IBOutlet private weak var meanViewContainer: UIView!
    
    @IBOutlet private weak var cardImageView: UIImageView!

    @IBOutlet private weak var wordTextField: MMTextView!
    @IBOutlet private weak var meanTextField: MMTextView!
    
    @IBOutlet private weak var imageButton: UIButton!
    
    weak var tableView: UITableView?
    
    var cellUniqueId: String?
    var isFocusedField: Bool = false
            
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        wordTextField.inputViewStyle = .borderWith(radius: 4.0)
        wordTextField.lineColor = AppColor.royalBlue?.withAlphaComponent(0.3)
        wordTextField.editLineColor = AppColor.royalBlue
        wordTextField.indicatorStyle = .default
        wordTextField.textColor = AppColor.darkSlateGray
        
        meanTextField.inputViewStyle = .borderWith(radius: 4.0)
        meanTextField.lineColor = AppColor.royalBlue?.withAlphaComponent(0.3)
        meanTextField.editLineColor = AppColor.royalBlue
        meanTextField.indicatorStyle = .default
        meanTextField.textColor = AppColor.darkSlateGray
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func updateCard(_ card: CardDataModel) {
        cellUniqueId = card.uuid
        wordTextField.text = card.front
        meanTextField.text = card.back
        self.cardImageView.image = card.image
        subscrible(card)
    }
    
    private func subscrible(_ card: CardDataModel) {
        disposeBag = DisposeBag()
        wordTextField.rx.didChange
            .map({ [unowned self] in self.wordTextField.text })
            .bind(to: card.frontRelay).disposed(by: disposeBag)
        meanTextField.rx.didChange
            .map({ [unowned self] in self.meanTextField.text })
            .bind(to: card.backRelay).disposed(by: disposeBag)
        Observable.combineLatest([wordTextField.rx.observe(\.contentSize),
                                  meanTextField.rx.observe(\.contentSize)])
        .observe(on: MainScheduler.asyncInstance)
        .subscribe(onNext: { [unowned self] _ in
            self.tableView?.beginUpdates()
            self.tableView?.endUpdates()
        }).disposed(by: disposeBag)

        imageButton.rx.tap.bind(to: card.didSelectImageRelay).disposed(by: disposeBag)
        
        card.imageRelay.bind(onNext: { [unowned self] image in
            self.cardImageView.image = image
        }).disposed(by: disposeBag)
    
        Observable.merge([wordTextField.rx.didBeginEditing.asObservable(),
                          meanTextField.rx.didBeginEditing.asObservable()])
            .map({ [unowned self] _ in
                self.isFocusedField = true
                return self.isFocusedField
            }).bind(to: card.focusRelay)
            .disposed(by: disposeBag)
        
        Observable.merge([wordTextField.rx.didEndEditing.asObservable(),
                                  meanTextField.rx.didEndEditing.asObservable()])
            .map({ [unowned self] _ in
                self.isFocusedField = false
                return self.isFocusedField
            }).bind(to: card.focusRelay)
            .disposed(by: disposeBag)
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
        } else if meanTextField.isFirstResponder, let uuid = cellUniqueId {
            completion?(.focusNextFrom(uuid))
        }
    }
    
    func resignFirstResponder() {
        self.endEditing(true)
    }
}
