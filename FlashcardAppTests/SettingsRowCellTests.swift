import UIKit
import XCTest
@testable import FlashcardApp

/// Layout of the pop-up value on the "Giao diện" row. The button is the cell's accessory view, so its
/// frame (not Auto Layout) decides how much room the value gets; a stale frame wraps the text.
final class SettingsRowCellTests: XCTestCase {

    private func makeCell(width: CGFloat = 390) -> SettingsRowCell {
        let cell = SettingsRowCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: width, height: 56)
        return cell
    }

    private func configure(_ cell: SettingsRowCell, value: String) {
        cell.configureChoice(title: "Giao diện", iconName: "circle.lefthalf.filled", selectedTitle: value, menu: UIMenu(children: []))
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
    }

    func test_longerValueReplacingShorterOneStaysOnOneLine() throws {
        let cell = makeCell()
        configure(cell, value: "Tối")
        let short = try XCTUnwrap(cell.accessoryView).frame
        configure(cell, value: "Theo hệ thống")
        let long = try XCTUnwrap(cell.accessoryView).frame

        XCTAssertGreaterThan(long.width, short.width, "The button must grow to fit the longer value")
        XCTAssertEqual(long.height, short.height, accuracy: 1, "A taller button means the value wrapped")
    }

    func test_valueStaysFlushWithTrailingEdgeAfterRepeatedReconfiguration() throws {
        let cell = makeCell()
        configure(cell, value: "Theo hệ thống")
        let first = try XCTUnwrap(cell.accessoryView).frame
        for value in ["Tối", "Sáng", "Theo hệ thống"] { configure(cell, value: value) }
        let last = try XCTUnwrap(cell.accessoryView).frame

        XCTAssertEqual(last.width, first.width, accuracy: 1)
        XCTAssertEqual(last.maxX, first.maxX, accuracy: 1)
        XCTAssertEqual(last.height, first.height, accuracy: 1)
    }

    func test_valueIsTruncatedNotWrappedWhenTheRowIsNarrow() throws {
        let cell = makeCell(width: 240)
        configure(cell, value: "Theo hệ thống")
        let button = try XCTUnwrap(cell.accessoryView)

        XCTAssertLessThanOrEqual(button.frame.width, 240 * 0.6 + 1, "The value must leave room for the row title")
        XCTAssertLessThan(button.frame.height, 56, "One line of text fits inside the row; two lines would not")
    }
}
