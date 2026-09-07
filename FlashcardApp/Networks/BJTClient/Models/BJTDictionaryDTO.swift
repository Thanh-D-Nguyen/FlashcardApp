//
//  BJTDictionaryDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Dictionary Search Result (GET /api/dictionary/search)
// Response shape derived from ContentRepository.lexemes() — same as BJTLexemeDTO
// but returned from the canonical /dictionary/search endpoint.

struct BJTDictionarySearchResultDTO: Codable {
    let id: String
    let word: String?
    let reading: String?
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
    let status: String?
    let senses: [BJTDictionarySenseDTO]?
    let examples: [BJTDictionaryExampleDTO]?
}

struct BJTDictionarySenseDTO: Codable {
    let id: String?
    let lexemeId: String?
    let position: Int?
    let meaningVi: String?
    let explanation: String?
    let note: String?
    let partOfSpeech: String?
}

struct BJTDictionaryExampleDTO: Codable {
    let id: String?
    let sentence: String?
    let translation: String?
    let reading: String?
}

// MARK: - Dictionary Word Detail (GET /api/dictionary/words/{id})

struct BJTDictionaryWordDetailDTO: Codable {
    let id: String
    let word: String?
    let reading: String?
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
    let status: String?
    let senses: [BJTDictionarySenseDTO]?
    let examples: [BJTDictionaryExampleDTO]?
    let relatedWords: [BJTDictionaryRelatedWordDTO]?
    let createdAt: String?
    let updatedAt: String?
}

struct BJTDictionaryRelatedWordDTO: Codable {
    let id: String?
    let word: String?
    let reading: String?
    let meaningVi: String?
    let relationType: String?
}

// MARK: - ViJa Reverse Search Result (GET /api/vija/search)

struct BJTReverseSearchResultDTO: Codable {
    let id: String
    let word: String?
    let reading: String?
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
}