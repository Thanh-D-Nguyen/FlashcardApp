//
//  HandwritingRecognitionService.swift
//  FlashcardApp
//
//  Recognizes a handwritten kanji or kana by comparing the strokes the learner drew with the stroke shapes of every
//  character in `HandwritingTemplates.bin` (KanjiVG, © Ulrich Apel, CC BY-SA 3.0; built by
//  `scripts/build-handwriting-templates.py`). It runs on the device, the strokes are never uploaded or stored, and it
//  only ever offers characters that exist in the template file: when nothing is close enough the list is empty.
//
//  Matching ignores stroke order and tolerates a missing, merged or extra stroke: every drawn stroke is paired with at
//  most one template stroke (optimal assignment, direction-aware), unpaired strokes cost a fixed penalty, and a small
//  term prefers the usual stroke order.
//

import CoreGraphics
import Foundation
import RxSwift
import simd

/// One sampled position of a stroke.
struct InkPoint: Equatable {
    var location: CGPoint
}

/// What the learner has drawn, stroke by stroke in drawing order, in any coordinate space (only the shape matters).
struct HandwritingInk: Equatable {
    static let maximumStrokes = 40
    static let maximumPointsPerStroke = 2_000

    var strokes: [[InkPoint]] = []

    /// Strokes of at least two distinct positions; a tap is not a line.
    var lines: [[CGPoint]] {
        strokes.compactMap { stroke in
            let points = stroke.map(\.location)
            guard let first = points.first, points.contains(where: { $0 != first }) else { return nil }
            return points
        }
    }

    var isEmpty: Bool { lines.isEmpty }
}

enum HandwritingRecognitionError: Error, Equatable, LocalizedError {
    case tooMuchInk
    case templatesUnavailable

    var errorDescription: String? {
        switch self {
        case .tooMuchInk: return NSLocalizedString("That is too much to read. Clear the canvas and write one character at a time.", comment: "")
        case .templatesUnavailable: return NSLocalizedString("Handwriting recognition isn’t available in this version of the app.", comment: "")
        }
    }
}

protocol HandwritingRecognizing: AnyObject {
    /// Characters that look like the ink, best first, without duplicates; empty when nothing is close enough.
    func candidates(for ink: HandwritingInk) -> Single<[String]>
}

// MARK: - Stroke geometry

enum HandwritingGeometry {
    typealias Stroke = [SIMD2<Float>]

    static let pointsPerStroke = 12

    /// Strokes resampled to `pointsPerStroke` points of equal arc length, then scaled uniformly so the whole character fits
    /// a unit box and centred on it. `nil` when there is no line or it is a single point.
    static func normalize(_ strokes: [[CGPoint]]) -> [Stroke]? {
        let resampled = strokes.compactMap { resample($0.map { SIMD2<Float>(Float($0.x), Float($0.y)) }) }
        guard !resampled.isEmpty else { return nil }
        var low = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for point in resampled.joined() {
            low = simd_min(low, point)
            high = simd_max(high, point)
        }
        let extent = max(high.x - low.x, high.y - low.y)
        guard extent.isFinite, extent > 0 else { return nil }
        let center = (low + high) / 2
        return resampled.map { $0.map { ($0 - center) / extent } }
    }

    static func resample(_ points: [SIMD2<Float>]) -> Stroke? {
        guard points.count >= 2 else { return nil }
        var cumulative: [Float] = [0]
        for index in 1..<points.count { cumulative.append(cumulative[index - 1] + simd_distance(points[index - 1], points[index])) }
        guard let total = cumulative.last, total.isFinite, total > 0 else { return nil }
        var result: Stroke = []
        var segment = 0
        for step in 0..<pointsPerStroke {
            let target = total * Float(step) / Float(pointsPerStroke - 1)
            while segment < points.count - 2, cumulative[segment + 1] < target { segment += 1 }
            let span = cumulative[segment + 1] - cumulative[segment]
            let fraction = span > 0 ? (target - cumulative[segment]) / span : 0
            result.append(points[segment] + (points[segment + 1] - points[segment]) * min(max(fraction, 0), 1))
        }
        return result
    }

    /// Mean distance between the points of two strokes of the same length (direction matters).
    static func distance(_ a: Stroke, _ b: Stroke) -> Float {
        var sum: Float = 0
        for index in 0..<a.count { sum += simd_distance(a[index], b[index]) }
        return sum / Float(a.count)
    }
}

// MARK: - Templates

