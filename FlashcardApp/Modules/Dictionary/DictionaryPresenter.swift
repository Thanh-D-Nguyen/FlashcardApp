//
//  DictionaryPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation
import UIKit
import RxRelay

enum DictionarySearchType: Int, CaseIterable {
    case vocalbulary
    case kanji
    case grammar
    case sentence
    
    var description: String {
        switch self {
            case .vocalbulary:
                return "Từ vựng"
            case .kanji:
                return "Hán tự"
            case .grammar:
                return "Ngữ pháp"
            case .sentence:
                return "Câu"
        }
    }
    static func all() -> [String] {
        return self.allCases.map { $0.description }
    }
}

protocol DictionaryPresenterInterface: AnyObject {
    
    var createdPageControllerRelay: PublishRelay<UIPageViewController> { get }
    var createdWelcomeControllerRelay: PublishRelay<UIPageViewController> { get }

    func searchText(_ text: String?, withType type: Int)
    func viewDidLoad()
}

class DictionaryPresenter {
    private let interactor: DictionaryInteractorInterface
    private let wireframe: DictionaryWireframeInterface
    
    private var currentSearchText = ""
    private var currentSearchType: DictionarySearchType = .vocalbulary
    
    private let vocalWireFrame = VocabularyWireframe()
    private var vocalPresenter: VocabularyPresenterInterface {
        return vocalWireFrame.viewController.presenter
    }
    
    let createdPageControllerRelay = PublishRelay<UIPageViewController>()
    let createdWelcomeControllerRelay = PublishRelay<UIPageViewController>()

    init(interactor: DictionaryInteractorInterface, 
        wireframe: DictionaryWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
    
    private func createGroupPageView() -> UIPageViewController {
        let pageView = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageView.setViewControllers([vocalWireFrame.viewController], direction: .forward, animated: false)
        return pageView
    }
    
    private func createWelcomeController() -> UIViewController {
        
    }
}

extension DictionaryPresenter: DictionaryPresenterInterface {
    
    func searchText(_ text: String?, withType type: Int) {
        guard let keyword = text, let searchType = DictionarySearchType(rawValue: type) else {
            return
        }
        logger.debug("\(searchType): \(keyword)")
        
        if currentSearchText != keyword || searchType != currentSearchType {
            vocalPresenter.updateSearchKeyword(keyword)
        }
    }
    
    func viewDidLoad() {
        let groupPageView = createGroupPageView()
        createdPageControllerRelay.accept(groupPageView)
    }
}
