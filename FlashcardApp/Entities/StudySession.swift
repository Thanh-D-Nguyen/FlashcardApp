//
//  StudySession.swift
//  FlashcardApp
//
//  Pure state machine for studying one deck: order, flipping, shuffle, multiple-choice quiz and
//  the counters shown to the learner. No UIKit, no Realm, no persistence: progress is per
//  session only, as on the website (nothing here is synchronised or stored).
//

import CryptoKit
import Foundation

struct StudyCard: Equatable {
    let id: String
    let front: String
    let back: String
    let reading: String
    let note: String
    let imageReference: String

    init(entity: CardEntity) {
        id = entity.id
        front = entity.frontText
        back = entity.backText
        reading = entity.frontExtraText
        note = entity.backExtraText
        imageReference = entity.imageUrl
    }

    /// The kana reading a typed answer is checked against. `nil` unless the front is Japanese and differs from its reading (a kana
    /// word would only be copied), and the reading is pure kana: the reading of the front is what is asked.
    var typedAnswer: String? {
        guard KanaAnswer.isKana(reading), JapaneseText.containsJapanese(front),
              KanaAnswer.normalized(front) != KanaAnswer.normalized(reading) else { return nil }
        return reading
    }

    /// Identifies what the learner was asked and shown: front, reading and back. The note and the picture
    /// are not part of it, so renaming a deck or changing an image keeps the learner's history valid.
    /// Persisted with each attempt: do not change how it is computed.
    var contentVersion: String {
        let joined = [front, reading, back].joined(separator: "\u{1F}")
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    init(id: String, front: String, back: String, reading: String = "", note: String = "", imageReference: String = "") {
        self.id = id
        self.front = front
        self.back = back
        self.reading = reading
        self.note = note
        self.imageReference = imageReference
    }
}

enum StudyMode: String {
    case flip
    case quiz
    /// Type the reading in kana.
    case type
}

/// Picks an integer in the range; injectable so shuffle and quiz options are testable.
typealias StudyRandomSource = (Range<Int>) -> Int

/// What a learner did when answering, kept apart because the evidence differs: a correct quiz
/// answer shows recognition, a flip rated by the learner is a self-assessment. They never
/// upgrade each other.
enum ReviewSkill: String, Equatable {
    case recognition
    case selfRecall
    /// The learner typed the reading: a checked recall of the answer itself, neither a pick among options nor a self-rating.
    case typedRecall
}

/// Outcome of one answered question. Only combinations that can really happen exist.
enum ReviewResult: String, Equatable {
    case correct
    case incorrect
    case remembered
    case needsReview
    case typedCorrect
    case typedIncorrect

    var skill: ReviewSkill {
        switch self {
        case .correct, .incorrect: return .recognition
        case .remembered, .needsReview: return .selfRecall
        case .typedCorrect, .typedIncorrect: return .typedRecall
        }
    }
}

/// Self-rating after the answer of a flipped card is shown.
enum SelfRating: Equatable {
    case remembered
    case needsReview
}

/// Help that was available to the learner before answering, so the result is not read as an
/// unaided recall.
enum ReviewHint: String, Equatable, CaseIterable {
    case reading
    case audio
}

/// One answered question. The `id` is stable for the question in its run: persisting the same
/// value again (a retry) must never count twice, while a restarted run gets new ids.
struct ReviewAttempt: Equatable {
    let id: String
    let cardID: String
    let result: ReviewResult
    let hints: Set<ReviewHint>
    /// `StudyCard.contentVersion` of the card as it was answered, so a later edit of the card does not
    /// make this result look like evidence about the new wording.
    let contentVersion: String
    let answeredAt: Date

    var skill: ReviewSkill { result.skill }
}

struct StudySession {
    static let maximumQuizOptions = 4

