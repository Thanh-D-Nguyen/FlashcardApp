//
//  DeskCardHeaderView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit

class DeskCardHeaderView: UITableViewHeaderFooterView {
    
    var didChangeLanguageSorting: ((Int) -> Void)?
    @IBOutlet private weak var languageSegmented: UISegmentedControl!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction
    private func segmentDidChangeAction(_ sender: UISegmentedControl) {
        didChangeLanguageSorting?(sender.selectedSegmentIndex)
    }
    
    func updateSortingLanguage(_ type: LanguageSortingType) {
        languageSegmented.selectedSegmentIndex = type.rawValue
    }
}
