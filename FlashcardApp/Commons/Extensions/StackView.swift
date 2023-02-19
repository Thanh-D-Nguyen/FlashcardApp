//
//  StackView.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//
import UIKit

extension UIStackView {
    
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { view in
            view.removeFromSuperview()
        }
    }
}
