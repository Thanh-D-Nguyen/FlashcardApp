//
//  ImageSearchViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//  
//

import UIKit

final class ImageSearchViewController: BaseViewController {
    var presenter: ImageSearchPresenterInterface!
    @IBOutlet private weak var segmentedControl: RESegmentedControl!
    @IBOutlet private weak var imageCollectionView: UICollectionView!
    @IBOutlet private weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        let titles = SearchImageType.all()
        var segmentItems: [SegmentModel] {
            return titles.map({ SegmentModel(title: $0) })
        }
        let preset = BootstapPreset(backgroundColor: AppColors.primary, selectedBackgroundColor: AppColors.accentGreen, textColor: AppColors.background, selectedTextColor: AppColors.textPrimary)
        segmentedControl.configure(segmentItems: segmentItems, preset: preset)

        setupCollectionView()
    }
    
    func subscribe() {
        subscribe(presenter.photosRelay) { [weak self] _ in
            guard let self else { return }
            self.imageCollectionView.reloadData()
        }
    }
    
    @IBAction
    private func segmentedValueChanged() {
        presenter.changePhotoSource(segmentedControl.selectedSegmentIndex)
    }
    
    private func setupCollectionView() {
        imageCollectionView.addPullToRefresh(PullToRefresh(position: .bottom), action: { [weak self] in
            guard let self else { return }
            self.loadMoreItems()
        })
        imageCollectionView.registerClass(ImageSearchResultCell.self)
        let layout =  UICollectionViewFlowLayout()
            let spacing: CGFloat = 1
            let itemsPerRow: CGFloat = 3
            let totalSpacing = spacing * (itemsPerRow - 1)
            let itemWidth = (imageCollectionView.bounds.width - totalSpacing) / itemsPerRow
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
        imageCollectionView.setCollectionViewLayout(layout, animated: true)
    }
    
    private func loadMoreItems() {
        presenter.searchPhotos(query: nil)
    }
}

extension ImageSearchViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        presenter.photosRelay.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ImageSearchResultCell = imageCollectionView.dequeueResuableCell(forIndexPath: indexPath)
        let image = presenter.photosRelay.value[indexPath.row]
        cell.updateImage(image)
        return cell
    }
}

extension ImageSearchViewController: UICollectionViewDelegate {
    
}


extension ImageSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter.searchPhotos(query: searchText)
    }
}
