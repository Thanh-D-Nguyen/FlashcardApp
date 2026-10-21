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
