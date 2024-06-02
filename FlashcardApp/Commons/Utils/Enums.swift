//
//  Enums.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

// Welcome
enum WelcomeType {
    case show, main, emailLogin, signUpLogin
}
enum SignInType: Int {
    case signUpWithMail = 1
    case apple
    case google
    case facebook
}

enum CardFace {
    case front, back
}

enum MainTabbarName: Int {
    case home
    case quiz
    case desk
    case card
    case dictionary
    case setting
    
    var title: String {
        switch self {
            case .home:
                return NSLocalizedString("Home", comment: "")
            case .quiz:
                return NSLocalizedString("Quiz", comment: "")
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
            case .quiz:
                return UIImage(systemName: "checklist")
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

enum PhotoSize: String {
    case thumbnail = "q"
    case large = "b"
}
