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
        label.textColor = AppColor.blackA80
        label.numberOfLines = 2
        label.minimumScaleFactor = 0.5
        label.backgroundColor = AppColor.whiteSmoke
        label.textAlignment = .center
        label.layer.cornerRadius = 8.0
        label.layer.masksToBounds = true
        return label
    }()
    
    private func setupView() {
        addSubview(titleLabel)
        titleLabel.text = "Text"
        self.contentView.fill(with: titleLabel, edges: .init(top: 4, left: 4, bottom: 4, right: 4))
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