    let cards: [StudyCard]
    /// Where quiz answers come from: the cards asked, or a bigger set they belong to.
    private let pool: [StudyCard]
    private let random: StudyRandomSource
    private let now: () -> Date
    private let makeRunID: () -> String
    private var runID = ""
    private var hintsByPosition: [Int: Set<ReviewHint>] = [:]

    private(set) var order: [Int]
    private(set) var position = 0
    private(set) var isFlipped = false
    private(set) var isShuffled: Bool
    private(set) var mode: StudyMode
    private(set) var isFinished = false

    private(set) var options: [String] = []
    private(set) var selectedOption: String?
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// What the learner typed for the current question, once submitted.
    private(set) var typedAnswer: String?

    /// Answered questions of the current run in the order they were answered. Looking at a card,
    /// flipping it, listening or moving on never adds one; skipped questions have none.
    private(set) var attempts: [ReviewAttempt] = []
    var currentAttempt: ReviewAttempt? { attempt(at: position) }
    /// Help in view for the current question: what its attempt recorded once answered, otherwise what is noted so far.
    var currentHints: Set<ReviewHint> { attempt(at: position)?.hints ?? hintsByPosition[position] ?? [] }

    /// `quizPool` is where a quiz may take its answers from when the session asks only some of a deck's cards (a session planned
    /// on Today): quiz or flip, and the wrong options, must not depend on how few cards are asked. It defaults to the cards.
    init(cards: [StudyCard], quizPool: [StudyCard]? = nil, mode: StudyMode = .flip, shuffled: Bool = false,
         random: @escaping StudyRandomSource = { Int.random(in: $0) },
         now: @escaping () -> Date = Date.init,
         makeRunID: @escaping () -> String = { UUID().uuidString }) {
        self.cards = cards
        self.pool = quizPool ?? cards
        self.random = random
        self.now = now
        self.makeRunID = makeRunID
        self.isShuffled = shuffled
        self.order = Array(cards.indices)
        self.mode = Self.resolve(mode, cards: cards, pool: quizPool ?? cards)
        restart()
    }

    /// A quiz needs at least two different answers; otherwise every option would be the same.
    static func canQuiz(_ cards: [StudyCard]) -> Bool {
        Set(cards.map(\.back).filter { !$0.isEmpty }).count >= 2
    }

    var canQuiz: Bool { Self.canQuiz(pool) }

    /// Typing needs a kana reading to check against on every card asked.
    static func canType(_ cards: [StudyCard]) -> Bool { !cards.isEmpty && cards.allSatisfy { $0.typedAnswer != nil } }

    /// A mode the cards cannot support is flipping.
    private static func resolve(_ mode: StudyMode, cards: [StudyCard], pool: [StudyCard]) -> StudyMode {
        switch mode {
        case .quiz: return canQuiz(pool) ? .quiz : .flip
        case .type: return canType(cards) ? .type : .flip
        case .flip: return .flip
        }
    }

    var canType: Bool { Self.canType(cards) }
    var count: Int { cards.count }
    var current: StudyCard? { order.indices.contains(position) ? cards[order[position]] : nil }
    var canGoBack: Bool { mode == .flip && position > 0 && !isFinished }
    var canGoForward: Bool { !isFinished && !cards.isEmpty }
    var isLastCard: Bool { position == count - 1 }
    /// 0…1; reaches 1 when the last card is shown.
    var progress: Double { count == 0 ? 0 : Double(isFinished ? count : position + 1) / Double(count) }
    var isAnswerCorrect: Bool? {
        if mode == .type { return typedAnswer.flatMap { typed in current?.typedAnswer.map { KanaAnswer.matches(typed: typed, expected: $0) } } }
        return selectedOption.map { $0 == current?.back }
    }

    // MARK: Transitions

    mutating func restart() {
        position = 0
        isFlipped = false
        isFinished = false
        selectedOption = nil
        typedAnswer = nil
        correctCount = 0
        answeredCount = 0
        attempts = []
        hintsByPosition = [:]
        runID = makeRunID()
        order = Array(cards.indices)
        if isShuffled { shuffleOrder() }
        prepareQuestion()
    }

