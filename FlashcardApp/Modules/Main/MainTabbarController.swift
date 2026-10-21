//
//  MainTabbarController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//

import UIKit

class MainTabbarController: UITabBarController {
    override var childForStatusBarStyle: UIViewController? {
        self.viewControllers?[self.selectedIndex]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // The system tab bar floats as Liquid Glass above content; it keeps its default
        // appearance (no custom background) and always shows icon + label for the four tabs.
        view.backgroundColor = Design.Color.background
    }
}
