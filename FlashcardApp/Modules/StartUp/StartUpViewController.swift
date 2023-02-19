//
//  StartUpViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

final class StartUpViewController: BaseViewController {
    var presenter: StartUpPresenterInterface!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() { }
    
    func subscribe() { }
}
