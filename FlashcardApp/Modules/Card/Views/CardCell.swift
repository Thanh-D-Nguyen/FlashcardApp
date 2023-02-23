//
//  CardCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import UIKit
import CollectionViewPagingLayout

class CardCell: UICollectionViewCell {

    // MARK: Properties
    var entity: CardEntity? {
        didSet {
            updateViews()
        }
    }
    
    private(set) var cardView: CardView!
    private var edgeConstraints: [NSLayoutConstraint]?
    
    
    // MARK: Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let edgeConstraints = edgeConstraints else {
            return
        }
        let leftRightMargin = 24.0
        let topBottomMargin = 24.0
        edgeConstraints[0].constant = leftRightMargin
        edgeConstraints[2].constant = -leftRightMargin
        
        edgeConstraints[1].constant = topBottomMargin
        edgeConstraints[3].constant = -topBottomMargin
    }
    
    private func setupViews() {
        cardView = CardView(frame: bounds)
        let leftRightMargin = 24.0
        let topBottomMargin = 24.0
        edgeConstraints = contentView.fill(
            with: cardView,
            edges: UIEdgeInsets(top: topBottomMargin, left: leftRightMargin, bottom: -topBottomMargin, right: -leftRightMargin)
        )
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    private func updateViews() {
        cardView.entity = entity
    }
}

extension CardCell: ScaleTransformView {
    var scaleOptions: ScaleTransformViewOptions {
        return .layout(.blur)
    }
}
