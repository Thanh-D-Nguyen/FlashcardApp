//
//  WelcomeMainViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/12.
//

import UIKit
import FBSDKLoginKit

class WelcomeMainViewController: BaseViewController {
    
    var presenter: WelcomeMainPresenterInterface!
    @IBOutlet private weak var signInFBButton: UIButton!
    private let facebookLoginButton = FBLoginButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }
    
    func setupUI() {
        view.addSubview(facebookLoginButton)
        view.sendSubviewToBack(facebookLoginButton)
        facebookLoginButton.translatesAutoresizingMaskIntoConstraints = false
        signInFBButton.topAnchor.constraint(equalTo: facebookLoginButton.topAnchor).isActive = true
        signInFBButton.leadingAnchor.constraint(equalTo: facebookLoginButton.leadingAnchor).isActive = true
        signInFBButton.trailingAnchor.constraint(equalTo: facebookLoginButton.trailingAnchor).isActive = true
        facebookLoginButton.delegate = self
    }
    
    func subscribe() {
        
    }
    
    @IBAction
    private func signInAction(_ sender: UIButton) {
        if sender.tag == SignInType.facebook.rawValue {
            // 1. Login Facebook by open webview
            facebookLoginButton.sendActions(for: .touchUpInside)
        } else {
            presenter.signInAction(sender.tag)
        }
    }
}

extension WelcomeMainViewController: LoginButtonDelegate {
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        // 2. Login Facebook using firebase
        presenter.signInAction(SignInType.facebook.rawValue)
    }
    
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        
    }
}
