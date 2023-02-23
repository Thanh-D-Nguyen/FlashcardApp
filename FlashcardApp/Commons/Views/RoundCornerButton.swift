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

    @IBInspectable
    var dashed: Bool = false {
        didSet {
            if dashed {
                border.lineDashPattern = [6, 4]
            } else {
                border.lineDashPattern = nil
            }
        }
    }
    @IBInspectable
    var borderColor: UIColor = .clear {
        didSet {
            border.strokeColor = borderColor.cgColor
        }
    }
    
    @IBInspectable
    var cornerRadius: CGFloat = 0 {
        didSet {
            updatePath()
            layer.cornerRadius = cornerRadius > bounds.width / 2 ? bounds.width / 2 : cornerRadius
        }
    }
    
    @IBInspectable
    var lineWidth: CGFloat = 0 {
        didSet {
            updatePath()
            border.lineWidth = lineWidth
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }
    
    private let border = CAShapeLayer()
    
    private func setup() {
        border.strokeColor = borderColor.cgColor
        border.fillColor = nil
        border.lineJoin = .round
        border.lineWidth = lineWidth
        updatePath()
        layer.addSublayer(border)
        layer.masksToBounds = true
        layer.cornerRadius = cornerRadius
    }
    
    private func updatePath() {
        border.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        border.frame = bounds
    }
}
