//
//  CardRepositoryInterface.swift
//  FlashcardApp
//

import Foundation

protocol CardRepositoryInterface: AnyObject {
    func add(_ card: CardEntity, toDesk desk: DeskEntity) throws
}