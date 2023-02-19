//
//  CarouselView.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/15.
//

import UIKit

enum CarouselType {
    case advanceSmall, advanceLarge, simpleSmall, simpleLarge, boxes
    
    static func random() -> CarouselType {
        return [CarouselType.advanceSmall,
                CarouselType.advanceLarge,
                CarouselType.simpleSmall,
                CarouselType.simpleLarge,
                CarouselType.boxes][Int.random(in: 0 ..< 5)]
    }
}

class CarouselView: UIView {
    
    @IBOutlet weak private var collectionView: UICollectionView!
    
    private var type: CarouselType = CarouselType.random()
    
    private func setupView() {
        instantiate()
        collectionView.register(cellClass: SimpleCardCell.self)
        collectionView.register(cellClass: AdvanceCardCell.self)
        collectionView.register(cellClass: SnackBoxesCell.self)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = .zero
        collectionView.backgroundColor = .clear
        collectionView.backgroundView?.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

}
extension CarouselView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        5
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch self.type {
            case .advanceSmall, .advanceLarge:
                let cell: AdvanceCardCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            case .simpleSmall,
                    .simpleLarge:
                let cell: SimpleCardCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            case .boxes:
                let cell: SnackBoxesCell = collectionView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
        }
    }
}

extension CarouselView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let height = collectionView.bounds.height
        switch type {
            case .advanceSmall, .simpleSmall, .boxes:
                return CGSize(width: width / 3.0, height: height)
            case .advanceLarge, .simpleLarge:
                return CGSize(width: width / 1.5, height: height)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
}

extension CarouselView: NibInstantiate {}
