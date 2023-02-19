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

enum EmailLoginType {
    case login
    case register
}

protocol MailLoginPresenterInterface: AnyObject {
    var warningAttributedText: NSAttributedString { get }
    var mailPlaceHolderAttributedText: NSAttributedString { get }
    var passPlaceHolderAttributedText: NSAttributedString { get }
    var titleText: String { get }
    var loginButtonText: String { get }
    
    var userInfoRelay: PublishRelay<SocialUserEntity> { get }
    
    func loginWithEmail()
    func viewDidLoad()
}

class MailLoginPresenter {
    private let wireframe: MailLoginWireframeInterface
    private let interactor: MailLoginInteractorInterface
    
    let userInfoRelay = PublishRelay<SocialUserEntity>()
    
    private var loginType: EmailLoginType = .register
    private var userInfo: SocialUserEntity?
    
    var warningAttributedText: NSAttributedString {
        let warningText = NSLocalizedString("By clicking \"Create account\", I agree to SnackOverflow’s TOS and Privacy Policy.", comment: "")
        let attribuedTxt = NSMutableAttributedString(string: warningText)
        attribuedTxt.addAttribute(.link, value: "www.google.com", range: (warningText as NSString).range(of: "TOS"))
        attribuedTxt.addAttribute(.link, value: "www.yahoo.com", range: (warningText as NSString).range(of: "Privacy Policy."))
        return attribuedTxt
    }
    
    var mailPlaceHolderAttributedText: NSAttributedString {
        NSAttributedString(
            string: NSLocalizedString("mr.donuts@gmail.com", comment: ""),
            attributes: [.foregroundColor: UIColor(named: "clooneyColor") ?? UIColor.white])
    }
    
    var passPlaceHolderAttributedText: NSAttributedString {
        NSAttributedString(
            string: NSLocalizedString("password", comment: ""),
            attributes: [.foregroundColor: UIColor(named: "clooneyColor") ?? UIColor.white])
    }
    
    var titleText: String {
        return loginType == .register ?
        NSLocalizedString("Go with your flow.", comment: "") :
        NSLocalizedString("Welcome back!", comment: "")
    }
    
    var loginButtonText: String {
        return loginType == .register ?
        NSLocalizedString("Create account", comment: "") :
        NSLocalizedString("Login", comment: "")
    }
    
    init(
        interactor: MailLoginInteractorInterface,
        wireframe: MailLoginWireframeInterface
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
    
    func setLoginType(_ type: EmailLoginType, userInfo: SocialUserEntity?) {
        self.loginType = type
        self.userInfo = userInfo
    }
}

extension MailLoginPresenter: MailLoginPresenterInterface {
    func viewDidLoad() {
        if let userInfo = userInfo {
            userInfoRelay.accept(userInfo)
        }
    }
    func loginWithEmail() {
        wireframe.showMain()
    }
}
