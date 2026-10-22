//
//  AppErrors.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/22.
//

import Foundation

enum AppError: Error {
    case invalidInput(String)
    case deskNameEmpty
    case flashCardMinimum
    case databaseInitializationFailed(String)
    case databaseWriteFailed(String)
    case entityNotFound(String)
    case authenticationFailed(String)
    case networkRequestFailed(String)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .invalidInput(let message): return message
            case .deskNameEmpty:
                return NSLocalizedString("Please enter a deck name.", comment: "")
            case .flashCardMinimum:
                return NSLocalizedString("Add at least 2 cards.", comment: "")
            case .databaseInitializationFailed(let reason):
                return String(format: NSLocalizedString("Couldn't initialize the database: %@", comment: ""), reason)
            case .databaseWriteFailed(let reason):
                return String(format: NSLocalizedString("Couldn't save data: %@", comment: ""), reason)
            case .entityNotFound(let entityType):
                return String(format: NSLocalizedString("Couldn't find %@ in the database.", comment: ""), entityType)
            case .authenticationFailed(let reason):
                return String(format: NSLocalizedString("Authentication error: %@", comment: ""), reason)
            case .networkRequestFailed(let reason):
                return String(format: NSLocalizedString("Network error: %@", comment: ""), reason)
        }
    }
}
