//
//  DeskCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import RxSwift
import RxCocoa

protocol FocusTextFieldCellProtocol: AnyObject {
    var cellUniqueId: String? { get }
    var isFocusedField: Bool { get }
    
    func becomeNextResponder(_ completion: ((DeskChangedEvent) -> Void)?)
    func resignFirstResponder()
}

class DeskCell: UITableViewCell {
    final private let textFieldBorderWidth = 2.0

    private var disposeBag = DisposeBag()
    
    @IBOutlet private weak var deskButtonContainerView: UIView!
    @IBOutlet private weak var deskDescContainerView: UIView!
    
    @IBOutlet private weak var deskNameTextField: MMTextView!
    @IBOutlet private weak var deskDescTextField: MMTextView!
    
    weak var tableView: UITableView?
    var cellUniqueId: String?
    var isFocusedField: Bool = false
        
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        deskButtonContainerView.isHidden = false
        deskDescContainerView.isHidden = true
        deskNameTextField.inputViewStyle = .borderWith(radius: textFieldBorderWidth)
        deskNameTextField.lineColor = AppColors.primary
        deskNameTextField.editLineColor = AppColors.secondary
        deskNameTextField.indicatorStyle = .default
        deskNameTextField.textColor = AppColors.primary
        
        deskDescTextField.inputViewStyle = .borderWith(radius: textFieldBorderWidth)
        deskDescTextField.indicatorStyle = .default
        deskDescTextField.lineColor = AppColors.primary
        deskDescTextField.editLineColor = AppColors.secondary
        deskDescTextField.textColor = AppColors.textPrimary

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
        deskNameTextField.text = desk.deskName
        deskDescTextField.text = desk.deskDesc
        subscrible(desk)
        
    }
    
    private func subscrible(_ desk: DeskDataModel) {
        disposeBag = DisposeBag()
        deskNameTextField.rx.didChange
            .map({ [unowned self] in self.deskNameTextField.text })
            .bind(to: desk.deskNameRelay).disposed(by: disposeBag)
        deskDescTextField.rx.didChange
            .map({ [unowned self] in self.deskDescTextField.text })
            .bind(to: desk.deskDescRelay).disposed(by: disposeBag)
        
        Observable.combineLatest([deskNameTextField.rx.observe(\.contentSize),
                                  deskDescTextField.rx.observe(\.contentSize)])
        .observe(on: MainScheduler.asyncInstance)
        .subscribe(onNext: { [unowned self] _ in
            self.tableView?.beginUpdates()
            self.tableView?.endUpdates()
        }).disposed(by: disposeBag)
        
        Observable.merge([deskNameTextField.rx.didBeginEditing.asObservable(),
                          deskDescTextField.rx.didBeginEditing.asObservable()])
        .observe(on: MainScheduler.asyncInstance)
            .map({ [unowned self] _ in
                self.isFocusedField = true
                return self.isFocusedField
            }).bind(to: desk.focusRelay)
            .disposed(by: disposeBag)
        
        Observable.merge([deskNameTextField.rx.didEndEditing.asObservable(),
                                  deskDescTextField.rx.didEndEditing.asObservable()])
            .observe(on: MainScheduler.asyncInstance)
            .map({ [unowned self] _ in
                self.isFocusedField = false
                return self.isFocusedField
            }).bind(to: desk.focusRelay)
            .disposed(by: disposeBag)
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
