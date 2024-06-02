//
//  CardMiniView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/11.
//
import UIKit

@IBDesignable
class CardMiniView: UIView {
    @IBInspectable var frontText: String? {
        didSet {
            frontLabel.text = frontText
        }
    }
    
    @IBInspectable var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }
    
    @IBInspectable var borderColor: UIColor = UIColor.clear {
        didSet {
            layer.borderColor = borderColor.cgColor
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    
    @IBInspectable var shadowColor: UIColor = UIColor.clear {
        didSet {
            layer.shadowColor = shadowColor.cgColor
        }
    }
    
    @IBInspectable var shadowOpacity: Float = 0 {
        didSet {
            layer.shadowOpacity = shadowOpacity
        }
    }
    
    @IBInspectable var shadowRadius: CGFloat = 0 {
        didSet {
            layer.shadowRadius = shadowRadius
        }
    }
    
    @IBInspectable var shadowOffset: CGSize = CGSize(width: 0, height: 0) {
        didSet {
            layer.shadowOffset = shadowOffset
        }
    }
    
    private var frontLabel = UILabel()
    private var imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Cập nhật shadowPath khi layout thay đổi
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
    }
    
    private func setupView() {
        self.layer.masksToBounds = false

        
        addSubview(imageView)
        addSubview(frontLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        frontLabel.translatesAutoresizingMaskIntoConstraints = false
        
        frontLabel.backgroundColor = .clear

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        frontLabel.adjustsFontSizeToFitWidth = true
        frontLabel.minimumScaleFactor = 0.5
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            frontLabel.topAnchor.constraint(equalTo: self.topAnchor),
            frontLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            frontLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            frontLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath

        layer.cornerRadius = 4
        clipsToBounds = true
    }
}

