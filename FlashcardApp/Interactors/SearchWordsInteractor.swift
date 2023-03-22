//
//  SearchWordsInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/18.
//

import Foundation

protocol SearchWordsInteractorProtocol: AnyObject {
    func searchText(_ text: String?, cardFace: CardFace) -> SearchResultEntity
}

class SearchWordsInteractor {
    private func searchFront(_ text: String) -> SearchResultEntity {
        let cards = JaViManagement.shared.search(text)
        return SearchResultEntity(face: .front, cards: cards.map({ $0.toCard() }))
    }
    
    private func searchBack(_ text: String) -> SearchResultEntity {
        let cards = ViJaManagement.shared.search(text)
        return SearchResultEntity(face: .back, cards: cards.map({ $0.toCard() }))
    }
}

extension SearchWordsInteractor: SearchWordsInteractorProtocol {
    func searchText(_ text: String?, cardFace: CardFace) -> SearchResultEntity {
        guard let txt = text, !txt.isEmpty else { return SearchResultEntity(face: .front, cards: []) }
        if cardFace == .front {
            return searchFront(txt)
        } else {
            return searchBack(txt)
        }
    }
}
