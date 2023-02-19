//
//  WelcomeMainWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/12.
//

import UIKit

protocol WelcomeMainWireframeInterface: AnyObject {
    func showEmailLoginWithType(_ type: EmailLoginType, userInfo: SocialUserEntity?)
}

class WelcomeMainWireframe: BaseWireframe<WelcomeMainViewController> {
    private let storyboard = UIStoryboard(name: "WelcomeMain", bundle: nil)
    
    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: WelcomeMainViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = WelcomeMainInteractor()
        let presenter = WelcomeMainPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }

}

extension WelcomeMainWireframe: WelcomeMainWireframeInterface {
    func showEmailLoginWithType(_ type: EmailLoginType, userInfo: SocialUserEntity?) {
        navigationController?.setRootWireframe(MailLoginWireframe(type, userInfo: userInfo))
    }
}
