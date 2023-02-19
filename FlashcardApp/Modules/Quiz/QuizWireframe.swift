//
//  QuizWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol QuizWireframeInterface: AnyObject {

}

final class QuizWireframe: BaseWireframe<QuizViewController> {

    private let storyboard = UIStoryboard(name: "Quiz", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: QuizViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.quiz.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.quiz.title, image: MainTabbarName.quiz.image, tag: MainTabbarName.quiz.rawValue)
        let interactor = QuizInteractor() 
        let presenter = QuizPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension QuizWireframe: QuizWireframeInterface {

}
