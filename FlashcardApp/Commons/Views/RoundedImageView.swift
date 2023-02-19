//
//  RoundedImageView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit

@IBDesignable
class RoundedImageView: UIImageView {
    @IBInspectable
    var radiusRatio: CGFloat = 0.0 {
        didSet {
            self.layer.cornerRadius = self.bounds.size.width * radiusRatio
        }
    }
    @IBInspectable
    public var borderWidth: CGFloat = 0.0 {
        didSet {
            self.layer.borderWidth = borderWidth
        }
    }
    @IBInspectable
    public var borderColor: UIColor = .black {
        didSet {
            self.layer.borderColor = borderColor.cgColor
        }
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setup()
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    override public init(image: UIImage!) {
        super.init(image: image)
        setup()
    }
    
    override public init(image: UIImage!, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        setup()
    }
    
    
    // MARK: - Support Methods
    func setup() {
        self.layer.masksToBounds = true
    }
    
    override public func prepareForInterfaceBuilder() {
        setup()
    }
}
