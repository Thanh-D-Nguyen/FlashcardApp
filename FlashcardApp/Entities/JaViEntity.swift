//
//  JaViEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/18.
//

import Foundation

struct JaViEntity {
    var id: Int
    var means: JaViMeansEntity?
    var opposite: String
    var phonetic: String
    var pronunciation: String
    var relate: String
    var seq: Int
    var synsets: String
    var word: String
    var favorite: Bool
    
    init(_ obj: RJaVi) {
        self.id = obj.id
        self.means = try? JaViMeansEntity(obj.mean)
        self.opposite = obj.opposite
        self.phonetic = obj.phonetic
        self.pronunciation = obj.pronunciation
        self.relate = obj.relate
        self.seq = obj.seq
        self.synsets = obj.synsets
        self.word = obj.word
        self.favorite = obj.favorite
    }
}

extension JaViEntity {
    func toCard() -> CardEntity {
        CardEntity(id: "\(self.id)",
                   frontText: self.word,
                   frontExtraText: self.phonetic,
                   backText: self.means?.first?.mean ?? "",
                   backExtraText: "",
                   imageUrl: "",
                   videoUrl: "")
    }
}
