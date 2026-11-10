import CoreGraphics
import XCTest
@testable import FlashcardApp

final class KanjiStrokeDrawingTests: XCTestCase {
    func testStrokesAreReadInDocumentOrderWithTheViewBoxSize() throws {
        let drawing = try KanjiStrokeDrawing(svg: Self.twoStrokes)
        XCTAssertEqual(drawing.size, CGSize(width: 109, height: 109))
        XCTAssertEqual(drawing.strokes.map(\.number), [1, 2])
        XCTAssertEqual(drawing.strokes[0].path.currentPoint.x, 14, accuracy: 0.001)
        XCTAssertEqual(drawing.strokes[0].path.currentPoint.y, 51.5, accuracy: 0.001)
    }

    func testRelativeAndAbsoluteCommandsEndWhereTheDataSays() throws {
        // M52.75,10.5 then c (relative) …,3.93 → 52.75-0.97, 10.5+3.93 ; C absolute ; s smooth ; l ; h ; v ; z
        let drawing = try KanjiStrokeDrawing(svg: Self.svg(paths: [
            "M10,10c1,1,2,2,3,3", "M10,10C20,20,30,30,40,40", "M0,0c1,1,2,2,3,3s1,1,2,2", "M5,5l10,0h5v5", "M1,1L2,2z"
        ]))
        let ends = drawing.strokes.map(\.path.currentPoint)
        XCTAssertEqual(ends[0], CGPoint(x: 13, y: 13))
        XCTAssertEqual(ends[1], CGPoint(x: 40, y: 40))
        XCTAssertEqual(ends[2], CGPoint(x: 5, y: 5))
        XCTAssertEqual(ends[3], CGPoint(x: 20, y: 10))
        XCTAssertEqual(ends[4], CGPoint(x: 1, y: 1), "z returns to the start of the subpath")
    }

    func testCompactNumbersWithoutSeparatorsAreParsed() throws {
        let drawing = try KanjiStrokeDrawing(svg: Self.svg(paths: ["M52.75,10.5c0.11,0.98-0.19,2.67-0.97,3.93", "M1-.5.5.5"]))
        XCTAssertEqual(drawing.strokes[0].path.currentPoint.x, 51.78, accuracy: 0.001)
        XCTAssertEqual(drawing.strokes[1].path.currentPoint, CGPoint(x: 0.5, y: 0.5), "M1,-.5 then an implicit lineto .5,.5")
    }

    func testOnlyPathsBecomeStrokes_TextScriptsAndStylesAreIgnored() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 109 109"><script>alert(1)</script><style>*{}</style><path d="M1,1L5,5"/><text>1</text><image href="https://x"/></svg>"#
        let drawing = try KanjiStrokeDrawing(svg: svg)
        XCTAssertEqual(drawing.strokes.count, 1)
    }

    func testUnsafeOrUnsupportedDocumentsAreRefusedWhole() {
        let cases: [(String, KanjiStrokeDrawing.Failure)] = [
            ("<html></html>", .notSVG),
            ("not xml", .notSVG),
            (#"<!DOCTYPE svg [<!ENTITY a "aaaa">]><svg xmlns="http://www.w3.org/2000/svg"><path d="M1,1L2,2"/></svg>"#, .forbidden),
            (Self.svg(paths: ["M1,1A5,5,0,0,1,9,9"]), .invalidPath),
            (Self.svg(paths: ["M1,1L2,x"]), .invalidPath),
            (Self.svg(paths: ["L1,1"]), .invalidPath),
            (Self.svg(paths: ["M1,1L2"]), .invalidPath),
            (Self.svg(paths: []), .noStrokes),
            (Self.svg(paths: Array(repeating: "M1,1L2,2", count: 65)), .tooManyStrokes),
            (Self.svg(paths: ["M1,1" + String(repeating: "L2,2", count: 1000)]), .invalidPath)
        ]
        for (svg, expected) in cases {
            XCTAssertThrowsError(try KanjiStrokeDrawing(svg: svg), "expected \(expected)") {
                XCTAssertEqual($0 as? KanjiStrokeDrawing.Failure, expected)
            }
        }
    }

    func testMissingViewBoxFallsBackToTheKanjiVGSize() throws {
        let drawing = try KanjiStrokeDrawing(svg: #"<svg xmlns="http://www.w3.org/2000/svg"><path d="M1,1L2,2"/></svg>"#)
        XCTAssertEqual(drawing.size, CGSize(width: 109, height: 109))
    }

    func testIntegrityHashMatchesTheBackendValue() {
        // The real 食 file hashes to the `strokeSvgHash` the API sends.
        XCTAssertEqual(KanjiStrokeDrawing.sha256Hex(of: "abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertTrue(KanjiStrokeDrawing.matches("abc", expectedHash: "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
        XCTAssertFalse(KanjiStrokeDrawing.matches("abd", expectedHash: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
        XCTAssertTrue(KanjiStrokeDrawing.matches("anything", expectedHash: nil), "No hash from the server means nothing to compare")
        XCTAssertTrue(KanjiStrokeDrawing.matches("anything", expectedHash: ""))
    }

    static func svg(paths: [String]) -> String {
        #"<svg xmlns="http://www.w3.org/2000/svg" width="109" height="109" viewBox="0 0 109 109"><g>"#
            + paths.map { #"<path d="\#($0)"/>"# }.joined() + "</g></svg>"
    }

    static let twoStrokes = svg(paths: ["M52.75,10.5c0.11,0.98-0.19,2.67-0.97,3.93C45,25.34,31.75,41.19,14,51.5", "M52.75,16.25c5.09,4.8,25.71,19.61,33.7,24.9"])
}

extension KanjiStrokeDrawingTests {
    func testTheRealFileWithUndeclaredNamespacePrefixesParsesAsNineStrokesInOrder() throws {
        let drawing = try KanjiStrokeDrawing(svg: KanjiStrokeFixtures.shokuSVG)
        XCTAssertEqual(drawing.strokes.count, 9, "食 is written with nine strokes")
        XCTAssertEqual(drawing.strokes.map(\.number), Array(1...9))
        XCTAssertEqual(drawing.size, CGSize(width: 109, height: 109))
        XCTAssertEqual(drawing.strokes[0].path.boundingBoxOfPath.minX, 14, accuracy: 0.5, "first stroke is the left-falling stroke ending at x=14")
    }

    func testTheRealFileMatchesTheHashTheBackendPublishes() {
        XCTAssertTrue(KanjiStrokeDrawing.matches(KanjiStrokeFixtures.shokuSVG, expectedHash: KanjiStrokeFixtures.shokuHash))
        XCTAssertFalse(KanjiStrokeDrawing.matches(KanjiStrokeFixtures.shokuSVG + " ", expectedHash: KanjiStrokeFixtures.shokuHash))
    }
}
