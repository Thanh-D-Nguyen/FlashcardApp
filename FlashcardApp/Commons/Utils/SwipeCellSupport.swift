//
//  SwipeCellSupport.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/05.
//
import UIKit

class IndicatorView: UIView {
    var color = UIColor.clear {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        color.set()
        UIBezierPath(ovalIn: rect).fill()
    }
}

enum ActionDescriptor {
    case up, down, trash, vi, ja
    
    func title(forDisplayMode displayMode: ButtonDisplayMode) -> String? {
        guard displayMode != .imageOnly else { return nil }
        
        switch self {
            case .up: return "Up"
            case .down: return "Down"
            case .trash: return "Trash"
            default: return ""
        }
    }
    
    func image(forStyle style: ButtonStyle, displayMode: ButtonDisplayMode) -> UIImage? {
        guard displayMode != .titleOnly else { return nil }
        let name: String
        switch self {
            case .up: name = "arrow.up"
            case .down: name = "arrow.down"
            case .trash: name = "trash.fill"
            case .vi: name = "VN"
            case .ja: name = "JP"
        }
        
        if style == .backgroundColor {
            let config = UIImage.SymbolConfiguration(pointSize: 23.0, weight: .regular)
            return UIImage(systemName: name, withConfiguration: config)
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .regular)
            let image = UIImage(systemName: name, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysTemplate)
            return circularIcon(with: color(forStyle: style), size: CGSize(width: 50, height: 50), icon: image)
        }
    }
    
    func color(forStyle style: ButtonStyle) -> UIColor {
        switch self {
            case .up, .down: return UIColor.systemBlue
            case .trash: return UIColor.systemRed
            case .ja, .vi: return UIColor.systemTeal
        }
    }
    
    func circularIcon(with color: UIColor, size: CGSize, icon: UIImage? = nil) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        UIBezierPath(ovalIn: rect).addClip()
        
        color.setFill()
        UIRectFill(rect)
        
        if let icon = icon {
            let iconRect = CGRect(x: (rect.size.width - icon.size.width) / 2,
                                  y: (rect.size.height - icon.size.height) / 2,
                                  width: icon.size.width,
                                  height: icon.size.height)
            icon.draw(in: iconRect, blendMode: .normal, alpha: 1.0)
        }
        
        defer { UIGraphicsEndImageContext() }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

enum ButtonDisplayMode {
    case titleAndImage, titleOnly, imageOnly
}

enum ButtonStyle {
    case backgroundColor, circular
}
