//
//  BJTExampleDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Example Sentence (GET /api/examples, GET /api/examples/search, GET /api/examples/by-word/{wordId})

struct BJTExampleSentenceDTO: Codable {
    let id: String
    let sentence: String?
    let reading: String?
    let translationVi: String?
    let sourceType: String?
    let sourceId: String?
    let wordId: String?
    let kanjiId: String?
    let grammarId: String?
    let createdAt: String?
    let updatedAt: String?
}