//
//  ImageSearchResultCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/26.
//

import UIKit
import Kingfisher

class ImageSearchResultCell: UICollectionViewCell {
    
    private var imageView = UIImageView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupView()
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
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.topAnchor.constraint(equalTo: imageView.topAnchor).isActive = true
        contentView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor).isActive = true
        imageView.contentMode = .scaleAspectFit
    }
    
    func updateImage(_ photo: SearchPhoto) {
        if let url = URL(string: photo.url) {
            imageView.kf.setImage(with: url)
        }
    }
}
