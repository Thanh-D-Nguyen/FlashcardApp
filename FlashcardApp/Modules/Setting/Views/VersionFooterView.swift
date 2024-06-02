//
//  VersionFooterView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/10/09.
//

import UIKit

class VersionFooterView: UIView {

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

extension VersionFooterView: NibInstantiate { }
