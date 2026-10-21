//
//  MailLoginViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit
import RxSwift

final class MailLoginViewController: BaseViewController {
    
    private let textFieldMailButtonTag = 1
    private let textFieldPassButtonTag = 2

    var presenter: MailLoginPresenterInterface!
    @IBOutlet weak private var titleTextLabel: UILabel!
    @IBOutlet weak private var messageLabel: UILabel!
    @IBOutlet weak private var mailTextField: UITextField!
    @IBOutlet weak private var passTextField: UITextField!
    @IBOutlet weak private var formStackView: UIStackView!
    
    @IBOutlet weak private var loginButton: UIButton!
    private let continueWithoutLoginButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.cancelLogin()
        view.endEditing(true)
        passTextField.text = nil
    }
    
    func setupUI() {
        titleTextLabel.text = presenter.titleText
        titleTextLabel.numberOfLines = 0
        titleTextLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: titleTextLabel.font)
        titleTextLabel.adjustsFontForContentSizeCategory = true
        loginButton.accessibilityIdentifier = "website_login_button"
        mailTextField.accessibilityIdentifier = "website_email"
        passTextField.accessibilityIdentifier = "website_password"
        loginButton.setTitle(presenter.loginButtonText, for: .normal)
        loginButton.titleLabel?.adjustsFontForContentSizeCategory = true
        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        let tapGuesture = UITapGestureRecognizer()
        tapGuesture.addTarget(self, action: #selector(self.dismissKeyboard))
        tapGuesture.cancelsTouchesInView = false
        tapGuesture.delegate = self
        self.view.addGestureRecognizer(tapGuesture)
        mailTextField.attributedPlaceholder = presenter.mailPlaceHolderAttributedText
        passTextField.attributedPlaceholder = presenter.passPlaceHolderAttributedText
        configureTextFields()
        configureContinueButton()
    }

    private func configureTextFields() {
        mailTextField.keyboardType = .emailAddress
        mailTextField.textContentType = .emailAddress
        mailTextField.autocapitalizationType = .none
        mailTextField.autocorrectionType = .no
        mailTextField.returnKeyType = .next
        mailTextField.accessibilityLabel = NSLocalizedString("Email address", comment: "")
        passTextField.isSecureTextEntry = true
        passTextField.textContentType = .password
        passTextField.autocapitalizationType = .none
        passTextField.autocorrectionType = .no
        passTextField.returnKeyType = .go
        passTextField.accessibilityLabel = NSLocalizedString("Password", comment: "")
        for field in [mailTextField, passTextField].compactMap({ $0 }) {
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.delegate = self
        }
    }

    private func configureContinueButton() {
        continueWithoutLoginButton.setTitle(NSLocalizedString("Continue without login", comment: ""), for: .normal)
        continueWithoutLoginButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        continueWithoutLoginButton.titleLabel?.adjustsFontForContentSizeCategory = true
        continueWithoutLoginButton.titleLabel?.numberOfLines = 0
        continueWithoutLoginButton.titleLabel?.textAlignment = .center
        continueWithoutLoginButton.accessibilityIdentifier = "continueWithoutLoginButton"
        continueWithoutLoginButton.addTarget(self, action: #selector(continueWithoutLoginAction), for: .touchUpInside)
        formStackView.insertArrangedSubview(continueWithoutLoginButton, at: formStackView.arrangedSubviews.count - 1)
        continueWithoutLoginButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
    
    func subscribe() {
        presenter.viewState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in self?.render(state) })
            .disposed(by: disposeBag)
    }

    private func render(_ state: MailLoginViewState) {
        let isLoading = state == .loading
        loginButton.isEnabled = !isLoading
        loginButton.alpha = isLoading ? 0.6 : 1
        loginButton.setTitle(isLoading ? NSLocalizedString("Signing in…", comment: "") : presenter.loginButtonText, for: .normal)
        mailTextField.isEnabled = !isLoading
        passTextField.isEnabled = !isLoading
        messageLabel.textColor = .secondaryLabel
        switch state {
        case .idle:
            messageLabel.text = NSLocalizedString("Use your existing website account, or continue without login to study offline.", comment: "")
        case .loading:
            messageLabel.text = NSLocalizedString("Signing in to your website account…", comment: "")
        case .error(let message):
            messageLabel.text = message
            messageLabel.textColor = .systemRed
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    @objc
    private func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    @IBAction
    private func loginWithEmailAction() {
        view.endEditing(true)
        presenter.loginWithEmail(email: mailTextField.text ?? "", password: passTextField.text ?? "")
    }

    @objc private func continueWithoutLoginAction() {
        view.endEditing(true)
        presenter.continueWithoutLogin()
    }
    
    @IBAction
    private func displayKeyboardAction(_ sender: UIButton) {
        if sender.tag == textFieldMailButtonTag {
            mailTextField.becomeFirstResponder()
        } else if sender.tag == textFieldPassButtonTag {
            passTextField.becomeFirstResponder()
        }
    }
}

extension MailLoginViewController: UITextFieldDelegate, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view else { return true }
        return !touchedView.isDescendant(of: mailTextField) && !touchedView.isDescendant(of: passTextField)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === mailTextField {
            passTextField.becomeFirstResponder()
        } else {
            loginWithEmailAction()
        }
        return false
    }
}
