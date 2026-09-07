//
//  BJTSearchDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Search Result (GET /api/search)
// Meilisearch projection — read-only copy of indexed content.

struct BJTSearchResultDTO: Codable {
    let id: String?
    let type: String?
    let word: String?
    let reading: String?
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
    let character: String?
    let pattern: String?
    let sentence: String?
    let translation: String?
    let score: Double?
    let highlights: [String: String]?
}

// MARK: - Search Suggest Result (GET /api/search/suggest)

struct BJTSearchSuggestDTO: Codable {
    let text: String?
    let type: String?
    let id: String?
    let score: Double?
}