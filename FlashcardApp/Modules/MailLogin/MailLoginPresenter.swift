//
//  MailLoginPresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import Foundation
import UIKit
import RxRelay
import RxSwift

enum MailLoginViewState: Equatable {
    case idle
    case loading
    /// Google's account sheet is open, or its ID token is being exchanged for a website session.
    case signingInWithGoogle
    case signingInWithApple
    case error(String)
}

protocol MailLoginPresenterInterface: AnyObject {
    var mailPlaceHolderAttributedText: NSAttributedString { get }
    var titleText: String { get }
    var subtitleText: String { get }
    var loginButtonText: String { get }
    var googleButtonText: String { get }
    /// False when this build has no Google OAuth configuration; the view then hides the Google button.
    var isGoogleSignInAvailable: Bool { get }
    var viewState: BehaviorRelay<MailLoginViewState> { get }

    func loginWithEmail(email: String, password: String)
    func loginWithGoogle()
    func loginWithApple()
    func cancelLogin()
    func continueWithoutLogin()
}

final class MailLoginPresenter {
    private let wireframe: MailLoginWireframeInterface
    private let interactor: MailLoginInteractorInterface
    private var loginRequest: SingleAssignmentDisposable?

    let viewState = BehaviorRelay<MailLoginViewState>(value: .idle)
    
    var mailPlaceHolderAttributedText: NSAttributedString {
        NSAttributedString(
            string: NSLocalizedString("email@domain.com", comment: ""),
            attributes: [.foregroundColor: AppColors.placeholderText])
    }
    
    var titleText: String {
        NSLocalizedString("Welcome back", comment: "Login screen headline")
    }

    var subtitleText: String {
        NSLocalizedString("Use your existing website account, or continue without login to study offline.", comment: "")
    }

    var loginButtonText: String {
        NSLocalizedString("Sign In", comment: "")
    }

    var googleButtonText: String {
        NSLocalizedString("Continue with Google", comment: "Login screen Google button")
    }

    var isGoogleSignInAvailable: Bool {
        interactor.isGoogleSignInAvailable
    }
    
    init(
        interactor: MailLoginInteractorInterface,
        wireframe: MailLoginWireframeInterface
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
    
    deinit {
        loginRequest?.dispose()
    }

    /// Runs one sign-in attempt at a time. A second request while one is running is ignored.
    private func start(_ state: MailLoginViewState,
                       _ attempt: (MailLoginInteractorInterface) -> Single<SocialUserEntity>) {
        guard loginRequest == nil else { return }
        let request = SingleAssignmentDisposable()
        loginRequest = request
        viewState.accept(state)
        guard loginRequest === request else { return }
        request.setDisposable(attempt(interactor)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self, weak request] _ in
                guard let request else { return }
                self?.finishLogin(request, error: nil)
            }, onFailure: { [weak self, weak request] error in
                guard let request else { return }
                self?.finishLogin(request, error: error)
            }))
    }

    private func finishLogin(_ request: SingleAssignmentDisposable, error: Error?) {
        guard loginRequest === request else { return }
        loginRequest = nil
        request.dispose()
        if let error {
            // Closing Google's account sheet is a choice, not a failure.
            if (error as? GoogleSignInError) == .cancelled || (error as? AppleSignInError) == .cancelled {
                viewState.accept(.idle)
            } else {
                viewState.accept(.error(error.localizedDescription))
            }
        } else {
            viewState.accept(.idle)
            wireframe.showMain()
        }
    }
}

extension MailLoginPresenter: MailLoginPresenterInterface {
    func loginWithEmail(email: String, password: String) {
        guard loginRequest == nil else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            viewState.accept(.error(NSLocalizedString("Enter a valid email address.", comment: "")))
            return
        }
        guard !password.isEmpty else {
            viewState.accept(.error(NSLocalizedString("Enter your password.", comment: "")))
            return
        }
        guard password.utf8.count <= 1024 else {
            viewState.accept(.error(NSLocalizedString("Enter a valid email address and password.", comment: "")))
            return
        }

        start(.loading) { $0.login(email: email, password: password) }
    }

    func loginWithGoogle() {
        guard isGoogleSignInAvailable else {
            viewState.accept(.error(GoogleSignInError.notConfigured.localizedDescription))
            return
        }
        start(.signingInWithGoogle) { [wireframe] in $0.loginWithGoogle(presenting: wireframe.presentingViewController) }
    }

    func loginWithApple() {
        start(.signingInWithApple) { [wireframe] in $0.loginWithApple(presenting: wireframe.presentingViewController) }
    }

    func cancelLogin() {
        let request = loginRequest
        loginRequest = nil
        request?.dispose()
        viewState.accept(.idle)
    }

    func continueWithoutLogin() {
        cancelLogin()
        wireframe.showMain()
    }
}
