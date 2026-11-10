import RxSwift
import XCTest
@testable import FlashcardApp

/// Deterministic generator so the measured accuracy is reproducible.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class HandwritingRecognitionTests: XCTestCase {
    private let bag = DisposeBag()

    // MARK: Helpers

    private func ink(_ strokes: [[CGPoint]]) -> HandwritingInk {
        HandwritingInk(strokes: strokes.map { $0.map { InkPoint(location: $0) } })
    }

    private func line(_ a: CGPoint, _ b: CGPoint, steps: Int = 20) -> [CGPoint] {
        (0...steps).map { CGPoint(x: a.x + (b.x - a.x) * CGFloat($0) / CGFloat(steps), y: a.y + (b.y - a.y) * CGFloat($0) / CGFloat(steps)) }
    }

    private func recognize(_ recognizer: HandwritingRecognizing, _ ink: HandwritingInk) throws -> [String] {
        let done = expectation(description: "recognized")
        var outcome: Result<[String], Error>?
        recognizer.candidates(for: ink).subscribe(onSuccess: { outcome = .success($0); done.fulfill() },
                                                  onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 120)
        return try XCTUnwrap(outcome).get()
    }

    /// Flattens KanjiVG curves into dense points, as a finger would sample them.
    static func points(of path: CGPath) -> [CGPoint] {
        var result: [CGPoint] = []
        var current = CGPoint.zero
        path.applyWithBlock { element in
            let p = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                current = p[0]; result.append(current)
            case .addQuadCurveToPoint:
                for i in 1...10 {
                    let t = CGFloat(i) / 10, u = 1 - t
                    result.append(CGPoint(x: u * u * current.x + 2 * u * t * p[0].x + t * t * p[1].x, y: u * u * current.y + 2 * u * t * p[0].y + t * t * p[1].y))
                }
                current = p[1]
            case .addCurveToPoint:
                for i in 1...10 {
                    let t = CGFloat(i) / 10, u = 1 - t
                    result.append(CGPoint(x: u * u * u * current.x + 3 * u * u * t * p[0].x + 3 * u * t * t * p[1].x + t * t * t * p[2].x,
                                          y: u * u * u * current.y + 3 * u * u * t * p[0].y + 3 * u * t * t * p[1].y + t * t * t * p[2].y))
                }
                current = p[2]
            default: break
            }
        }
        return result
    }

    /// Whole-character skew/scale/rotation, per-stroke shift and a smooth wobble: a rough stand-in for a shaky hand.
    static func shaky(_ strokes: [[CGPoint]], level: CGFloat, rng: inout SeededGenerator) -> [[CGPoint]] {
        func r(_ x: CGFloat) -> CGFloat { CGFloat.random(in: -x...x, using: &rng) }
        let angle = r(0.12 * level), sx = 1 + r(0.15 * level), sy = 1 + r(0.15 * level), shear = r(0.1 * level)
        return strokes.map { stroke in
            let dx = r(0.025 * level), dy = r(0.025 * level), turn = r(0.06 * level), phase = r(3)
            return stroke.enumerated().map { index, point in
                var x = point.x - 0.5, y = point.y - 0.5
                x += shear * y
                let c = cos(angle + turn), s = sin(angle + turn)
                (x, y) = ((x * c - y * s) * sx + dx, (x * s + y * c) * sy + dy)
                let wobble = 0.012 * level * sin(CGFloat(index) / CGFloat(stroke.count) * 6 + phase)
                return CGPoint(x: x + wobble + 0.5, y: y - wobble + 0.5)
            }
        }
    }

    // MARK: Geometry

    func testTapsAndSinglePointsAreNotInk() {
        XCTAssertTrue(ink([[CGPoint(x: 5, y: 5)], [CGPoint(x: 9, y: 9), CGPoint(x: 9, y: 9)]]).isEmpty)
        XCTAssertNil(HandwritingGeometry.normalize([[CGPoint(x: 5, y: 5)]]))
        XCTAssertFalse(ink([line(.zero, CGPoint(x: 10, y: 0))]).isEmpty)
    }

    func testNormalizationIgnoresSizeAndPosition() throws {
        let small = line(CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)) , other = line(CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 0))
        let big = [small, other].map { $0.map { CGPoint(x: $0.x * 30 + 200, y: $0.y * 30 + 40) } }
        let a = try XCTUnwrap(HandwritingGeometry.normalize([small, other]))
        let b = try XCTUnwrap(HandwritingGeometry.normalize(big))
        for (x, y) in zip(a.joined(), b.joined()) { XCTAssertEqual(x.x, y.x, accuracy: 0.001); XCTAssertEqual(x.y, y.y, accuracy: 0.001) }
        XCTAssertTrue(a.joined().allSatisfy { abs($0.x) <= 0.5001 && abs($0.y) <= 0.5001 })
    }

    // MARK: Template file

    func testTheBundledTemplatesLoadAndCoverKanjiAndKana() throws {
        let store = try HandwritingTemplateStore.load(from: Bundle(for: DictionaryHandwritingInteractor.self))
        XCTAssertGreaterThan(store.templates.count, 6_000)
        let characters = Set(store.templates.compactMap(\.character))
        for expected in ["食", "日", "愛", "あ", "ア", "ん", "ヲ"] { XCTAssertTrue(characters.contains(expected), expected) }
        XCTAssertTrue(store.templates.allSatisfy { !$0.strokes.isEmpty && $0.strokes.allSatisfy { $0.count == HandwritingGeometry.pointsPerStroke } })
    }

    func testAMalformedTemplateFileIsRefusedWhole() throws {
        let valid = try Data(contentsOf: XCTUnwrap(Bundle(for: DictionaryHandwritingInteractor.self).url(forResource: "HandwritingTemplates", withExtension: "bin")))
        XCTAssertNoThrow(try HandwritingTemplateStore(data: valid))
        XCTAssertThrowsError(try HandwritingTemplateStore(data: Data()))
        XCTAssertThrowsError(try HandwritingTemplateStore(data: Data("NOPE".utf8) + valid.dropFirst(4)))
        XCTAssertThrowsError(try HandwritingTemplateStore(data: valid.dropLast(7)), "Truncated file")
        XCTAssertThrowsError(try HandwritingTemplateStore(data: valid + Data([0])), "Trailing bytes")
    }

    // MARK: Matching on a tiny store

    private func store(_ shapes: [(UInt32, [[CGPoint]])]) throws -> HandwritingTemplateStore {
        HandwritingTemplateStore(templates: try shapes.map { HandwritingTemplate(scalar: $0.0, strokes: try XCTUnwrap(HandwritingGeometry.normalize($0.1))) })
    }

    private var cross: [[CGPoint]] { [line(CGPoint(x: 0, y: 50), CGPoint(x: 100, y: 50)), line(CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 100))] }

    func testStrokeOrderAndDirectionAreWhatDistinguishCharacters() throws {
        let matcher = HandwritingMatcher(store: try store([(0x5341, cross), (0x4E00, [line(CGPoint(x: 0, y: 50), CGPoint(x: 100, y: 50))])]))
        // Same shape, strokes drawn in the other order: still 十.
        let swapped = try XCTUnwrap(HandwritingGeometry.normalize([cross[1], cross[0]]))
        XCTAssertEqual(matcher.matches(for: swapped, limit: 5).first?.character, "十")
        // One stroke only: 一 first, and 十 (one missing stroke) is still offered after it.
        let single = try XCTUnwrap(HandwritingGeometry.normalize([cross[0]]))
        XCTAssertEqual(matcher.matches(for: single, limit: 5).map(\.character), ["一", "十"])
        // A stroke drawn backwards is a different shape for a direction-aware matcher.
        let backwards = try XCTUnwrap(HandwritingGeometry.normalize([line(CGPoint(x: 100, y: 50), CGPoint(x: 0, y: 50)), cross[1]]))
        let forward = try XCTUnwrap(HandwritingGeometry.normalize(cross))
        XCTAssertGreaterThan(HandwritingMatcher.score(drawn: backwards, template: forward),
                             HandwritingMatcher.score(drawn: forward, template: forward) + 0.1)
    }

    func testAScribbleMatchesNothing() throws {
        let matcher = HandwritingMatcher(store: try store([(0x5341, cross)]))
        let zigzag = (0..<12).map { CGPoint(x: Double($0) * 9, y: $0 % 2 == 0 ? 0 : 100) }
        XCTAssertTrue(matcher.matches(for: try XCTUnwrap(HandwritingGeometry.normalize([zigzag, zigzag.reversed()])), limit: 5).isEmpty)
    }

    func testTemplatesWithTooDifferentAStrokeCountAreNotConsidered() throws {
        let matcher = HandwritingMatcher(store: try store([(0x5341, cross)]))
        let many = (0..<6).map { line(CGPoint(x: 0, y: Double($0) * 20), CGPoint(x: 100, y: Double($0) * 20)) }
        XCTAssertTrue(matcher.matches(for: try XCTUnwrap(HandwritingGeometry.normalize(many)), limit: 5).isEmpty)
    }

    func testAssignmentCostFindsTheCheapestPairing() {
        // Rows pick columns 1, 0, 2 (cost 1 + 2 + 3) although the diagonal is cheaper in the first row.
        let cost: [Float] = [5, 1, 9,
                             2, 8, 9,
                             9, 9, 3]
        XCTAssertEqual(HandwritingMatcher.assignmentCost(cost, size: 3), 6, accuracy: 0.0001)
        XCTAssertEqual(HandwritingMatcher.lowerBound(cost, size: 3), 6, accuracy: 0.0001)
    }

    // MARK: Recognizer

    func testEmptyInkReadsNothingAndTooMuchInkIsRefused() throws {
        let recognizer = StrokeTemplateRecognizer(loadStore: { try XCTUnwrap(nil as HandwritingTemplateStore?) })
        XCTAssertEqual(try recognize(recognizer, HandwritingInk()), [])
        let flood = ink((0...HandwritingInk.maximumStrokes).map { _ in line(.zero, CGPoint(x: 10, y: 10)) })
        XCTAssertThrowsError(try recognize(recognizer, flood)) { XCTAssertEqual($0 as? HandwritingRecognitionError, .tooMuchInk) }
    }

    func testAMissingTemplateFileIsAnErrorNotAnEmptyAnswer() throws {
        let recognizer = StrokeTemplateRecognizer(loadStore: { throw HandwritingRecognitionError.templatesUnavailable })
        XCTAssertThrowsError(try recognize(recognizer, ink([line(.zero, CGPoint(x: 10, y: 10))]))) {
            XCTAssertEqual($0 as? HandwritingRecognitionError, .templatesUnavailable)
        }
    }

    /// Real KanjiVG strokes from the API fixture (not the resampled template file), drawn with a shaky hand.
    func testARealKanjiFromTheAPIIsRecognizedFirstDespiteShakyStrokes() throws {
        let drawing = try KanjiStrokeDrawing(svg: KanjiStrokeFixtures.shokuSVG)
        let strokes = drawing.strokes.map { Self.points(of: $0.path).map { CGPoint(x: $0.x / 109, y: $0.y / 109) } }
        let recognizer = StrokeTemplateRecognizer(loadStore: { try HandwritingTemplateStore.load(from: Bundle(for: DictionaryHandwritingInteractor.self)) })
        var rng = SeededGenerator(state: 42)
        for level in [CGFloat(0), 1, 2] {
            XCTAssertEqual(try recognize(recognizer, ink(Self.shaky(strokes, level: level, rng: &rng))).first, "食", "level \(level)")
        }
    }

    /// Measured on a deterministic sample of the template set, distorted: synthetic, not human handwriting.
    func testDistortedCharactersAreFoundInTheTopCandidates() throws {
        let store = try HandwritingTemplateStore.load(from: Bundle(for: DictionaryHandwritingInteractor.self))
        let recognizer = StrokeTemplateRecognizer(loadStore: { store })
        var rng = SeededGenerator(state: 7)
        var first = 0, topFive = 0, total = 0
        for (index, template) in store.templates.enumerated() where index % 260 == 0 {
            let strokes = template.strokes.map { $0.map { CGPoint(x: CGFloat($0.x) + 0.5, y: CGFloat($0.y) + 0.5) } }
            let result = try recognize(recognizer, ink(Self.shaky(strokes, level: 1, rng: &rng)))
            total += 1
            if result.first == template.character { first += 1 }
            if result.prefix(5).contains(template.character ?? "") { topFive += 1 }
        }
        XCTAssertGreaterThan(total, 20)
        XCTAssertGreaterThanOrEqual(Double(first) / Double(total), 0.9, "top-1 \(first)/\(total)")
        XCTAssertGreaterThanOrEqual(Double(topFive) / Double(total), 0.95, "top-5 \(topFive)/\(total)")
    }
}
