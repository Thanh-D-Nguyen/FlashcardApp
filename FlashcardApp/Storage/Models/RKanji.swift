//
//  RKanji.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import RealmSwift

class RKanji: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var components: String
    @Persisted var componentsDetail: String
    @Persisted var detail: String
    @Persisted var examples: String
    @Persisted var frequenty: Int
    @Persisted var kanji: String
    @Persisted var kun: String
    @Persisted var level: Int
    @Persisted var mean: String
    @Persisted var on: String
    @Persisted var short: String
    @Persisted var strokeCount: Int
    @Persisted var svg: String
    @Persisted var favorite: Bool
    @Persisted var remember: Bool
}
