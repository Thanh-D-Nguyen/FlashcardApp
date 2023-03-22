//
//  ViJaEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/18.
//

import Foundation

struct ViJaEntity {
    var id: Int
    var kind: String
    var means: ViJaMeansEntity?
    var word: String
    var favorite: Bool
    
    init(_ obj: RViJa) {
        self.id = obj.id
        self.kind = obj.kind
        self.means = try? ViJaMeansEntity(obj.mean)
        self.word = obj.word
        self.favorite = obj.favorite
    }
}

extension ViJaEntity {
    func toCard() -> CardEntity {
        CardEntity(id: "\(self.id)",
                   frontText: self.word,
                   frontExtraText: "",
                   backText: self.means?.first?.mean ?? "",
                   backExtraText: "",
                   imageUrl: "",
                   videoUrl: "")
    }
}
