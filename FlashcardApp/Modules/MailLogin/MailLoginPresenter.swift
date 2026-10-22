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
    case error(String)
}

protocol MailLoginPresenterInterface: AnyObject {
    var mailPlaceHolderAttributedText: NSAttributedString { get }
    var titleText: String { get }
    var subtitleText: String { get }
    var loginButtonText: String { get }
    var viewState: BehaviorRelay<MailLoginViewState> { get }

    func loginWithEmail(email: String, password: String)
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

    private func finishLogin(_ request: SingleAssignmentDisposable, error: Error?) {
        guard loginRequest === request else { return }
        loginRequest = nil
        request.dispose()
        if let error {
            viewState.accept(.error(error.localizedDescription))
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
        let components = email.split(separator: "@", omittingEmptySubsequences: false)
        guard components.count == 2, components.allSatisfy({ !$0.isEmpty }),
              email.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            viewState.accept(.error(NSLocalizedString("Enter a valid email address.", comment: "")))
            return
        }
        guard !password.isEmpty else {
            viewState.accept(.error(NSLocalizedString("Enter your password.", comment: "")))
            return
        }

        let request = SingleAssignmentDisposable()
        loginRequest = request
        viewState.accept(.loading)
        guard loginRequest === request else { return }
        request.setDisposable(interactor.login(email: email, password: password)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self, weak request] _ in
                guard let request else { return }
                self?.finishLogin(request, error: nil)
            }, onFailure: { [weak self, weak request] error in
                guard let request else { return }
                self?.finishLogin(request, error: error)
            }))
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
