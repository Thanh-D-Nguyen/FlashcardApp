//
//  AddDeskBottomView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit

enum AddDeskBottomViewAction {
    case next, insert
}

@IBDesignable
class AddDeskBottomView: UIControl {
    @IBOutlet private weak var numOfItemLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!
    
    private(set) var action: AddDeskBottomViewAction = .next
    
    private func setupView() {
        instantiate()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    @IBAction
    private func nextAction(_ sender: UIButton) {
        action = .next
        sendActions(for: .touchUpInside)
    }
    
    @IBAction
    private func insertCardAction(_ sender: UIButton) {
        action = .insert
        sendActions(for: .touchUpInside)
    }
    
    func updateNumOfItems(_ text: String) {
        numOfItemLabel.text = text
    }
}

extension AddDeskBottomView: NibInstantiate {}
