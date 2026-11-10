//
//  LotoRandomizer.swift
//
//  The on-device "randomness lab": number sets drawn with a weight per number that blends the draw's own signals
//  (frequent, overdue, rare) with a flat weight. `randomness` 1 gives every number the same weight, so every valid
//  combination is equally likely; lower values lean towards the signals. No setting changes the chance of winning,
//  and the screen says so. Nothing here is sent to or read from a server.
//

import Foundation

enum LotoRandomizer {
    /// Weight an unmarked number keeps next to a marked one when randomness is 0. Never 0, so every number stays possible.
    static let unmarkedShare = 0.15

    /// How many sets one spin produces.
    static let setsPerSpin = 5

    static func clamped(_ randomness: Double) -> Double {
        randomness.isFinite ? min(max(randomness, 0), 1) : 1
    }

    /// One weight per number, index 0 for number 1, each in `unmarkedShare…1`. All equal at randomness 1 or without signals.
    static func weights(game: LotoGame, signals: LotoSignals, randomness: Double) -> [Double] {
        let flat = clamped(randomness)
        let marked = Set(signals.hot).union(signals.overdue).union(signals.cold)
        return (1...game.poolSize).map { number in
            let affinity = marked.isEmpty || marked.contains(number) ? 1 : unmarkedShare
            return flat + (1 - flat) * affinity
        }
    }

    /// True when the weights are exactly flat: the sampling is then uniform over all combinations.
    static func isUniform(_ weights: [Double]) -> Bool {
        guard let first = weights.first else { return true }
        return weights.allSatisfy { $0 == first }
    }

    /// One sorted ticket: `pickCount` different numbers drawn one by one in proportion to their weight.
    static func ticket<G: RandomNumberGenerator>(game: LotoGame, signals: LotoSignals, randomness: Double, using generator: inout G) -> [Int] {
        var remaining = weights(game: game, signals: signals, randomness: randomness)
        var picked: [Int] = []
        while picked.count < game.pickCount {
            let total = remaining.reduce(0, +)
            var target = Double.random(in: 0..<total, using: &generator)
            var chosen = remaining.indices.last { remaining[$0] > 0 } ?? 0
            for index in remaining.indices where remaining[index] > 0 {
                if target < remaining[index] { chosen = index; break }
                target -= remaining[index]
            }
            picked.append(chosen + 1)
            remaining[chosen] = 0
        }
        return picked.sorted()
    }

    /// `count` different tickets.
    static func tickets<G: RandomNumberGenerator>(game: LotoGame, signals: LotoSignals, randomness: Double, count: Int = setsPerSpin,
                                                  using generator: inout G) -> [[Int]] {
        var seen = Set<[Int]>()
        var result: [[Int]] = []
        var attempts = 0
        while result.count < count, attempts < count * 20 {
            attempts += 1
            let ticket = ticket(game: game, signals: signals, randomness: randomness, using: &generator)
            if seen.insert(ticket).inserted { result.append(ticket) }
        }
        return result
    }
}

/// A `RandomNumberGenerator` backed by a closure, so a presenter can be given a repeatable source in tests.
struct LotoRandomSource: RandomNumberGenerator {
    private let source: () -> UInt64

    init(_ source: @escaping () -> UInt64) { self.source = source }

    /// The system generator, which is cryptographically secure.
    static var system: LotoRandomSource {
        var generator = SystemRandomNumberGenerator()
        return LotoRandomSource { generator.next() }
    }

    mutating func next() -> UInt64 { source() }
}