    mutating func setShuffled(_ shuffled: Bool) {
        isShuffled = shuffled
        restart()
    }

    mutating func setMode(_ newMode: StudyMode) {
        mode = Self.resolve(newMode, cards: cards, pool: pool)
        restart()
    }

    mutating func flip() {
        guard mode == .flip, current != nil, !isFinished else { return }
        isFlipped.toggle()
    }

    /// Moves to the next card, or finishes after the last one.
    mutating func advance() {
        guard !isFinished, current != nil else { return }
        if position + 1 < count {
            position += 1
            isFlipped = false
            selectedOption = nil
            typedAnswer = nil
            prepareQuestion()
        } else {
            isFinished = true
        }
    }

    mutating func goBack() {
        guard canGoBack else { return }
        position -= 1
        isFlipped = false
    }

    /// Records a quiz answer once per question.
    mutating func select(option: String) {
        guard mode == .quiz, selectedOption == nil, options.contains(option), let card = current else { return }
        selectedOption = option
        answeredCount += 1
        if option == card.back { correctCount += 1 }
        record(option == card.back ? .correct : .incorrect, for: card)
    }

    /// Records a typed reading once per question; a blank answer is not an answer.
    mutating func submit(typed: String) {
        guard mode == .type, typedAnswer == nil, !isFinished, let card = current, let expected = card.typedAnswer,
              !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        typedAnswer = typed
        answeredCount += 1
        let isRight = KanaAnswer.matches(typed: typed, expected: expected)
        if isRight { correctCount += 1 }
        record(isRight ? .typedCorrect : .typedIncorrect, for: card)
    }

    /// Rates the shown answer of a flipped card; once per question.
    mutating func rate(_ rating: SelfRating) {
        guard mode == .flip, isFlipped, !isFinished, let card = current, !isAnswered(at: position) else { return }
        record(rating == .remembered ? .remembered : .needsReview, for: card)
    }

    /// Notes help that was in view for the current question. Ignored once the answer is shown or
    /// the question was answered: later help cannot have made the answer easier.
    mutating func noteHint(_ hint: ReviewHint) {
        guard !isFinished, current != nil, !isFlipped, !isAnswered(at: position) else { return }
        hintsByPosition[position, default: []].insert(hint)
    }

    // MARK: Helpers

    /// Stable for a question within a run, so persisting it again is recognisably a retry.
    private func attemptID(at position: Int) -> String { "\(runID)/\(position)" }

    private func attempt(at position: Int) -> ReviewAttempt? {
        let id = attemptID(at: position)
        return attempts.first { $0.id == id }
    }

    private func isAnswered(at position: Int) -> Bool { attempt(at: position) != nil }

    private mutating func record(_ result: ReviewResult, for card: StudyCard) {
        attempts.append(ReviewAttempt(id: attemptID(at: position), cardID: card.id, result: result,
                                      hints: hintsByPosition[position] ?? [], contentVersion: card.contentVersion, answeredAt: now()))
    }

    private mutating func prepareQuestion() {
        guard mode == .quiz, let card = current else {
            options = []
            return
        }
        var distractors: [String] = []
        for other in pool where other.id != card.id && !other.back.isEmpty && other.back != card.back && !distractors.contains(other.back) {
            distractors.append(other.back)
        }
        var chosen = Self.shuffled(distractors, random: random)
        chosen = Array(chosen.prefix(Self.maximumQuizOptions - 1))
        options = Self.shuffled([card.back] + chosen, random: random)
    }

    private mutating func shuffleOrder() {
        order = Self.shuffled(order, random: random)
    }

    /// Fisher–Yates with an injectable source of randomness.
    private static func shuffled<T>(_ items: [T], random: StudyRandomSource) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let other = random(0..<(index + 1))
            if other != index { result.swapAt(index, other) }
        }
        return result
    }
}
