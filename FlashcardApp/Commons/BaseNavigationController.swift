//
//  BaseNavigationController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/12.
//

import UIKit

class BaseNavigationController: UINavigationController {
    
    override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = Design.Color.background
        // Bars keep the system appearance: iOS 26 draws them as glass over content, so no
        // custom background or UIBarAppearance is set. Screens that own a header hide the bar.
        navigationBar.prefersLargeTitles = true
        isNavigationBarHidden = true
    }
}
