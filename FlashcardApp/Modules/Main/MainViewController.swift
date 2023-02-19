//
//  MainViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

final class MainViewController: BaseViewController {

    var presenter: MainPresenterInterface!
    
    @IBOutlet
    private weak var tabBarContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        tabBarContainerView.backgroundColor = .white
    }
    
    func subscribe() {
        subscribe(presenter.createdTabbarControllerRelay) { [weak self] tabbarController in
            guard let self else { return }
            self.updateTabbarController(tabbarController)
        }
    }
    
    private func updateTabbarController(_ controller: MainTabbarController) {
        tabBarContainerView.addSubview(controller.view)
        controller.didMove(toParent: self)
        self.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainerView.topAnchor.constraint(equalTo: controller.view.topAnchor).isActive = true
        tabBarContainerView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor).isActive = true
        tabBarContainerView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor).isActive = true
        tabBarContainerView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor).isActive = true
    }
}
