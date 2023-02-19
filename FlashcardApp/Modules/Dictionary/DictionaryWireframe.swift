//
//  DictionaryWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol DictionaryWireframeInterface: AnyObject {

}

final class DictionaryWireframe: BaseWireframe<DictionaryViewController> {

    private let storyboard = UIStoryboard(name: "Dictionary", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: DictionaryViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.dictionary.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.dictionary.title, image: MainTabbarName.dictionary.image, tag: MainTabbarName.dictionary.rawValue)
        let interactor = DictionaryInteractor() 
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension DictionaryWireframe: DictionaryWireframeInterface {

}
