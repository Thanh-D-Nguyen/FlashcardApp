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
    @IBOutlet private weak var titleLabel: UILabel!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.text = NSLocalizedString("Cards", comment: "")
        languageSegmented.setTitle(NSLocalizedString("Japanese - Vietnamese", comment: ""), forSegmentAt: 0)
        languageSegmented.setTitle(NSLocalizedString("Vietnamese - Japanese", comment: ""), forSegmentAt: 1)
    }
    
    func updateSortingLanguage(_ desk: DeskDataModel) {
        languageSegmented.selectedSegmentIndex = desk.sortingLanguageRelay.value.rawValue
        languageSegmented.rx.controlEvent(.valueChanged)
            .map({ [unowned self] in LanguageSortingType(rawValue: self.languageSegmented.selectedSegmentIndex) ?? .normal })
            .bind(to: desk.sortingLanguageRelay).disposed(by: disposeBag)
    }
}
