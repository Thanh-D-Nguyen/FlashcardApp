//
//  DictionaryViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

final class DictionaryViewController: BaseViewController {
    var presenter: DictionaryPresenterInterface!

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