struct HandwritingTemplate {
    let scalar: UInt32
    let strokes: [HandwritingGeometry.Stroke]

    var character: String? { Unicode.Scalar(scalar).map { String(Character($0)) } }
}

struct HandwritingTemplateStore {
    enum Failure: Error, Equatable { case malformed }

    let templates: [HandwritingTemplate]

    init(templates: [HandwritingTemplate]) { self.templates = templates }

    /// Reads the file written by `scripts/build-handwriting-templates.py`; anything that does not add up is refused whole.
    init(data: Data) throws {
        var offset = 0
        func read<T: FixedWidthInteger>(_: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard offset + size <= data.count else { throw Failure.malformed }
            defer { offset += size }
            return data[data.startIndex + offset ..< data.startIndex + offset + size].reduce(T.zero) { ($0 << 8) | T($1) }.byteSwapped
        }
        guard data.count >= 10, data.prefix(4) == Data("KVGH".utf8) else { throw Failure.malformed }
        offset = 4
        guard try read(UInt8.self) == 1 else { throw Failure.malformed }
        let points = Int(try read(UInt8.self))
        let count = Int(try read(UInt32.self))
        guard points >= 2, count > 0, count <= 100_000 else { throw Failure.malformed }
        var result: [HandwritingTemplate] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            let scalar = try read(UInt32.self)
            let strokeCount = Int(try read(UInt8.self))
            guard strokeCount > 0, Unicode.Scalar(scalar) != nil, offset + strokeCount * points * 2 <= data.count else { throw Failure.malformed }
            var strokes: [[CGPoint]] = []
            for _ in 0..<strokeCount {
                strokes.append((0..<points).map { _ in
                    let x = data[data.startIndex + offset], y = data[data.startIndex + offset + 1]
                    offset += 2
                    return CGPoint(x: Double(x) / 2, y: Double(y) / 2)
                })
            }
            // Templates are stored at the same sampling as drawn ink, so both go through the one normalization.
            guard let normalized = HandwritingGeometry.normalize(strokes) else { throw Failure.malformed }
            result.append(HandwritingTemplate(scalar: scalar, strokes: normalized))
        }
        guard offset == data.count else { throw Failure.malformed }
        templates = result
    }

    static func load(from bundle: Bundle = .main) throws -> HandwritingTemplateStore {
        guard let url = bundle.url(forResource: "HandwritingTemplates", withExtension: "bin") else { throw HandwritingRecognitionError.templatesUnavailable }
        return try HandwritingTemplateStore(data: Data(contentsOf: url, options: .mappedIfSafe))
    }
}

// MARK: - Matching

struct HandwritingMatcher {
    /// A drawn stroke with no partner (or a template stroke nobody drew) costs this much, about a third of the character's size.
    static let unpairedPenalty: Float = 0.35
    /// How strongly a pairing that breaks the usual stroke order is disliked.
    static let orderWeight: Float = 0.06
    /// Templates whose stroke count differs from the drawing's by more than this are not considered.
    static let strokeCountTolerance = 2
    /// A character farther than this (mean distance per stroke, in character sizes) from the drawing is not offered.
    static let maximumScore: Float = 0.30

    let store: HandwritingTemplateStore

    struct Match: Equatable {
        let character: String
        let score: Float
    }

    func matches(for strokes: [HandwritingGeometry.Stroke], limit: Int) -> [Match] {
        guard limit > 0 else { return [] }
        // Cheap pass: a lower bound on every template's score. The exact (cubic) pairing then only runs on templates whose
        // bound could still beat the current `limit`-th best, closest first, so most of the file is never paired exactly.
        var pool: [(index: Int, bound: Float)] = []
        for (index, template) in store.templates.enumerated() where abs(template.strokes.count - strokes.count) <= Self.strokeCountTolerance {
            let size = max(strokes.count, template.strokes.count)
            let bound = Self.lowerBound(Self.costMatrix(drawn: strokes, template: template.strokes), size: size) / Float(size)
            if bound <= Self.maximumScore { pool.append((index, bound)) }
        }
        pool.sort { $0.bound < $1.bound }
        var best: [Match] = []
        for candidate in pool {
            if best.count == limit, candidate.bound >= best[limit - 1].score { break }
            let template = store.templates[candidate.index]
            guard let character = template.character else { continue }
            let score = Self.score(drawn: strokes, template: template.strokes)
            guard score <= Self.maximumScore else { continue }
            let position = best.firstIndex { $0.score > score } ?? best.count
            best.insert(Match(character: character, score: score), at: position)
            if best.count > limit { best.removeLast() }
        }
        return best
    }

