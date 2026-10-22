//
//  ViJaManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import Foundation
import RealmSwift

class ViJaManagement {
    static let shared = ViJaManagement()
    
    func search(_ text: String) -> [ViJaEntity] {
        let objects = RealmService.shared.realm.objects(RViJa.self).filter("word CONTAINS[c] %@", text)
        return objects.map({ ViJaEntity($0) }).sorted(by: { $0.word.count < $1.word.count })
    }

    /// At most `limit` entries, best matches first (exact, prefix, contains); see `JaViManagement.search(_:limit:)`.
    func search(_ text: String, limit: Int) -> [ViJaEntity] {
        let all = RealmService.shared.realm.objects(RViJa.self)
        var seen = Set<Int>()
        var result: [ViJaEntity] = []
        func take(_ matches: Results<RViJa>, sortedByLength: Bool) {
            guard result.count < limit else { return }
            var candidates = Array(matches.prefix(sortedByLength ? max(limit * 20, 200) : limit))
            if sortedByLength { candidates.sort { $0.word.count < $1.word.count } }
            for object in candidates where result.count < limit && seen.insert(object.id).inserted {
                result.append(ViJaEntity(object))
            }
        }
        take(all.filter("word ==[c] %@", text), sortedByLength: false)
        take(all.filter("word BEGINSWITH[c] %@", text), sortedByLength: true)
        take(all.filter("word CONTAINS[c] %@", text), sortedByLength: true)
        return result
    }
}
