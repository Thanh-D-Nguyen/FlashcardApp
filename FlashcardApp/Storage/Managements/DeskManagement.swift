//
//  DeskManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation

class DeskManagement {
    static let shared = DeskManagement()
    
    func getAll() -> [DeskEntity] {
        let desks = RealmService.shared.realm.objects(RDesk.self)
        return Array(desks).map({ $0.toEntity() })
    }
    
    func deskFromId(_ id: String) -> RDesk? {
        return RealmService.shared.realm.objects(RDesk.self).first(where: { $0.id == id })
    }
    
    func add(_ desk: DeskEntity) throws {
        try RealmService.shared.realm.write {
            RealmService.shared.realm.add(desk.toRealm())
        }
    }
    
    func update(_ desk: DeskEntity) throws {
        try RealmService.shared.realm.write {
            RealmService.shared.realm.add(desk.toRealm(), update: .modified)
        }
    }
    
    func delete(_ desk: DeskEntity) throws {
        try RealmService.shared.realm.write {
            RealmService.shared.realm.delete(desk.toRealm())
        }
    }
}
