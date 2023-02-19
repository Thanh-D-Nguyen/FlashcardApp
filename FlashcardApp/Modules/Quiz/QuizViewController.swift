//
//  QuizViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

final class QuizViewController: BaseViewController {
    var presenter: QuizPresenterInterface!

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