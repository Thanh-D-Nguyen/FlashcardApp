//
//  RJaVi.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import RealmSwift

class RJaVi: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var mean: String
    @Persisted var opposite: String
    @Persisted var phonetic: String
    @Persisted var pronunciation: String
    @Persisted var relate: String
    @Persisted var seq: Int
    @Persisted var synsets: String
    @Persisted var word: String
    @Persisted var favorite: Bool
}
