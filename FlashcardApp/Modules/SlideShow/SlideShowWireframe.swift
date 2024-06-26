//
//  SlideShowWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

protocol SlideShowWireframeInterface: AnyObject {
    func navigateToGetStarted()
    func createSlidePageItem(_ entity: WelcomeEntity) -> UIViewController
}

final class SlideShowWireframe: BaseWireframe<SlideShowViewController> {
    
    private let storyboard = UIStoryboard(name: "SlideShow", bundle: nil)
    
    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: SlideShowViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = SlideShowInteractor()
        let presenter = SlideShowPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
        let welcomeInteractor = WelcomeMainInteractor()
        let welcomePresenter = WelcomeMainPresenter(interactor: welcomeInteractor, wireframe: self)
        moduleViewController.welcomePresenter = welcomePresenter
    }
}

// MARK: - Extensions -
extension SlideShowWireframe: SlideShowWireframeInterface {
    
    func navigateToGetStarted() {
        self.navigationController?.setRootWireframe(WelcomeMainWireframe())
    }
    
    func createSlidePageItem(_ entity: WelcomeEntity) -> UIViewController {
        let moduleViewController = storyboard.instantiateViewController(ofType: SlideItemViewController.self)
        moduleViewController.updatePageItem(entity)
        return moduleViewController
    }
}

extension SlideShowWireframe: WelcomeMainWireframeInterface {
    func showEmailLoginWithType(_ type: EmailLoginType, userInfo: SocialUserEntity?) {
        navigationController?.setRootWireframe(MailLoginWireframe(type, userInfo: userInfo))
    }
}
