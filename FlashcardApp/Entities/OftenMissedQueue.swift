//
//  OftenMissedQueue.swift
//  FlashcardApp
//
//  The cards the learner keeps getting wrong, from this device's own review history. Pure Foundation.
//
//  Source: `ReviewState.lapses`, the local schedule's count of wrong answers (rated again, or an incorrect quiz answer) given
//  after the first answer of a card, over the whole time the card has been studied: it is not a count for a week or a day, and the
//  store keeps no per-miss dates, so nothing here claims "twice this week". Server cards report their own `leeched` flag in Review;
//  the two sources are never merged. A schedule made for an earlier wording of the card is ignored: an edited card starts over.
//

import Foundation

struct OftenMissedDeck: Equatable {
    let id: String
    let name: String
    let cards: [StudyCard]
}

struct OftenMissedCard: Equatable {
    let cardID: String
    let deckID: String
    let deckName: String
    let front: String
    let reading: String
    let back: String
    /// Wrong answers after the first answer, over all time and both kinds of answer.
    let lapses: Int
    /// All answers that went into the schedules (both kinds), so "3 of 7" can be told truthfully.
    let answers: Int
    /// The most recent answer of any kind, right or wrong (the store does not date the misses).
    let lastAnsweredAt: Date
}

enum OftenMissedQueue {
    /// One wrong answer after the first is a slip; two is a pattern worth showing.
    static let minimumLapses = 2
    static let limit = 50

    static func build(decks: [OftenMissedDeck], schedules: [ReviewSchedule]) -> [OftenMissedCard] {
        var placed: [String: (deck: OftenMissedDeck, card: StudyCard)] = [:]
        for deck in decks {
            for card in deck.cards where placed[card.id] == nil { placed[card.id] = (deck, card) }
        }
        var totals: [String: (lapses: Int, answers: Int, last: Date)] = [:]
        for schedule in schedules {
            guard let home = placed[schedule.cardID], schedule.state.contentVersion == home.card.contentVersion else { continue }
            let previous = totals[schedule.cardID]
            totals[schedule.cardID] = ((previous?.lapses ?? 0) + schedule.state.lapses, (previous?.answers ?? 0) + schedule.state.reviews,
                                       max(previous?.last ?? .distantPast, schedule.state.lastReview))
        }
        return totals.compactMap { id, total -> OftenMissedCard? in
            guard total.lapses >= minimumLapses, let home = placed[id] else { return nil }
            return OftenMissedCard(cardID: id, deckID: home.deck.id, deckName: home.deck.name, front: home.card.front, reading: home.card.reading,
                                   back: home.card.back, lapses: total.lapses, answers: total.answers, lastAnsweredAt: total.last)
        }
        .sorted { lhs, rhs in
            if lhs.lapses != rhs.lapses { return lhs.lapses > rhs.lapses }
            if lhs.lastAnsweredAt != rhs.lastAnsweredAt { return lhs.lastAnsweredAt > rhs.lastAnsweredAt }
            return lhs.cardID < rhs.cardID
        }
        .prefix(limit).map { $0 }
    }
}
