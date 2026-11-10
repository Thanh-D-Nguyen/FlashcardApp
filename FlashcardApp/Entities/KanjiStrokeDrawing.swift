//
//  KanjiStrokeDrawing.swift
//  FlashcardApp
//
//  Stroke order of a kanji, read from the KanjiVG SVG the backend serves at `/kanji/{id}/stroke`. Only `<path d>` data is
//  used (in document order, which is stroke order); every other element, attribute and style in the file is ignored and
//  the path syntax is parsed here instead of handing the file to a renderer. Anything the parser does not understand
//  refuses the whole drawing, so a half-drawn or reordered kanji is never shown. KanjiVG is © Ulrich Apel, CC BY-SA 3.0.
//

import CoreGraphics
import CryptoKit
import Foundation

struct KanjiStrokeDrawing: Equatable {
    enum Failure: Error, Equatable { case notSVG, forbidden, noStrokes, tooManyStrokes, invalidPath }

    struct Stroke: Equatable {
        /// 1-based position in the stroke order.
        let number: Int
        let path: CGPath
    }

    static let maximumStrokes = 64
    static let maximumPathLength = 2_000
    /// KanjiVG draws on a 109 × 109 grid.
    static let defaultSize = CGSize(width: 109, height: 109)

    let size: CGSize
    let strokes: [Stroke]

    init(svg: String) throws {
        // KanjiVG files carry no DOCTYPE; refusing one rules out entity expansion tricks before the parser runs.
        let lowered = svg.lowercased()
        guard !lowered.contains("<!doctype"), !lowered.contains("<!entity") else { throw Failure.forbidden }
        guard lowered.contains("<svg") else { throw Failure.notSVG }
        let collector = Collector()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        guard parser.parse(), collector.sawSVGRoot else { throw Failure.notSVG }
        guard !collector.pathData.isEmpty else { throw Failure.noStrokes }
        guard collector.pathData.count <= Self.maximumStrokes else { throw Failure.tooManyStrokes }
        size = collector.size ?? Self.defaultSize
        strokes = try collector.pathData.enumerated().map { index, data in
            guard data.count <= Self.maximumPathLength else { throw Failure.invalidPath }
            return Stroke(number: index + 1, path: try SVGPathParser.path(from: data))
        }
    }

    // MARK: Integrity

    static func sha256Hex(of text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// `true` when the text hashes to the value the API published for it; without a published hash there is nothing to compare.
    static func matches(_ svg: String, expectedHash: String?) -> Bool {
        guard let expected = expectedHash?.trimmingCharacters(in: .whitespaces).lowercased(), !expected.isEmpty else { return true }
        return sha256Hex(of: svg) == expected
    }

    // MARK: Reading the file

    private final class Collector: NSObject, XMLParserDelegate {
        var pathData: [String] = []
        var size: CGSize?
        var sawSVGRoot = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String]) {
            switch elementName {
            case "svg":
                sawSVGRoot = true
                if let box = attributes["viewBox"] {
                    let numbers = box.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
                    if numbers.count == 4, numbers[2] > 0, numbers[3] > 0, numbers[2] <= 4_096, numbers[3] <= 4_096 {
                        size = CGSize(width: numbers[2], height: numbers[3])
                    }
                }
            case "path":
                // An empty or absent `d` is a drawing instruction we cannot honour; keep the slot so the count stays honest.
                pathData.append(attributes["d"] ?? "")
            default:
                break
            }
        }
    }
}

