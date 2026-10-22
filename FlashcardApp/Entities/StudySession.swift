//
//  StudySession.swift
//  FlashcardApp
//
//  Pure state machine for studying one deck: order, flipping, shuffle, multiple-choice quiz and
//  the counters shown to the learner. No UIKit, no Realm, no persistence: progress is per
//  session only, as on the website (nothing here is synchronised or stored).
//

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
}

/// Picks an integer in the range; injectable so shuffle and quiz options are testable.
typealias StudyRandomSource = (Range<Int>) -> Int

struct StudySession {
    static let maximumQuizOptions = 4

    let cards: [StudyCard]
    private let random: StudyRandomSource

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

    init(cards: [StudyCard], mode: StudyMode = .flip, shuffled: Bool = false,
         random: @escaping StudyRandomSource = { Int.random(in: $0) }) {
        self.cards = cards
        self.random = random
        self.isShuffled = shuffled
        self.order = Array(cards.indices)
        self.mode = (mode == .quiz && Self.canQuiz(cards)) ? .quiz : .flip
        restart()
    }

    /// A quiz needs at least two different answers; otherwise every option would be the same.
    static func canQuiz(_ cards: [StudyCard]) -> Bool {
        Set(cards.map(\.back).filter { !$0.isEmpty }).count >= 2
    }

    var canQuiz: Bool { Self.canQuiz(cards) }
    var count: Int { cards.count }
    var current: StudyCard? { order.indices.contains(position) ? cards[order[position]] : nil }
    var canGoBack: Bool { mode == .flip && position > 0 && !isFinished }
    var canGoForward: Bool { !isFinished && !cards.isEmpty }
    var isLastCard: Bool { position == count - 1 }
    /// 0…1; reaches 1 when the last card is shown.
    var progress: Double { count == 0 ? 0 : Double(isFinished ? count : position + 1) / Double(count) }
    var isAnswerCorrect: Bool? { selectedOption.map { $0 == current?.back } }

    // MARK: Transitions

    mutating func restart() {
        position = 0
        isFlipped = false
        isFinished = false
        selectedOption = nil
        correctCount = 0
        answeredCount = 0
        order = Array(cards.indices)
        if isShuffled { shuffleOrder() }
        prepareQuestion()
    }

    mutating func setShuffled(_ shuffled: Bool) {
        isShuffled = shuffled
        restart()
    }

    mutating func setMode(_ newMode: StudyMode) {
        mode = (newMode == .quiz && canQuiz) ? .quiz : .flip
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
    }

    // MARK: Helpers

    private mutating func prepareQuestion() {
        guard mode == .quiz, let card = current else {
            options = []
            return
        }
        var distractors: [String] = []
        for other in cards where other.id != card.id && !other.back.isEmpty && other.back != card.back && !distractors.contains(other.back) {
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
