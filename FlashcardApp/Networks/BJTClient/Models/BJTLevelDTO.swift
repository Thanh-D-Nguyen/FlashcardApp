//
//  BJTLevelDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Level List Item (GET /api/levels)

struct BJTLevelDTO: Codable {
    let code: String
    let name: String?
    let nameVi: String?
    let description: String?
    let order: Int?
    let kanjiCount: Int?
    let grammarCount: Int?
    let vocabularyCount: Int?
    let lessonCount: Int?
}

// MARK: - Level Detail (GET /api/levels/{code})

struct BJTLevelDetailDTO: Codable {
    let code: String
    let name: String?
    let nameVi: String?
    let description: String?
    let order: Int?
    let kanjiCount: Int?
    let grammarCount: Int?
    let vocabularyCount: Int?
    let lessonCount: Int?
    let lessons: [BJTLevelLessonSummaryDTO]?
}

// MARK: - Lesson Summary (in level detail or GET /api/levels/{code}/lessons)

struct BJTLevelLessonSummaryDTO: Codable {
    let slug: String
    let title: String?
    let titleVi: String?
    let order: Int?
    let kanjiCount: Int?
    let grammarCount: Int?
    let vocabularyCount: Int?
}

// MARK: - Lesson Detail (GET /api/levels/lessons/{slug})

struct BJTLevelLessonDetailDTO: Codable {
    let slug: String
    let title: String?
    let titleVi: String?
    let levelCode: String?
    let order: Int?
    let kanji: [BJTLevelKanjiItemDTO]?
    let grammar: [BJTLevelGrammarItemDTO]?
    let vocabulary: [BJTLevelVocabularyItemDTO]?
}

// MARK: - Level Vocabulary Item (GET /api/levels/{code}/vocabulary)

struct BJTLevelVocabularyItemDTO: Codable {
    let id: String
    let word: String?
    let reading: String?
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
}

// MARK: - Level Kanji Item (GET /api/levels/{code}/kanji)

struct BJTLevelKanjiItemDTO: Codable {
    let id: String
    let character: String
    let meaningVi: String?
    let onyomi: String?
    let kunyomi: String?
    let strokeCount: Int?
    let level: Int?
}

// MARK: - Level Grammar Item (GET /api/levels/{code}/grammar)

struct BJTLevelGrammarItemDTO: Codable {
    let id: String
    let pattern: String
    let meaningVi: String?
    let jlptLevel: String?
    let category: String?
}
