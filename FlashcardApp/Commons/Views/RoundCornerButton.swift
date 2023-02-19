//
//  RoundCornerButton.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

@IBDesignable
class RoundCornerButton: UIButton {
    @IBInspectable
    var cornerRadius: CGFloat = 0.0
    @IBInspectable
    var borderColor: UIColor = .clear
    @IBInspectable
    var borderWidth: CGFloat = 0.0
    @IBInspectable
    var backgroundImageColor: UIColor  = .clear {
        didSet {
            backgroundColor = backgroundImageColor
            setBackgroundImage(backgroundImageColor.image(), for: .normal)
        }
    }
    @IBInspectable
    var backgroundImagePressedColor: UIColor = .clear {
        didSet {
            setBackgroundImage(backgroundImagePressedColor.image(), for: .highlighted)
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        layer.cornerRadius = cornerRadius
        clipsToBounds = (cornerRadius > 0)
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
    }
}
