//
//  DictionaryWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//
//

import UIKit

protocol DictionaryWireframeInterface: AnyObject {
    func showEntry(_ item: DictionaryItem)
    func showSaved()
    func showScanner()
    func showVoice()
    func showHandwriting()
}

final class DictionaryWireframe: BaseWireframe<DictionaryViewController> {
    private weak var presenter: DictionaryPresenter?

    init() {
        let moduleViewController = DictionaryViewController()
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.dictionary.title
        moduleViewController.tabBarItem = MainTabbarName.dictionary.tabBarItem
        let interactor = DictionaryInteractor()
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: self)
        self.presenter = presenter
        moduleViewController.presenter = presenter
    }
}

extension DictionaryWireframe: DictionaryWireframeInterface {
    func showEntry(_ item: DictionaryItem) {
        navigationController?.pushWireframe(DictionaryEntryWireframe(item: item, lookUp: lookUpHandler))
    }

    func showSaved() {
        navigationController?.pushWireframe(DictionarySavedWireframe(lookUp: lookUpHandler))
    }

    func showScanner() {
        let scanner = DictionaryScanWireframe(onLookUp: { [weak self] text in self?.presenter?.beginSearch(text) })
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let controller = scanner.viewController
        let container = BaseNavigationController(rootViewController: controller)
        container.isNavigationBarHidden = false
        container.navigationBar.prefersLargeTitles = false
        viewController.present(container, animated: true)
    }

    func showVoice() {
        let voice = DictionaryVoiceWireframe(onLookUp: { [weak self] text in self?.presenter?.beginSearch(text) })
        let controller = voice.viewController
        let container = BaseNavigationController(rootViewController: controller)
        container.isNavigationBarHidden = false
        container.navigationBar.prefersLargeTitles = false
        if let sheet = container.sheetPresentationController { sheet.detents = [.medium(), .large()] }
        viewController.present(container, animated: true)
    }

    func showHandwriting() {
        let handwriting = DictionaryHandwritingWireframe(onLookUp: { [weak self] text in self?.presenter?.beginSearch(text) })
        let controller = handwriting.viewController
        let container = BaseNavigationController(rootViewController: controller)
        container.isNavigationBarHidden = false
        container.navigationBar.prefersLargeTitles = false
        // Full screen, not a sheet: a downward stroke on the pad would otherwise be taken by the sheet's own drag gesture.
        container.modalPresentationStyle = .fullScreen
        viewController.present(container, animated: true)
    }

    /// Runs a search for a text the learner picked inside an entry (the entry screens call it after popping back).
    private var lookUpHandler: (String) -> Void {
        { [weak self] text in self?.presenter?.beginSearch(text) }
    }
}
