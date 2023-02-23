//
//  GradientView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import UIKit

class GradientView: RoundCornerView {
    override class var layerClass: Swift.AnyClass {
        CAGradientLayer.self
    }
    
    override var layer: CAGradientLayer {
        (super.layer as? CAGradientLayer)!
    }
    
    public func set(colors: [UIColor]) {
        backgroundColor = .clear
        layer.colors = colors.map { $0.cgColor }
    }
    
    public func set(startPoint: CGPoint, endPoint: CGPoint) {
        layer.startPoint = startPoint
        layer.endPoint = endPoint
    }
}

