//
//  Loto.swift
//
//  Loto 6 and Loto 7 number sets from the website's "Loto" magazine articles. The sets are chosen from past draws with a
//  weighted heuristic; every valid combination has the same chance, and the server says so in `riskDisclaimer`. The app
//  shows that statement with the numbers and never shows a promise of winning.
//

import Foundation

enum LotoGame: String, CaseIterable, Equatable {
    case loto6, loto7

    init?(widgetKind: String) {
        switch widgetKind {
        case "magazine_loto6", "loto6": self = .loto6
        case "magazine_loto7", "loto7": self = .loto7
        default: return nil
        }
    }

    /// How many main numbers a ticket has.
    var pickCount: Int { self == .loto6 ? 6 : 7 }
    /// Numbers are drawn from 1…`poolSize`.
    var poolSize: Int { self == .loto6 ? 43 : 37 }

    var title: String {
        switch self {
        case .loto6: return NSLocalizedString("Loto 6", comment: "Lottery game name")
        case .loto7: return NSLocalizedString("Loto 7", comment: "Lottery game name")
        }
    }

    /// Number of different tickets: the chance of any one combination is 1 in this.
    var combinations: Int {
        var result = 1
        for index in 1...pickCount { result = result * (poolSize - pickCount + index) / index }
        return result
    }
}

enum LotoTag: String, Equatable, CaseIterable {
    /// Drawn often in the history.
    case hot
    /// Drawn rarely in the history.
    case cold
    /// Has not been drawn for a while.
    case overdue
    /// Drawn in the latest draws.
    case recent
}

struct LotoNumber: Equatable {
    let number: Int
    /// Times it was drawn in the history.
    let count: Int?
    /// Draws since it was last drawn.
    let gap: Int?
    let tags: [LotoTag]
}

struct LotoShape: Equatable {
    let odd: Int
    let even: Int
    let low: Int
    let high: Int
    let sum: Int
    let consecutivePairs: Int
}

struct LotoSet: Equatable {
    let rank: Int
    let main: [Int]
    let bonus: [Int]
    /// The heuristic's own score, 0…1. It orders the sets; it is not a probability.
    let score: Double?
    let shape: LotoShape?
    let numbers: [LotoNumber]
}

struct LotoSignals: Equatable {
    let hot: [Int]
    let cold: [Int]
    let overdue: [Int]

    var isEmpty: Bool { hot.isEmpty && cold.isEmpty && overdue.isEmpty }
}

enum LotoWeightKind: String, CaseIterable, Equatable {
    case frequencyHot, frequencyCold, overdue, recentMomentum, pairAffinity, randomEntropy

    var title: String {
        switch self {
        case .frequencyHot: return NSLocalizedString("Frequent numbers", comment: "Loto method factor")
        case .frequencyCold: return NSLocalizedString("Rare numbers", comment: "Loto method factor")
        case .overdue: return NSLocalizedString("Overdue numbers", comment: "Loto method factor")
        case .recentMomentum: return NSLocalizedString("Recent draws", comment: "Loto method factor")
        case .pairAffinity: return NSLocalizedString("Pairs drawn together", comment: "Loto method factor")
        case .randomEntropy: return NSLocalizedString("Randomness", comment: "Loto method factor")
        }
    }
}

struct LotoWeight: Equatable {
    let kind: LotoWeightKind
    /// 0…1.
    let value: Double
}

/// One draw the server prepared numbers for.
struct LotoDraw: Equatable {
    let slug: String
    let game: LotoGame
    let day: MagazineDay
    /// "18:45 JST", as the server writes it.
    let drawTime: String
    /// When the draw happens, if `drawTime` could be read.
    let drawInstant: Date?
    let drawNumber: Int?
    let drawNumberIsEstimate: Bool
    let sets: [LotoSet]
    let signals: LotoSignals
    let weights: [LotoWeight]
    /// Past draws the heuristic looked at.
    let historyDraws: Int?
    /// The statement that every combination has the same chance, in the learner's language when the server has it.
    let disclaimer: String
    /// Where the official results are published (https only).
    let officialURL: URL?

    /// "Thứ 2 & Thứ 5 hàng tuần…" as written by the server in the learner's language, when present.
    let schedule: String?
}

struct LotoListItem: Equatable {
    let slug: String
    let game: LotoGame
    let day: MagazineDay
}

struct LotoOverview: Equatable {
    /// The next draw of each game, in the order of `LotoGame.allCases`; a game without articles is missing.
    let draws: [LotoDraw]
}
