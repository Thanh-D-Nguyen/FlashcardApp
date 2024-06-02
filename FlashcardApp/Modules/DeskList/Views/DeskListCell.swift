//
//  DeskListCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/05/12.
//

import UIKit

class DeskListCell: UICollectionViewCell {

    @IBOutlet private var deskTitle: UILabel!
    @IBOutlet private var deskSubTitle: UILabel!
    @IBOutlet private var numOfCardsButton: UIButton!
    @IBOutlet private var favoriteButton: UIButton!
    
    @IBOutlet private var cardMiniViews: [CardMiniView]!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupCards()
    }
    
    func updateDesk(_ desk: DeskEntity) {
        deskTitle.text = desk.name
        deskSubTitle.text = desk.description
        numOfCardsButton.setTitle("\(desk.cards.count) thẻ", for: .normal)
        updateCards(desk.cards)
        logger.debug("\(desk.cards.map({ $0.frontText + " : " + $0.backText }).joined())")
    }
    
    private func updateCards(_ allCards: [CardEntity]) {
        let pickItemCount = 3
        var cards = Array(allCards.prefix(pickItemCount))
        let isLessThanOrEqualThree = cards.count == allCards.count || allCards.count < pickItemCount
        let isGreaterThanThree = allCards.count > pickItemCount
        cardMiniViews.forEach({ $0.isHidden = true })
        for cardView in cardMiniViews {
            if cards.isEmpty {
                if isLessThanOrEqualThree {
                    return
                } else if isGreaterThanThree {
                    cardView.isHidden = false
                    cardView.frontText = "Còn nữa..."
                    return
                }
            }
            cardView.isHidden = false
            let card = cards.removeFirst()
            cardView.frontText = card.frontText
        }
    }
    
    private func setupCards() {
        let rotationAngle = CGFloat(45) * .pi / 180
        
        for cardView in cardMiniViews {
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 500
            transform = CATransform3DRotate(transform, rotationAngle, 0, 2, 0.2)
            
            cardView.layer.transform = transform
        }
    }
}
