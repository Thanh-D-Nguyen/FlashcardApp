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
                return "Cấp độ"
            case .desk:
                return "Bộ thẻ"
            case .card:
                return "Thẻ"
            case .dictionary:
                return "Từ điển"
            case .setting:
                return "Cài đặt"
        }
    }
    
    var image: UIImage? {
        switch self {
            case .home:
                return UIImage(systemName: "graduationcap")
            case .desk:
                return UIImage(systemName: "menucard")
            case .card:
                return UIImage(systemName: "rectangle.stack")
            case .dictionary:
                return UIImage(systemName: "character.book.closed")
            case .setting:
                return UIImage(systemName: "gearshape")
        }
    }

    /// Filled variant used for the selected tab.
    var selectedImage: UIImage? {
        switch self {
            case .home:
                return UIImage(systemName: "graduationcap.fill")
            case .desk:
                return UIImage(systemName: "menucard.fill")
            case .card:
                return UIImage(systemName: "rectangle.stack.fill")
            case .dictionary:
                return UIImage(systemName: "character.book.closed.fill")
            case .setting:
                return UIImage(systemName: "gearshape.fill")
        }
    }

    var tabBarItem: UITabBarItem {
        let item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
        item.tag = rawValue
        return item
    }
}
