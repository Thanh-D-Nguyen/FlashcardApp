//
//  ListFlowLayout.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/03.
//

import UIKit

class ListFlowLayout: UICollectionViewFlowLayout {
    
    override init() {
        super.init()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }
    
    func setupLayout() {
        minimumInteritemSpacing = 1
        minimumLineSpacing = 1
        scrollDirection = .vertical
        let width = UIScreen.main.bounds.width
        itemSize = CGSize(width: width, height: 150)
    }
}
