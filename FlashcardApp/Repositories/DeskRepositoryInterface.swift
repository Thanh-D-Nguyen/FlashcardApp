//
//  DeskRepositoryInterface.swift
//  FlashcardApp
//

import Foundation

protocol DeskRepositoryInterface: AnyObject {
    func getAll() -> [DeskEntity]
    func deskFromId(_ id: String) -> RDesk?
    func add(_ desk: DeskEntity) throws
    func update(_ desk: DeskEntity) throws
    func delete(_ desk: DeskEntity) throws
}