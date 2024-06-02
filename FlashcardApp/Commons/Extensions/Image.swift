//
//  Image.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/25.
//

import UIKit

extension UIImage {
    func withBorder(borderColor: UIColor, borderWidth: CGFloat) -> UIImage? {
        let size = CGSize(width: self.size.width + borderWidth * 2, height: self.size.height + borderWidth * 2)
        
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Vẽ viền
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)
        let rect = CGRect(x: borderWidth / 2, y: borderWidth / 2, width: self.size.width + borderWidth, height: self.size.height + borderWidth)
        context.stroke(rect)
        
        // Vẽ hình ảnh gốc
        self.draw(at: CGPoint(x: borderWidth, y: borderWidth))
        
        let imageWithBorder = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageWithBorder
    }
}

