//
//  CardViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit
import CollectionViewPagingLayout

final class CardViewController: BaseViewController {
    var presenter: CardPresenterInterface!
    
    @IBOutlet private weak var deskButton: UIButton!
    @IBOutlet private weak var cardCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.loadDesks()
    }

    func setupUI() {
        cardCollectionView.registerClass(CardCell.self)
        cardCollectionView.isPagingEnabled = true
        cardCollectionView.dataSource = self
        let layout = CollectionViewPagingLayout()
        cardCollectionView.collectionViewLayout = layout
        layout.delegate = self
        cardCollectionView.showsHorizontalScrollIndicator = false
        cardCollectionView.clipsToBounds = false
        cardCollectionView.backgroundColor = .clear
        cardCollectionView.delegate = self
    }

    func subscribe() {
        subscribe(presenter.deskDataRelay, { [weak self] _ in
            guard let self else { return }
            self.updateCurrentDesk()
            self.cardCollectionView.reloadData()
        })
    }
    
    private func updateCurrentDesk() {
        let desk = presenter.selectingDesk
        deskButton.setTitle(desk?.name, for: .normal)
    }
}

extension CardViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return presenter.cards.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CardCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
        if presenter.cards.indices.contains(indexPath.row) {
            cell.entity = presenter.cards[indexPath.row]
        } else {
            cell.entity = nil
        }
        return cell
    }
}

extension CardViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // If select empty entity cell, it mean add new card
        if !presenter.cards.indices.contains(indexPath.row) {
            presenter.createNewCard()
        }
    }
}

extension CardViewController: CollectionViewPagingLayoutDelegate {
    func onCurrentPageChanged(layout: CollectionViewPagingLayout, currentPage: Int) {
        print("Current Page:", currentPage)
    }
}


extension CardViewController {
    @IBAction
    private func selectDeskAction() {
        presenter.showDesk(byAddNew: false)
    }
    
    @IBAction
    private func addNewDeskAction() {
        presenter.showDesk(byAddNew: true)
    }
}
