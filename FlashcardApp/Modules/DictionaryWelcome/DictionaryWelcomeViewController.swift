//
//  DictionaryWelcomeViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/06/02.
//  
//

import UIKit

final class DictionaryWelcomeViewController: BaseViewController {
    var presenter: DictionaryWelcomePresenterInterface!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {

    }

    func subscribe() {

    }
}