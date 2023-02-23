//
//  DeskViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

final class DeskViewController: BaseViewController {
    var presenter: DeskPresenterInterface!
    @IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var descTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        let tapGusture = UITapGestureRecognizer(target: self, action: #selector(dismissView))
        self.view.addGestureRecognizer(tapGusture)
    }

    func subscribe() {

    }
    
    @objc private func dismissView() {
        if nameTextField.isFirstResponder || descTextView.isFirstResponder {
            view.endEditing(true)
        } else {
            presenter.dismiss()
        }
    }
    
    @IBAction
    private func addDeskAction() {
        presenter.addDeskName(nameTextField.text, description: descTextView.text)
    }
}