/// The subset of SVG path syntax KanjiVG uses (M L H V C S Q T Z, absolute and relative). Elliptical arcs are rejected.
enum SVGPathParser {
    static func path(from data: String) throws -> CGPath {
        var scanner = Scanner(Array(data.unicodeScalars))
        let path = CGMutablePath()
        var current = CGPoint.zero, start = CGPoint.zero
        var lastCubicControl: CGPoint?, lastQuadControl: CGPoint?
        var command: Character?
        var hasStarted = false

        while true {
            scanner.skipSeparators()
            if scanner.atEnd { break }
            if let letter = scanner.peekCommand() {
                command = letter
                scanner.advance()
                if letter == "z" || letter == "Z" {
                    guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                    path.closeSubpath()
                    current = start
                    lastCubicControl = nil; lastQuadControl = nil
                    continue
                }
            }
            guard let active = command else { throw KanjiStrokeDrawing.Failure.invalidPath }
            let relative = active.isLowercase
            func absolute(_ x: Double, _ y: Double) -> CGPoint {
                relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch active {
            case "M", "m":
                let (x, y) = try scanner.pair()
                current = absolute(x, y)
                start = current
                path.move(to: current)
                hasStarted = true
                // Further pairs after a moveto are implicit linetos.
                command = relative ? "l" : "L"
                lastCubicControl = nil; lastQuadControl = nil
            case "L", "l":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let (x, y) = try scanner.pair()
                current = absolute(x, y)
                path.addLine(to: current)
                lastCubicControl = nil; lastQuadControl = nil
            case "H", "h":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let x = try scanner.number()
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastCubicControl = nil; lastQuadControl = nil
            case "V", "v":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let y = try scanner.number()
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastCubicControl = nil; lastQuadControl = nil
            case "C", "c":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let (x1, y1) = try scanner.pair(), (x2, y2) = try scanner.pair(), (x, y) = try scanner.pair()
                let c1 = absolute(x1, y1), c2 = absolute(x2, y2), end = absolute(x, y)
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
                lastCubicControl = c2; lastQuadControl = nil
            case "S", "s":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let (x2, y2) = try scanner.pair(), (x, y) = try scanner.pair()
                let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = absolute(x2, y2), end = absolute(x, y)
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
                lastCubicControl = c2; lastQuadControl = nil
            case "Q", "q":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let (x1, y1) = try scanner.pair(), (x, y) = try scanner.pair()
                let control = absolute(x1, y1), end = absolute(x, y)
                path.addQuadCurve(to: end, control: control)
                current = end
                lastQuadControl = control; lastCubicControl = nil
            case "T", "t":
                guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
                let (x, y) = try scanner.pair()
                let control = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let end = absolute(x, y)
                path.addQuadCurve(to: end, control: control)
                current = end
                lastQuadControl = control; lastCubicControl = nil
            default:
                // Arcs (A/a) and anything unknown.
                throw KanjiStrokeDrawing.Failure.invalidPath
            }
        }
        guard hasStarted else { throw KanjiStrokeDrawing.Failure.invalidPath }
        return path
    }

    private struct Scanner {
        private let scalars: [Unicode.Scalar]
        private var index = 0

        init(_ scalars: [Unicode.Scalar]) { self.scalars = scalars }

        var atEnd: Bool { index >= scalars.count }
        mutating func advance() { index += 1 }

        mutating func skipSeparators() {
            while index < scalars.count, scalars[index] == " " || scalars[index] == "," || scalars[index] == "\n" || scalars[index] == "\t" || scalars[index] == "\r" {
                index += 1
            }
        }

        func peekCommand() -> Character? {
            guard index < scalars.count else { return nil }
            let scalar = scalars[index]
            return scalar.properties.isAlphabetic && scalar != "e" && scalar != "E" ? Character(scalar) : nil
        }

        mutating func pair() throws -> (Double, Double) { (try number(), try number()) }

        mutating func number() throws -> Double {
            skipSeparators()
            let begin = index
            if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" { index += 1 }
            var digits = 0, sawDot = false
            while index < scalars.count {
                let scalar = scalars[index]
                if ("0"..."9").contains(scalar) { digits += 1; index += 1 }
                else if scalar == ".", !sawDot { sawDot = true; index += 1 }
                else { break }
            }
            guard digits > 0 else { throw KanjiStrokeDrawing.Failure.invalidPath }
            if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
                var probe = index + 1
                if probe < scalars.count, scalars[probe] == "-" || scalars[probe] == "+" { probe += 1 }
                var exponentDigits = 0
                while probe < scalars.count, ("0"..."9").contains(scalars[probe]) { probe += 1; exponentDigits += 1 }
                if exponentDigits > 0 { index = probe }
            }
            var text = ""
            text.unicodeScalars.append(contentsOf: scalars[begin..<index])
            guard let value = Double(text), value.isFinite, abs(value) < 1e6 else { throw KanjiStrokeDrawing.Failure.invalidPath }
            return value
        }
    }
}
