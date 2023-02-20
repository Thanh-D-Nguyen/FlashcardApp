//
//  RGrammar.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import RealmSwift

class RGrammar: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var category: String
    @Persisted var define: String
    @Persisted var level: String
    @Persisted var mean: String
    @Persisted var note: String
    @Persisted var summary: String
    @Persisted var favorite: Bool
    @Persisted var remember: Bool    
}
