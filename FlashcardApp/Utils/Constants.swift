//
//  Constants.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/08.
//

import Foundation
import UIKit

class Constants {
    static var currentBarStyle: UIStatusBarStyle = .darkContent
    
    static var mainView: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
}
