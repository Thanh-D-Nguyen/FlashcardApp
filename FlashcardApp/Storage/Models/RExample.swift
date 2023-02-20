//
//  RExample.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import RealmSwift

class RExample: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var ref_id: Int
    @Persisted var mean: String
    @Persisted var trans: String
    @Persisted var content: String
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case ref_id, mean, trans, content
    }
    
}
