//
//  AddDeskBottomView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//

import UIKit
import RxSwift

enum AddDeskBottomViewAction {
    case next, insert
}

@IBDesignable
class AddDeskBottomView: UIControl {
    @IBOutlet private weak var numOfItemLabel: UILabel!
    @IBOutlet private weak var nextFocusButton: UIButton!
    @IBOutlet private weak var collectionView: FadingEdgesCollectionView!
    @IBOutlet private weak var collectionContainerView: UIView!
    
    private(set) var action: AddDeskBottomViewAction = .next
    
    private var result = SearchResultEntity(face: .front, cards: [])
    
    var didSelectCard: ((CardEntity) -> Void)?
    
    private func setupView() {
        instantiate()
        collectionView.registerClass(WordSuggestionCell.self)
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
    
    func setSearchResult(_ result: SearchResultEntity) {
        self.result = result
        collectionContainerView.isHidden = result.cards.count == 0
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    func updateKeyboardHidden(_ isHidden: Bool) {
        numOfItemLabel.alpha = isHidden ? 0.0 : 1.0
        nextFocusButton.alpha = isHidden ? 0.0 : 1.0
    }
    
    func updateNumOfItemText(_ text: String) {
        numOfItemLabel.text = text
    }
}

extension AddDeskBottomView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return result.cards.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: WordSuggestionCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
        cell.updateWord(result.cards[indexPath.row], face: result.face)
        return cell
    }
}

extension AddDeskBottomView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 3.0
        return CGSize(width: width, height: collectionView.bounds.height)
    }
}

extension AddDeskBottomView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectCard?(result.cards[indexPath.row])
    }
}

extension AddDeskBottomView: NibInstantiate {}
