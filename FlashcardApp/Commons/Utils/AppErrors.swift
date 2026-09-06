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
    case databaseInitializationFailed(String)
    case databaseWriteFailed(String)
    case entityNotFound(String)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .deskNameEmpty:
                return "Vui lòng nhập tên desk"
            case .flashCardMinimum:
                return "Vui lòng nhập ít nhất 2 flashcard"
            case .databaseInitializationFailed(let reason):
                return "Không thể khởi tạo cơ sở dữ liệu: \(reason)"
            case .databaseWriteFailed(let reason):
                return "Không thể lưu dữ liệu: \(reason)"
            case .entityNotFound(let entityType):
                return "Không tìm thấy \(entityType) trong cơ sở dữ liệu"
        }
    }
}
