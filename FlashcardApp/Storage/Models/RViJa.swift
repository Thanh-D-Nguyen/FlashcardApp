//
//  RViJa.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import RealmSwift

class RViJa: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var kind: String
    @Persisted var mean: String
    @Persisted var word: String
    @Persisted var favorite: Bool
}
