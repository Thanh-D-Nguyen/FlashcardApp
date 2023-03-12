//
//  DeskCardHeaderView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import RxSwift

class DeskCardHeaderView: UITableViewHeaderFooterView {
    private let disposeBag = DisposeBag()
    @IBOutlet private weak var languageSegmented: UISegmentedControl!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func updateSortingLanguage(_ desk: DeskDataModel) {
        languageSegmented.selectedSegmentIndex = desk.sortingLanguageRelay.value.rawValue
        languageSegmented.rx.controlEvent(.valueChanged)
            .map({ [unowned self] in LanguageSortingType(rawValue: self.languageSegmented.selectedSegmentIndex) ?? .normal })
            .bind(to: desk.sortingLanguageRelay).disposed(by: disposeBag)
    }
}
