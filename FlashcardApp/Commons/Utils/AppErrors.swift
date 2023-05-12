//
//  AppErrors.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/22.
//

import Foundation

enum AppError: Error {
    case deskNameEmpty
    case flashCardMinimum
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .deskNameEmpty:
                return "Vui lòng nhập tên desk"
            case .flashCardMinimum:
                return "Vui lòng nhập ít nhất 2 flashcard"
        }
    }
}
