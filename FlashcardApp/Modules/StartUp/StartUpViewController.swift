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
    
    @IBOutlet private weak var percentLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillApprear()
    }
    
    func setupUI() { }
    
    func subscribe() {
        subscribe(presenter.progressTextRelay) { [weak self] progressText in
            guard let self else { return }
            print("progressPercentage", progressText)

            self.percentLabel.text = progressText
        }
    }
}
