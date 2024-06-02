//
//  CardView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import UIKit
import Kingfisher

class CardView: UIView {
    
    @IBOutlet private weak var addMoreView: GradientView!
    @IBOutlet private weak var contentView: GradientView!

    @IBOutlet private weak var descImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subTitleLabel: UILabel!
    
    private var tapGuesture: UITapGestureRecognizer!
    
    var entity: CardEntity? {
        didSet {
            updateViewInfo()
        }
    }
    
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
        contentView.set(startPoint: .zero, endPoint: CGPoint(x: 1, y: 1))
        contentView.set(colors: [AppColors.primary, AppColors.secondary].compactMap({ $0! }))
        addMoreView.set(startPoint: .zero, endPoint: CGPoint(x: 1, y: 1))
        addMoreView.set(colors: [AppColors.primary, AppColors.secondary].compactMap({ $0! }))
        
        tapGuesture = UITapGestureRecognizer(target: self, action: #selector(flip))
        addGestureRecognizer(tapGuesture)
    }
    
    private func updateViewInfo() {
        if let entity = entity {
            addMoreView.isHidden = true
            contentView.isHidden = false
            entity.setImageToImageView(descImageView)
            if entity.displayingFront {
                titleLabel.text = entity.frontText
                subTitleLabel.text = entity.frontExtraText
                subTitleLabel.superview?.isHidden = entity.frontExtraText.isEmpty
            } else {
                titleLabel.text = entity.backText
                subTitleLabel.text = entity.backExtraText
                subTitleLabel.superview?.isHidden = entity.backExtraText.isEmpty
            }
        } else {
            if tapGuesture != nil {
                removeGestureRecognizer(tapGuesture)
            }
            addMoreView.isHidden = false
            contentView.isHidden = true
        }
    }
    
    @objc
    private func flip() {
        guard let entity else {
            return
        }
        let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromRight, .showHideTransitionViews]
        let displayingFront = entity.displayingFront
        UIView.transition(with: self, duration: 0.5, options: transitionOptions, animations: {
            self.entity?.displayingFront = !displayingFront
        }, completion: { _ in
            self.updateViewInfo()
        })
    }
}

extension CardView: NibInstantiate {}
