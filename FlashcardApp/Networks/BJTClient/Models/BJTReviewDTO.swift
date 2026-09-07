//
//  BJTReviewDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Review Submit Request (POST /api/review)

struct BJTSubmitReviewRequestDTO: Codable {
    let userId: String
    let rating: String
    let userFlashcardId: String
    let elapsedMs: Int?
    let reviewedAt: String?
}

// MARK: - Review Submit Outcome (POST /api/review response)

struct BJTReviewSubmitOutcomeDTO: Codable {
    let userFlashcardId: String
    let reviewEventId: String
    let cardId: String
    let state: String
    let dueAt: String
    let intervalDays: Double
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let rating: String
    let reviewedAt: String
    let previousDueAt: String
    let nextDueAt: String
}

// MARK: - Due Flashcard (GET /api/review/next)

struct BJTDueFlashcardDTO: Codable {
    let id: String
    let cardId: String
    let card: BJTDueFlashcardDetailDTO
    let leeched: Bool
    let comebackMode: Bool
    let primaryImage: BJTDueFlashcardMediaDTO?
    let state: String
}

struct BJTDueFlashcardDetailDTO: Codable {
    let frontText: String
    let backText: String
    let id: String
    let reading: String?
}

struct BJTDueFlashcardMediaDTO: Codable {
    let assetId: String
    let mimeType: String
    let readUrl: String?
}

// MARK: - Review Summary (GET /api/review/summary)

struct BJTReviewSummaryDTO: Codable {
    let totalDue: Int?
    let newCards: Int?
    let learningCards: Int?
    let reviewCards: Int?
    let lapsedCards: Int?
    let reviewedToday: Int?
    let correctToday: Int?
    let accuracyPercent: Double?

    enum CodingKeys: String, CodingKey {
        case totalDue, newCards, learningCards, reviewCards, lapsedCards
        case reviewedToday, correctToday, accuracyPercent
    }
}

// MARK: - Batch Review Request (POST /api/flashcards/reviews/batch)

struct BJTReviewBatchItemRequestDTO: Codable {
    let clientMutationId: String
    let userFlashcardId: String
    let rating: String
    let elapsedMs: Int?
    let reviewedAt: String?
}

struct BJTSubmitReviewBatchRequestDTO: Codable {
    let items: [BJTReviewBatchItemRequestDTO]
    let userId: String
}

// MARK: - Batch Review Response

struct BJTReviewBatchResultDTO: Codable {
    let clientMutationId: String
    let ok: Bool
    let error: String?
}

struct BJTSubmitReviewBatchResponseDTO: Codable {
    let results: [BJTReviewBatchResultDTO]
}

// MARK: - Flashcard Review Item (from flashcards-openapi.dto.ts)

struct BJTFlashcardReviewItemDTO: Codable {
    let id: String
    let cardId: String
    let card: BJTFlashcardReviewCardCoreDTO
    let state: String
    let comebackMode: Bool
    let leeched: Bool
    let examples: [BJTFlashcardReviewExampleDTO]
    let primaryImage: BJTFlashcardMediaRefDTO?
    let primaryAudio: BJTFlashcardMediaRefDTO?
}

struct BJTFlashcardReviewCardCoreDTO: Codable {
    let id: String
    let frontText: String
    let backText: String
    let reading: String?
}

struct BJTFlashcardReviewExampleDTO: Codable {
    let japaneseText: String
    let reading: String
    let translationVi: String
}

struct BJTFlashcardMediaRefDTO: Codable {
    let assetId: String
    let mimeType: String
    let readUrl: String?
}

// MARK: - Single Review Submit Response (POST /api/flashcards/reviews/:id)

struct BJTSubmitFlashcardReviewResponseDTO: Codable {
    let userFlashcardId: String
    let cardId: String
    let state: String
    let rating: String
    let dueAt: String
    let previousDueAt: String
    let nextDueAt: String
    let easeFactor: Double
    let intervalDays: Int
    let repetitions: Int
    let lapses: Int
    let leechDetected: Bool
    let leeched: Bool
    let comebackMode: Bool
    let reviewedAt: String
    let reviewEventId: String
    let remediation: BJTFlashcardReviewRemediationDTO?
    let remediationPolicy: BJTFlashcardReviewRemediationPolicyDTO?
}

struct BJTFlashcardReviewRemediationDTO: Codable {
    let sourceId: String
    let sourceIdKind: String
    let sourceType: String
}

struct BJTFlashcardReviewRemediationPolicyDTO: Codable {
    let availability: String
    let note: String
}

// MARK: - Comeback Summary (GET /api/flashcards/reviews/comeback-summary)

struct BJTReviewComebackSummaryDTO: Codable {
    let totalComeback: Int?
    let recovered: Int?
    let stillRecovering: Int?
}

// MARK: - Distractors (GET /api/flashcards/reviews/{userFlashcardId}/distractors)

struct BJTReviewDistractorDTO: Codable {
    let id: String?
    let text: String?
    let reading: String?
    let type: String?
}

// MARK: - Flashcard Styles

struct BJTFlashcardStyleDTO: Codable {
    let slug: String
    let name: String?
    let description: String?
    let isActive: Bool?
}

struct BJTActiveFlashcardStyleDTO: Codable {
    let slug: String?
}

struct BJTSetActiveFlashcardStyleRequestDTO: Codable {
    let slug: String?
}

// MARK: - Legacy type aliases for build compatibility

/// Alias used by BJTFlashcardsAPI and BJTAuthenticatedRequest
typealias BJTReviewSubmitResponse = BJTSubmitFlashcardReviewResponseDTO

/// Wrapper used by BJTFlashcardsAPI.submitReview — matches the DTO fields actually passed at the call site.
struct BJTReviewSubmitRequest: Codable {
    let rating: String
    let userId: String
    let userFlashcardId: String?
    let elapsedMs: Int?
    let reviewedAt: String?

    init(rating: String, userId: String, userFlashcardId: String? = nil, elapsedMs: Int? = nil, reviewedAt: String? = nil) {
        self.rating = rating
        self.userId = userId
        self.userFlashcardId = userFlashcardId
        self.elapsedMs = elapsedMs
        self.reviewedAt = reviewedAt
    }
}