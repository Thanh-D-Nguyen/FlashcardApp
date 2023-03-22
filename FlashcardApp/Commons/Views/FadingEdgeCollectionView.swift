//
//  FadingEdgeCollectionView.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/18.
//

import UIKit

var ActionBlockKey: UInt8 = 0

// a type for our action block closure
typealias BlockButtonActionBlock = (_ sender: UIButton) -> Void

class ActionBlockWrapper : NSObject {
    var block : BlockButtonActionBlock
    init(block: @escaping BlockButtonActionBlock) {
        self.block = block
    }
}

extension UIButton {
    func onClick(_ block: @escaping BlockButtonActionBlock) {
        objc_setAssociatedObject(self, &ActionBlockKey, ActionBlockWrapper(block: block), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(self, action: #selector(UIButton.block_handleAction(_:)), for: .touchUpInside)
    }
    
    @objc func block_handleAction(_ sender: UIButton) {
        let wrapper = objc_getAssociatedObject(self, &ActionBlockKey) as! ActionBlockWrapper
        wrapper.block(sender)
    }
}


public class FadingEdgesCollectionView: UICollectionView {
    private let fadeTagLeft = Int(NSDate().timeIntervalSince1970 * 1000) + 7110
    private let fadeTagRight = Int(NSDate().timeIntervalSince1970 * 1000) + 7120
    private let fadeTagTop = Int(NSDate().timeIntervalSince1970 * 1000) + 7130
    private let fadeTagBottom = Int(NSDate().timeIntervalSince1970 * 1000) + 7140
    
    public var gradientLength: CGFloat = 75.0 {
        willSet(newValue) {
            removeComponents(.gradients)
        }
        didSet {
            addComponents(.gradients)
        }
    }
    
    public var edgesToFade: UIRectEdge = .all {
        willSet(newValue) {
            removeComponents()
        }
        didSet {
            addComponents(components)
        }
    }
    
    public var arrowLength: CGFloat = 30.0 {
        willSet(newValue) {
            removeComponents(.arrows)
        }
        didSet {
            addComponents(.arrows)
        }
    }
    
    public var showArrows: Bool = true {
        didSet {
            removeComponents(.arrows)
            if (showArrows) {
                components.insert(.arrows)
                addComponents(.arrows)
            } else {
                components.remove(.arrows)
            }
        }
    }
    
    public override var backgroundColor: UIColor? {
        willSet {
            removeComponents(.gradients)
        }
        didSet {
            addComponents(.gradients)
        }
    }
    
    public var showGradients: Bool = true {
        didSet {
            removeComponents(.gradients)
            if (showGradients) {
                components.insert(.gradients)
                addComponents(.gradients)
            } else {
                components.remove(.gradients)
            }
        }
    }
    
    struct Components: OptionSet {
        let rawValue: Int
        static let gradients = Components(rawValue: 1 << 0)
        static let arrows = Components(rawValue: 1 << 1)
        static let all: Components = [.gradients, .arrows]
    }
    
    private var components: Components = .all
    
    public var fadeDistance: CGFloat = 25.0 {
        didSet {
            superview?.layoutSubviews()
        }
    }
    
    func removeComponents(_ components: Components = .all) {
        if (components.contains(.arrows)) {
            superview?.viewWithTag(fadeTagLeft + 1)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagRight + 1)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagTop + 1)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagBottom + 1)?.removeFromSuperview()
        }
        
