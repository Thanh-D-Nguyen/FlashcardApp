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
    @IBOutlet private weak var layoutButton: UIButton!
    
    private let gridLayout = GridFlowLayout()
    private let listLayout = ListFlowLayout()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        deskListCollectionView.delegate = self
        deskListCollectionView.dataSource = self
        deskListCollectionView.registerNib(cellClass: DeskListCell.self)
        deskListCollectionView.setCollectionViewLayout(listLayout, animated: false)
        deskListCollectionView.contentInset = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        layoutButton.setImage(AppImages.gridImage, for: .normal)
        deskListCollectionView.dataSource = self
        deskListCollectionView.delegate = self
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        deskListCollectionView.refreshControl = refresh
    }
    
    func subscribe() {
        subscribe(presenter.desksRelay) { [weak self] _ in
            guard let self else { return }
            self.deskListCollectionView.reloadData()
        }
    }
}

extension DeskListViewController {
    @IBAction private func close() {
        self.dismiss(animated: true)
    }
    
    @IBAction private func addDesk() {
        presenter.addDesk()
        logger.debug("addDesk")
    }
    
    @IBAction private func toggleLayout(_ sender: UIButton) {
        if deskListCollectionView.collectionViewLayout == gridLayout {
            deskListCollectionView.setCollectionViewLayout(listLayout, animated: true)
            layoutButton.setImage(AppImages.gridImage, for: .normal)
        } else {
            deskListCollectionView.setCollectionViewLayout(gridLayout, animated: true)
            layoutButton.setImage(AppImages.listImage, for: .normal)
        }
    }
    
    @objc private func handlePullToRefresh() {
        presenter.updateDesk()
        self.deskListCollectionView.reloadData()
        logger.debug("reloadData")
        self.deskListCollectionView.refreshControl?.endRefreshing()
    }
}

extension DeskListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        presenter.desksRelay.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: DeskListCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
        let entity = self.presenter.desksRelay.value[indexPath.row]
        cell.updateDesk(entity)
        return cell
    }
}

extension DeskListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        presenter.didSelectDeskAtIndex(indexPath.item)
    }
}
