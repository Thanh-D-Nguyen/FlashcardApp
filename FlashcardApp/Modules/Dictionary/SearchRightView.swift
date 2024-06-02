//
//  SearchRightView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/09/30.
//

import UIKit

class SearchRightView: UIView {
    
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

extension SearchRightView: NibInstantiate {}
