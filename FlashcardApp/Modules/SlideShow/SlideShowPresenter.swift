//
//  SlideShowPresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import UIKit

protocol SlideShowPresenterInterface: AnyObject {
    func viewDidLoad()
    
    func pageBefore(_ viewController: UIViewController?) -> UIViewController?
    func pageAfter(_ viewController: UIViewController) -> UIViewController?
    
    func getStartedAction()
}

class SlideShowPresenter {
    private let interactor: SlideShowInteractorInterface
    private let wireframe: SlideShowWireframeInterface
        
    init(interactor: SlideShowInteractorInterface,
         wireframe: SlideShowWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SlideShowPresenter: SlideShowPresenterInterface {
    func viewDidLoad() { }
    
    func pageBefore(_ viewController: UIViewController?) -> UIViewController? {
        if viewController == nil {
            return wireframe.createSlidePageItem(WelcomeEntity(index: 0))
        }
        guard let index = (viewController as? SlideItemViewController)?.index else {
            return nil
        }
        let previousIndex = index - 1
        guard previousIndex >= 0 else {
            return nil
        }
        guard WelcomeEntity.pageCount > previousIndex else { return nil }
        return wireframe.createSlidePageItem(WelcomeEntity(index: previousIndex))
    }
    
    func pageAfter(_ viewController: UIViewController) -> UIViewController? {
        guard let index = (viewController as? SlideItemViewController)?.index else {
            return nil
        }
        let nextIndex = index + 1
        guard nextIndex < WelcomeEntity.pageCount else {
            return nil
        }
        
        guard WelcomeEntity.pageCount > nextIndex else { return nil }
        return wireframe.createSlidePageItem(WelcomeEntity(index: nextIndex))
    }
    
    func getStartedAction() {
        wireframe.navigateToGetStarted()
    }
}
