//
//  JaViManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import Foundation

class JaViManagement {
    static let shared = JaViManagement()
    
    func search(_ text: String) -> [JaViEntity] {
        let objects = RealmService.shared.realm.objects(RJaVi.self).filter("word CONTAINS[c] %@", text)
        return objects.map({ JaViEntity($0) }).sorted(by: { $0.word.count < $1.word.count })
    }
}
