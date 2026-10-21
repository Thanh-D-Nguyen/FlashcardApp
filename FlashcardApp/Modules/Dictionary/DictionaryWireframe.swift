//
//  DictionaryWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol DictionaryWireframeInterface: AnyObject {
    func showResult(_ result: BJTSearchResultDTO)
}

final class DictionaryWireframe: BaseWireframe<DictionaryViewController> {

    init() {
        let moduleViewController = DictionaryViewController()
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.dictionary.title
        moduleViewController.tabBarItem = MainTabbarName.dictionary.tabBarItem
        let interactor = DictionaryInteractor() 
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension DictionaryWireframe: DictionaryWireframeInterface {
    func showResult(_ result: BJTSearchResultDTO) {
        showAlert(with: result.title, message: [result.reading, result.description, result.jlptLevel]
            .compactMap { $0 }.joined(separator: "\n\n"))
    }
}