        if (components.contains(.gradients)) {
            superview?.viewWithTag(fadeTagLeft)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagRight)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagTop)?.removeFromSuperview()
            superview?.viewWithTag(fadeTagBottom)?.removeFromSuperview()
        }
    }
    
    private func setAppropriateEdgeAlphaAndUpdateGradientBounds() {
        if (edgesToFade.contains(.left)) {
            if let gradient = superview?.viewWithTag(fadeTagLeft) {
                gradient.alpha = contentOffset.x / fadeDistance
                gradient.layer.mask?.frame = gradient.bounds
            }
            superview?.viewWithTag(fadeTagLeft + 1)?.alpha = contentOffset.x / fadeDistance
        }
        if (edgesToFade.contains(.right)) {
            let part1 = contentSize.width - contentOffset.x - self.bounds.width - fadeDistance
            
            if let gradient = superview?.viewWithTag(fadeTagRight) {
                gradient.alpha = CGFloat(1 - ((part1) / -fadeDistance))
                gradient.layer.mask?.frame = gradient.bounds
            }
            superview?.viewWithTag(fadeTagRight + 1)?.alpha = CGFloat(1 - ((part1) / -fadeDistance))
        }
        if (edgesToFade.contains(.top)) {
            if let gradient = superview?.viewWithTag(fadeTagTop) {
                gradient.alpha = contentOffset.y / fadeDistance
                gradient.layer.mask?.frame = gradient.bounds
            }
            superview?.viewWithTag(fadeTagTop + 1)?.alpha = contentOffset.y / fadeDistance
        }
        if (edgesToFade.contains(.bottom)) {
            let part1 = contentSize.height - contentOffset.y - self.bounds.height - fadeDistance
            
            if let gradient = superview?.viewWithTag(fadeTagBottom) {
                gradient.alpha = CGFloat(1 - ((part1) / -fadeDistance))
                gradient.layer.mask?.frame = gradient.bounds
            }
            superview?.viewWithTag(fadeTagBottom + 1)?.alpha = CGFloat(1 - ((part1) / -fadeDistance))
        }
    }
    
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        addComponents(components)
    }
    
    private func addComponents(_ components: Components = .all) {
        if (edgesToFade.contains(.left)) {
            addComponents(side: .left, components: components)
        }
        if (edgesToFade.contains(.right)) {
            addComponents(side: .right, components: components)
        }
        if (edgesToFade.contains(.top)) {
            addComponents(side: .top, components: components)
        }
        if (edgesToFade.contains(.bottom)) {
            addComponents(side: .bottom, components: components)
        }
        setAppropriateEdgeAlphaAndUpdateGradientBounds()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        setAppropriateEdgeAlphaAndUpdateGradientBounds()
    }
    
    private func addComponents(side: NSLayoutConstraint.Attribute, components: Components) {
        let debug = false
        
        let arrowsOn = components.contains(.arrows)
        let gradientsOn = components.contains(.gradients)
        
        // initialize views
        var vGradient = UIView()
        var btnArrow = UIButton()
        
        if (arrowsOn) {
            switch side {
                case .left, .right:
                    btnArrow = UIButton(frame: CGRect(x: 0, y: 0, width: Int(arrowLength), height: Int(self.bounds.height)))
                case .top, .bottom:
                    btnArrow = UIButton(frame: CGRect(x: 0, y: 0, width: Int(self.bounds.width), height: Int(arrowLength)))
                default:
                    break
            }
        }
        
        if (gradientsOn) {
            switch side {
                case .left, .right:
                    vGradient = UIView(frame: CGRect(x: 0, y: 0, width: Int(gradientLength), height: Int(self.bounds.height)))
                case .top, .bottom:
                    vGradient = UIView(frame: CGRect(x: 0, y: 0, width: Int(self.bounds.width), height: Int(gradientLength)))
                default:
                    break
            }
        }
        
        // get a view
        if (arrowsOn) {
            btnArrow.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            switch side {
                case .left:
                    btnArrow.tag = fadeTagLeft + 1
                case .right:
                    btnArrow.tag = fadeTagRight + 1
                    btnArrow.imageView?.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi))
                case .bottom:
                    btnArrow.tag = fadeTagBottom + 1
                    let img = UIImage(cgImage: btnArrow.imageView!.image!.cgImage!, scale: UIScreen.main.scale, orientation: .left)
                    btnArrow.setImage(img, for: .normal)
                case .top:
                    btnArrow.tag = fadeTagTop + 1
                    let img = UIImage(cgImage: btnArrow.imageView!.image!.cgImage!, scale: UIScreen.main.scale, orientation: .right)
                    btnArrow.setImage(img, for: .normal)
                default:
                    break
            }
            
            btnArrow.alpha = 0
            btnArrow.imageView!.contentMode = .scaleAspectFit
            
            btnArrow.onClick({ (sender) in self.setContentOffset(self.rightOffsetFor(direction: side, distance: 80), animated: true) })
            
            if (debug) {
                btnArrow.imageView!.alpha = 0.7
                btnArrow.imageView!.backgroundColor = UIColor.red
                btnArrow.backgroundColor = UIColor.green
            }
            
            superview?.addSubview(btnArrow)
        }
        
        if (gradientsOn) {
            switch side {
                case .left:
                    vGradient.tag = fadeTagLeft
                case .right:
                    vGradient.tag = fadeTagRight
                case .bottom:
                    vGradient.tag = fadeTagBottom
                case .top:
                    vGradient.tag = fadeTagTop
                default:
                    break
            }
            
            vGradient.isUserInteractionEnabled = false
//            vGradient.backgroundColor = debug ? .red : backgroundColor
            vGradient.alpha = 0
            
            // add gradient
            let gradient = CAGradientLayer()
            gradient.frame = vGradient.frame
            
            switch side {
                case .left, .right:
                    gradient.startPoint = CGPoint(x: side == .left ? 0.0 : 1.0, y: 0.5)
                    gradient.endPoint = CGPoint(x: side == .left ? 1.0 : 0.0, y: 0.5)
                case .bottom, .top:
                    gradient.startPoint = CGPoint(x: CGFloat(0.5), y: CGFloat(side == .top ? 0.0 : 1.0))
                    gradient.endPoint = CGPoint(x: CGFloat(0.5), y: CGFloat(side == .top ? 1.0 : 0.0))
                default:
                    break
            }
            gradient.colors = [UIColor.black, UIColor.clear]
            gradient.locations = [0, 1]
            vGradient.layer.mask = gradient
            
            if let btnArrow = superview?.viewWithTag(vGradient.tag + 1) {
                superview?.insertSubview(vGradient, belowSubview: btnArrow)
            } else {
                superview?.addSubview(vGradient)
            }
        }
        
        // add constraints
        func addConstraintsTo(view: UIView?, width: CGFloat) {
            if let view = view {
                switch side {
                    case .left, .right:
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0))
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: width))
                    case .bottom, .top:
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: width))
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: 0))
                        superview?.addConstraint(NSLayoutConstraint(item: view, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: 0))
                    default:
                        break
                }
            }
        }
        
        if (arrowsOn) {
            btnArrow.translatesAutoresizingMaskIntoConstraints = false
            superview?.addConstraint(NSLayoutConstraint(item: btnArrow, attribute: side, relatedBy: .equal, toItem: self, attribute: side, multiplier: 1, constant: 0))
            addConstraintsTo(view: btnArrow, width: arrowLength)
        }
        
        if (gradientsOn) {
            vGradient.translatesAutoresizingMaskIntoConstraints = false
            superview?.addConstraint(NSLayoutConstraint(item: vGradient, attribute: side, relatedBy: .equal, toItem: self, attribute: side, multiplier: 1, constant: 0))
            addConstraintsTo(view: vGradient, width: gradientLength)
        }
    }
    
    private func rightOffsetFor(direction: NSLayoutConstraint.Attribute, distance: CGFloat) -> CGPoint {
        switch direction {
            case .left:
                return CGPoint(x: max(contentOffset.x - distance, 0), y: 0)
            case .right:
                return CGPoint(x: min(contentOffset.x + distance, contentSize.width - self.bounds.width), y: 0)
            case .bottom:
                return CGPoint(x: 0, y: min(contentOffset.y + distance, contentSize.height - self.bounds.height))
            case .top:
                return CGPoint(x: 0, y: max(contentOffset.y - distance, 0))
            default:
                return CGPoint(x: 0, y: 0)
        }
    }
}
