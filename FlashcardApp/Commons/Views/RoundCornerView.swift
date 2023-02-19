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
    var radiusCorner: CGFloat = 0
    @IBInspectable
    var stroke: CGFloat = 0
    @IBInspectable
    var strokeColor: UIColor = .blue
    @IBInspectable
    var fillColor: UIColor = .darkGray
    
    private var roundCornerPath: UIBezierPath!
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.setValue(UIColor.clear, forKeyPath: "self.backgroundColor")
        self.setValue(UIColor.clear, forKeyPath: "self.tintColor")
        self.layoutSubviews()
    }
    
    override func draw(_ rect: CGRect) {
        guard UIGraphicsGetCurrentContext() != nil else {
            return
        }
        self.backgroundColor = UIColor.clear
        self.tintColor = UIColor.clear
        create()
        modify()
        
    }
    
    private func create() {
        roundCornerPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.radiusCorner)
        roundCornerPath.addClip()
    }
    
    private func modify() {
        self.fillColor.setFill()
        roundCornerPath.fill()
        self.strokeColor.setStroke()
        roundCornerPath.lineWidth = self.stroke
        roundCornerPath.stroke()
        
    }
}
