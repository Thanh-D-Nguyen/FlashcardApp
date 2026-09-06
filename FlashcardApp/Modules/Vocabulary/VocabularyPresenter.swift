//
//  VocabularyPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/10/01.
//  
//

import Foundation
import UIKit

enum VocabularySections: Int {
    case mean // Nghĩa
    case synonyms // Đồng nghĩa
    case antonyms // Trái nghĩa
    case sentences // Câu
    case relate // Liên quan
    
    var description: String {
        switch self {
            case .mean:
                return "Nghĩa"
            case .synonyms:
                return "Đồng nghĩa"
            case .antonyms:
                return "Trái nghĩa"
            case .sentences:
                return "Câu"
            case .relate:
                return "Liên quan"
        }
    }
    
    static let sectionCount = 5
}

protocol VocabularyPresenterInterface: AnyObject {
    func updateSearchKeyword(_ keyword: String)
    func viewDidLoad()
}

class VocabularyPresenter {
    private let interactor: VocabularyInteractorInterface
    private let wireframe: VocabularyWireframeInterface

    init(interactor: VocabularyInteractorInterface, 
        wireframe: VocabularyWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

// TODO: [Layer 3 Audit] VocabularyPresenter methods are currently empty.
// DictionaryPresenter creates VocabularyWireframe directly (tight coupling).
// Determine if vocabulary search is placeholder or needs implementation.
// If unused, remove Vocabulary module and decouple from DictionaryPresenter.
extension VocabularyPresenter: VocabularyPresenterInterface {
    func updateSearchKeyword(_ keyword: String) {

    }

    func viewDidLoad() {

    }
}
