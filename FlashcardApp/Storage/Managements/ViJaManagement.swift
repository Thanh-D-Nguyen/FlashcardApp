//
//  ViJaManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import Foundation

class ViJaManagement {
    static let shared = ViJaManagement()
    
    func search(_ text: String) -> [ViJaEntity] {
        let objects = RealmService.shared.realm.objects(RViJa.self).filter("word CONTAINS[c] %@", text)
        return objects.map({ ViJaEntity($0) }).sorted(by: { $0.word.count < $1.word.count })
    }
}
