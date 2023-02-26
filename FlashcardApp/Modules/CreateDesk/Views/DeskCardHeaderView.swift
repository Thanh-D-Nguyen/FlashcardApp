//
//  DeskCardHeaderView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit

class DeskCardHeaderView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction
    private func segmentDidChangeAction(_ sender: UISegmentedControl) {
        print("segmentDidChangeAction", sender.selectedSegmentIndex)
    }
}