    static func score(drawn: [HandwritingGeometry.Stroke], template: [HandwritingGeometry.Stroke]) -> Float {
        let size = max(drawn.count, template.count)
        return assignmentCost(costMatrix(drawn: drawn, template: template), size: size) / Float(size)
    }

    /// Row-major `size × size` matrix: the cost of pairing each drawn stroke (row) with each template stroke (column).
    /// Rows or columns beyond the real strokes are "unpaired" and cost the same penalty with everything.
    static func costMatrix(drawn: [HandwritingGeometry.Stroke], template: [HandwritingGeometry.Stroke]) -> [Float] {
        let size = max(drawn.count, template.count)
        var cost = [Float](repeating: unpairedPenalty, count: size * size)
        for row in 0..<drawn.count {
            for column in 0..<template.count {
                let ordering = orderWeight * Float(abs(row - column)) / Float(size)
                cost[row * size + column] = HandwritingGeometry.distance(drawn[row], template[column]) + ordering
            }
        }
        return cost
    }

    /// Every row must pair with some column, so the sum of the row minimums can never exceed the best pairing.
    static func lowerBound(_ cost: [Float], size: Int) -> Float {
        var total: Float = 0
        for row in 0..<size { total += cost[row * size ..< (row + 1) * size].min() ?? 0 }
        return total
    }

    /// Minimum total cost of pairing every row with a different column (Hungarian algorithm with potentials, O(n³)).
    static func assignmentCost(_ cost: [Float], size n: Int) -> Float {
        var u = [Float](repeating: 0, count: n + 1), v = [Float](repeating: 0, count: n + 1)
        var p = [Int](repeating: 0, count: n + 1), way = [Int](repeating: 0, count: n + 1)
        for i in 1...n {
            p[0] = i
            var j0 = 0
            var minv = [Float](repeating: .greatestFiniteMagnitude, count: n + 1)
            var used = [Bool](repeating: false, count: n + 1)
            repeat {
                used[j0] = true
                let i0 = p[j0]
                var delta = Float.greatestFiniteMagnitude
                var j1 = 0
                for j in 1...n where !used[j] {
                    let current = cost[(i0 - 1) * n + (j - 1)] - u[i0] - v[j]
                    if current < minv[j] { minv[j] = current; way[j] = j0 }
                    if minv[j] < delta { delta = minv[j]; j1 = j }
                }
                for j in 0...n {
                    if used[j] { u[p[j]] += delta; v[j] -= delta } else { minv[j] -= delta }
                }
                j0 = j1
            } while p[j0] != 0
            repeat {
                let j1 = way[j0]
                p[j0] = p[j1]
                j0 = j1
            } while j0 != 0
        }
        var total: Float = 0
        for j in 1...n { total += cost[(p[j] - 1) * n + (j - 1)] }
        return total
    }
}

// MARK: - Recognizer

final class StrokeTemplateRecognizer: HandwritingRecognizing {
    static let candidateLimit = 12

    private let loadStore: () throws -> HandwritingTemplateStore
    private let lock = NSLock()
    private var cached: Result<HandwritingTemplateStore, Error>?

    init(loadStore: @escaping () throws -> HandwritingTemplateStore = { try HandwritingTemplateStore.load() }) {
        self.loadStore = loadStore
    }

    func candidates(for ink: HandwritingInk) -> Single<[String]> {
        Single.create { [self] observer in
            guard ink.strokes.count <= HandwritingInk.maximumStrokes,
                  ink.strokes.allSatisfy({ $0.count <= HandwritingInk.maximumPointsPerStroke }) else {
                observer(.failure(HandwritingRecognitionError.tooMuchInk))
                return Disposables.create()
            }
            let work = DispatchWorkItem { [self] in
                do {
                    guard let strokes = HandwritingGeometry.normalize(ink.lines) else { return observer(.success([])) }
                    let matcher = HandwritingMatcher(store: try store())
                    observer(.success(matcher.matches(for: strokes, limit: Self.candidateLimit).map(\.character)))
                } catch {
                    observer(.failure(error))
                }
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
            return Disposables.create { work.cancel() }
        }
    }

    private func store() throws -> HandwritingTemplateStore {
        lock.lock()
        defer { lock.unlock() }
        if cached == nil { cached = Result { try loadStore() } }
        return try cached!.get()
    }
}
