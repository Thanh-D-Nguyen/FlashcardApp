//
//  RoundCornerView.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//
import UIKit

@IBDesignable
class RoundCornerView: UIView {
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
            layer.cornerRadius = cornerRadius
        }
    }
    
    @IBInspectable
    var lineWidth: CGFloat = 0 {
        didSet {
            updatePath()
            border.lineWidth = lineWidth
        }
    }
    
    @IBInspectable
    var shadowColor: UIColor = .clear {
        didSet {
            updateShadowPath()
            layer.shadowColor = shadowColor.cgColor
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
        updateShadowPath()
    }
    
    private let border = CAShapeLayer()
    
    private func setup() {
        border.strokeColor = borderColor.cgColor
        border.fillColor = nil
        border.lineJoin = .round
        border.lineWidth = lineWidth
        updatePath()
        updateShadowPath()
        layer.addSublayer(border)
        layer.shadowOffset = .zero
        layer.shadowOpacity = 1.0
        layer.shadowRadius = 3.0
        layer.masksToBounds = true
        layer.shadowColor = UIColor.clear.cgColor
        layer.cornerRadius = cornerRadius
    
    }
    
    private func updatePath() {
        border.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        border.frame = bounds
    }
    
    private func updateShadowPath() {
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
}
