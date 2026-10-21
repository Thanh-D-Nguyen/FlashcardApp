//
//  Enums.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

enum CardFace {
    case front, back
}

enum MainTabbarName: Int {
    case home
    case desk
    case card
    case dictionary
    case setting
    
    var title: String {
        switch self {
            case .home:
                return NSLocalizedString("Home", comment: "")
            case .desk:
                return NSLocalizedString("Desk", comment: "")
            case .card:
                return NSLocalizedString("Card", comment: "")
            case .dictionary:
                return NSLocalizedString("Dictionary", comment: "")
            case .setting:
                return NSLocalizedString("Setting", comment: "")
        }
    }
    
    var image: UIImage? {
        switch self {
            case .home:
                return UIImage(systemName: "house")
            case .desk:
                return UIImage(systemName: "menucard")
            case .card:
                return UIImage(systemName: "menucard")
            case .dictionary:
                return UIImage(systemName: "doc.text.magnifyingglass")
            case .setting:
                return UIImage(systemName: "gear")
        }
    }
}
