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
        self.view.backgroundColor = .white
        self.isNavigationBarHidden = true
    }
}
