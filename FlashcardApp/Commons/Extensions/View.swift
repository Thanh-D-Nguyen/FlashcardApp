//
//  View.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/15.
//

import UIKit

extension UIView {
    ///
    /// Loads a view from nib.
    ///
    /// Please note that if you are assigning directly to an optinonal or unwrapped
    /// optional you have to specify `name` of the nib.
    ///
    class func loadFromNib<T>(_ name: String = String(describing: T.self), owner: AnyObject? = nil, options: [UINib.OptionsKey: Any]? = nil, bundle: Bundle? = Bundle.main) -> T {
        return UINib(nibName: name, bundle: bundle).instantiate(withOwner: owner, options: options).first as! T
    }
    
    class func loadFromNib<T>(_ name: String = String(describing: T.self), index: Int) -> T {
        return UINib(nibName: name, bundle: nil).instantiate(withOwner: nil, options: nil)[index] as! T
    }
}

protocol NibInstantiate {
    func instantiate()
}

extension NibInstantiate where Self: UIView {
    func instantiate() {
        let className = String(describing: type(of: self))
        let nib = UINib(nibName: className, bundle: nil)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        view.frame = bounds
        addSubview(view)
    }
}

/// Constraints

extension UIView {
    @discardableResult
    public func fill(with view: UIView, edges: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let constraints = [
            NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: edges.left),
            NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: edges.top),
            NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: edges.right),
            NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: edges.bottom)
        ]
        addConstraints(constraints)
        return constraints
    }
    
    public func center(to view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        superview?.addConstraints([
            NSLayoutConstraint(item: view, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: view, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0)
        ])
    }
    
    public func equalSize(to view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        superview?.addConstraints([
            NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1, constant: 0)
        ])
    }
}
