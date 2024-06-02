//
//  TopBarView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import UIKit

class TopBarView: UIView {

    @IBInspectable var title: String = "Screen Name" {
        didSet {
            titleLabel.text = title
        }
    }
    @IBOutlet private weak var titleLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        instantiate()
    }
}

extension TopBarView: NibInstantiate {}
