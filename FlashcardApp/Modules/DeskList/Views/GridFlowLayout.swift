//
//  DeskListLayout.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/03.
//

import UIKit

class GridFlowLayout: UICollectionViewFlowLayout {
    
    override init() {
        super.init()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }
    
    func setupLayout() {
        minimumInteritemSpacing = 2
        minimumLineSpacing = 2
        scrollDirection = .vertical
        
        let itemsPerRow: CGFloat = 3
        let padding: CGFloat = 1
        let totalPadding = padding * (itemsPerRow - 1)
        let individualItemWidth = (UIScreen.main.bounds.width - totalPadding) / itemsPerRow
        itemSize = CGSize(width: individualItemWidth, height: individualItemWidth)
    }
}
