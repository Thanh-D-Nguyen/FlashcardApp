//
//  LotoChaos.swift
//
//  The "butterfly effect" mode of the randomness lab. Every spin gathers the factors that are really there at that moment
//  (the clock, the draw, the weather of ten Japanese cities from the server, how the phone shakes, where the balls of the
//  drum came to rest, the learner's touches). They are folded into one fingerprint (SHA-256) that sets the start of a Lorenz
//  system, the textbook chaotic system. The path of that system, run beside a copy that starts a millionth away, shows the
//  butterfly effect, and its end state seeds the numbers.
//
//  This is a model and an explanation, not a forecast: the real machine is not reachable from here, and nothing in this file
//  changes the chance of a ticket. Factors that cannot be read (no motion sensor, no weather) are left out, never invented.
//

import CryptoKit
import Foundation

struct LotoChaosFactor: Equatable {
    enum Kind: String, CaseIterable {
        case moment, draw, weather, motion, touch, drum, slider
    }

    let kind: Kind
    /// Unique and stable, e.g. `weather.tokyo`. Factors are sorted by it before they are hashed.
    let key: String
    /// Exactly what is hashed.
    let value: String
    /// What the learner reads, when the hashed text is not meant for reading.
    let display: String
    /// For `weather`: the city id.
    let subject: String?

    init(kind: Kind, key: String, value: String, display: String? = nil, subject: String? = nil) {
        self.kind = kind
        self.key = key
        self.value = value
        self.display = display ?? value
        self.subject = subject
    }
}

struct LotoChaosPoint: Equatable {
    let x: Double
    let y: Double
    let z: Double

    func distance(to other: LotoChaosPoint) -> Double {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }
}

struct LotoChaosResult: Equatable {
    let tickets: [[Int]]
    let factors: [LotoChaosFactor]
    /// First bytes of the fingerprint in hex, to show that any change of a factor changes all of it.
    let fingerprint: String
    let original: [LotoChaosPoint]
    let perturbed: [LotoChaosPoint]
    /// How far apart the two copies started.
    let perturbation: Double
    /// First sample at which the two copies are further apart than `LotoChaosEngine.divergenceDistance`.
    let divergenceIndex: Int?
    /// Distance between the two copies at the last sample.
    let finalDistance: Double
}

enum LotoChaosEngine {
    static let perturbation = 1e-6
    /// Beyond this distance (the whole attractor is about 50 wide) the two paths are no longer the same story.
    static let divergenceDistance = 5.0
    static let sampleCount = 2_000
    static let stepsPerSample = 3
    static let stepSize = 0.01
    private static let settleSteps = 500

    /// The fingerprint of a set of factors: order does not matter, any change of any factor changes every byte.
    static func fingerprint(of factors: [LotoChaosFactor]) -> [UInt8] {
        let text = factors.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        return Array(SHA256.hash(data: Data(text.utf8)))
    }

    static func run(factors: [LotoChaosFactor], game: LotoGame, signals: LotoSignals, randomness: Double,
                    ticketCount: Int = LotoRandomizer.setsPerSpin) -> LotoChaosResult {
        let digest = fingerprint(of: factors)
        let start = initialState(from: digest)
        let original = path(from: start)
        let nudged = LotoChaosPoint(x: start.x + perturbation, y: start.y, z: start.z)
        let perturbed = path(from: nudged)

        let distances = zip(original, perturbed).map { $0.distance(to: $1) }
        let divergence = distances.firstIndex { $0 > divergenceDistance }
        let finalDistance = distances.last ?? 0

        // The end states of both copies are part of the key: the numbers depend on the whole path, not on the fingerprint alone.
        var keyed = Data(digest)
        for point in [original.last, perturbed.last].compactMap({ $0 }) {
            for value in [point.x, point.y, point.z] { withUnsafeBytes(of: value.bitPattern.bigEndian) { keyed.append(contentsOf: $0) } }
        }
        var stream = LotoHashStream(key: Data(SHA256.hash(data: keyed)))
        var source = LotoRandomSource { stream.next() }
        let tickets = LotoRandomizer.tickets(game: game, signals: signals, randomness: randomness, count: ticketCount, using: &source)

        return LotoChaosResult(tickets: tickets, factors: factors.sorted { $0.key < $1.key },
                               fingerprint: digest.prefix(6).map { String(format: "%02x", $0) }.joined(),
                               original: original, perturbed: perturbed, perturbation: perturbation,
                               divergenceIndex: divergence, finalDistance: finalDistance)
    }

    // MARK: Lorenz system

    /// A point near the attractor chosen by the fingerprint.
    static func initialState(from digest: [UInt8]) -> LotoChaosPoint {
        func unit(_ offset: Int) -> Double {
            let bytes = (0..<4).map { digest[(offset + $0) % digest.count] }
            let value = bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            return Double(value) / Double(UInt32.max)
        }
        return LotoChaosPoint(x: -20 + 40 * unit(0), y: -25 + 50 * unit(4), z: 5 + 40 * unit(8))
    }

    /// `sampleCount` points of the path, after the start has settled onto the attractor.
    static func path(from start: LotoChaosPoint) -> [LotoChaosPoint] {
        var state = start
        for _ in 0..<settleSteps { state = step(state) }
        var points: [LotoChaosPoint] = []
        points.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            for _ in 0..<stepsPerSample { state = step(state) }
            points.append(state)
        }
        return points
    }

    private static func derivative(_ p: LotoChaosPoint) -> LotoChaosPoint {
        // σ = 10, ρ = 28, β = 8/3: the values of Lorenz's 1963 weather model.
        LotoChaosPoint(x: 10 * (p.y - p.x), y: p.x * (28 - p.z) - p.y, z: p.x * p.y - 8.0 / 3.0 * p.z)
    }

    /// One Runge–Kutta step. Only + − × ÷ are used, so the same start gives the same path on every device.
    private static func step(_ p: LotoChaosPoint) -> LotoChaosPoint {
        func add(_ a: LotoChaosPoint, _ b: LotoChaosPoint, _ k: Double) -> LotoChaosPoint {
            LotoChaosPoint(x: a.x + b.x * k, y: a.y + b.y * k, z: a.z + b.z * k)
        }
        let h = stepSize
        let k1 = derivative(p)
        let k2 = derivative(add(p, k1, h / 2))
        let k3 = derivative(add(p, k2, h / 2))
        let k4 = derivative(add(p, k3, h))
        return LotoChaosPoint(x: p.x + h / 6 * (k1.x + 2 * k2.x + 2 * k3.x + k4.x),
                              y: p.y + h / 6 * (k1.y + 2 * k2.y + 2 * k3.y + k4.y),
                              z: p.z + h / 6 * (k1.z + 2 * k2.z + 2 * k3.z + k4.z))
    }
}

/// SHA-256 in counter mode: a stream of uniformly spread 64-bit values from one key.
struct LotoHashStream {
    private let key: Data
    private var counter: UInt64 = 0

    init(key: Data) { self.key = key }

    mutating func next() -> UInt64 {
        var block = key
        withUnsafeBytes(of: counter.bigEndian) { block.append(contentsOf: $0) }
        counter &+= 1
        return SHA256.hash(data: block).prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    }
}
