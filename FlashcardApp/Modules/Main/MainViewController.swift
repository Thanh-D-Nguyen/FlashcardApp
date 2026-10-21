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

    // The tab controller is embedded as a child; let it decide the status bar style.
    override var childForStatusBarStyle: UIViewController? { children.first }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        tabBarContainerView.backgroundColor = Design.Color.background
        view.backgroundColor = Design.Color.background
    }
    
    func subscribe() {
        subscribe(presenter.createdTabbarControllerRelay) { [weak self] tabbarController in
            guard let self else { return }
            self.updateTabbarController(tabbarController)
        }
    }
    
    private func updateTabbarController(_ controller: MainTabbarController) {
        addChild(controller)
        tabBarContainerView.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabBarContainerView.topAnchor.constraint(equalTo: controller.view.topAnchor),
            tabBarContainerView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
            tabBarContainerView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            tabBarContainerView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor)
        ])
        controller.didMove(toParent: self)
    }
}
