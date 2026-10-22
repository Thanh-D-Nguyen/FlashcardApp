//
//  JaViManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import Foundation
import RealmSwift

class JaViManagement {
    static let shared = JaViManagement()
    
    func search(_ text: String) -> [JaViEntity] {
        let objects = RealmService.shared.realm.objects(RJaVi.self).filter("word CONTAINS[c] %@", text)
        return objects.map({ JaViEntity($0) }).sorted(by: { $0.word.count < $1.word.count })
    }

    /// At most `limit` entries, best matches first: the exact word, words that start with the text, then
    /// the rest (a word containing it, or a reading starting with it). Only the matches that are kept are
    /// materialised, so a one-character query does not decode the whole dictionary. Main-thread Realm only.
    func search(_ text: String, limit: Int) -> [JaViEntity] {
        let all = RealmService.shared.realm.objects(RJaVi.self)
        var seen = Set<Int>()
        var result: [JaViEntity] = []
        func take(_ matches: Results<RJaVi>, sortedByLength: Bool) {
            guard result.count < limit else { return }
            var candidates = Array(matches.prefix(sortedByLength ? max(limit * 20, 200) : limit))
            if sortedByLength { candidates.sort { $0.word.count < $1.word.count } }
            for object in candidates where result.count < limit && seen.insert(object.id).inserted {
                result.append(JaViEntity(object))
            }
        }
        take(all.filter("word ==[c] %@", text), sortedByLength: false)
        take(all.filter("word BEGINSWITH[c] %@", text), sortedByLength: true)
        take(all.filter("phonetic BEGINSWITH[c] %@", text), sortedByLength: true)
        take(all.filter("word CONTAINS[c] %@", text), sortedByLength: true)
        return result
    }
}
