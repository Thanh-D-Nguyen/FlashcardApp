//
//  WordSuggestionCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/18.
//

import UIKit

class WordSuggestionCell: UICollectionViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = AppColors.textSecondary
        label.numberOfLines = 2
        label.minimumScaleFactor = 0.5
        label.adjustsFontSizeToFitWidth = true
        label.backgroundColor = AppColors.background
        label.textAlignment = .center
        label.layer.cornerRadius = 4.0
        label.layer.borderWidth = 1.0
        label.layer.borderColor = AppColors.separatorLine.cgColor
        label.layer.masksToBounds = true
        return label
    }()
    
    private func setupView() {
        addSubview(titleLabel)
        titleLabel.text = "Text"
        self.contentView.fill(with: titleLabel, edges: .init(top: 2, left: 2, bottom: 2, right: 2))
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func updateWord(_ card: CardEntity, face: CardFace) {
        titleLabel.text = face == .front ? card.frontText : card.backText
    }
    
}
