//
//  DeskListViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

final class DeskListViewController: BaseViewController {
    var presenter: DeskListPresenterInterface!
    @IBOutlet private weak var deskListCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        deskListCollectionView.registerNib(cellClass: DeskListCell.self)
        deskListCollectionView.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }

    func subscribe() {
        subscribe(presenter.desksRelay) { [weak self] _ in
            guard let self else { return }
            self.deskListCollectionView.reloadData()
        }
    }
    
    @IBAction private func close() {
        self.dismiss(animated: true)
    }
}

extension DeskListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return presenter.desksRelay.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: DeskListCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
        cell.updateDesk(presenter.desksRelay.value[indexPath.row])
        return cell
    }
}

extension DeskListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 16
        return CGSize(width: width, height: 66)
    }
}

extension DeskListViewController: UICollectionViewDelegate {
    
}
