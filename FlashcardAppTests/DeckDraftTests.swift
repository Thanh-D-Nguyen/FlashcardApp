import XCTest
@testable import FlashcardApp

final class DeckDraftTests: XCTestCase {
    private func complete(_ front: String, _ back: String) -> CardDraft { CardDraft(front: front, back: back) }

    func test_aNewDraftStartsWithTwoEmptyCardsAndIsNotYetSavable() {
        let draft = DeckDraft()
        XCTAssertEqual(draft.cards.count, 2)
        XCTAssertTrue(draft.cards.allSatisfy(\.isEmpty))
        XCTAssertEqual(draft.issues, [.nameEmpty, .tooFewCards])
    }

    func test_validDraftHasNoIssues() {
        let draft = DeckDraft(name: "N5", cards: [complete("犬", "chó"), complete("猫", "mèo")])
        XCTAssertEqual(draft.issues, [])
    }

    func test_halfFilledCardIsReportedInsteadOfBeingDropped() {
        let draft = DeckDraft(name: "N5", cards: [complete("犬", "chó"), complete("猫", "mèo"), CardDraft(front: "鳥"), CardDraft(back: "cá")])
        XCTAssertEqual(draft.issues, [.incompleteCard(index: 2, missingFront: false), .incompleteCard(index: 3, missingFront: true)])
    }

    func test_whitespaceOnlyTextCountsAsEmpty() {
        XCTAssertTrue(CardDraft(front: "  \n", back: " ").isEmpty)
        XCTAssertFalse(CardDraft(front: "犬", back: " ").isComplete)
    }

    func test_cardWithOnlyAnImageIsNotSilentlyIgnored() {
        let image = CardDraft(imageReference: "local-image:a.jpg")
        XCTAssertFalse(image.isEmpty)
        let draft = DeckDraft(name: "N5", cards: [complete("犬", "chó"), complete("猫", "mèo"), image])
        XCTAssertEqual(draft.issues, [.incompleteCard(index: 2, missingFront: true)])
    }

    func test_tooManyCardsIsRejected() {
        let cards = (0...DeckDraft.maximumCards).map { complete("f\($0)", "b\($0)") }
        XCTAssertTrue(DeckDraft(name: "Big", cards: cards).issues.contains(.tooManyCards))
        XCTAssertFalse(DeckDraft(name: "Max", cards: Array(cards.dropLast())).issues.contains(.tooManyCards))
    }

    func test_entityRoundTripKeepsIdsAndExtraFields() {
        let card = CardEntity()
        card.id = "card-1"
        card.frontText = "会議"
        card.frontExtraText = "かいぎ"
        card.backText = "cuộc họp"
        card.backExtraText = "formal"
        card.imageUrl = "https://example.com/a.jpg"
        let desk = DeskEntity()
        desk.id = "deck-1"
        desk.name = "Work"
        desk.description = "Office words"
        desk.sortingLanguage = .opposite
        desk.cards = [card]
        desk.date = Date(timeIntervalSince1970: 1_700_000_000)

        let draft = DeckDraft(entity: desk)
        let back = draft.toEntity()

        XCTAssertEqual(back.id, "deck-1")
        XCTAssertEqual(back.date, desk.date)
        XCTAssertEqual(back.sortingLanguage, .opposite)
        XCTAssertEqual(back.cards.map(\.id), ["card-1"])
        XCTAssertEqual(back.cards.first?.frontExtraText, "かいぎ")
        XCTAssertEqual(back.cards.first?.backExtraText, "formal")
        XCTAssertEqual(back.cards.first?.imageUrl, "https://example.com/a.jpg")
    }

    func test_newDraftGetsAFreshDeckIdAndEmptyCardsAreLeftOut() {
        let draft = DeckDraft(name: " Trimmed ", cards: [complete("a", "b"), CardDraft(), complete("c", "d")])
        let entity = draft.toEntity(newId: "fixed-id")
        XCTAssertEqual(entity.id, "fixed-id")
        XCTAssertEqual(entity.name, "Trimmed")
        XCTAssertEqual(entity.cards.count, 2)
    }

    func test_draftSurvivesJSONEncoding() throws {
        let draft = DeckDraft(deckId: "d", name: "N", details: "x", direction: .opposite,
                              cards: [CardDraft(id: "1", front: "a", back: "b", reading: "r", note: "n", imageReference: "local-image:x.jpg")],
                              createdAt: Date(timeIntervalSince1970: 5))
        let decoded = try JSONDecoder().decode(DeckDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(decoded, draft)
    }
}

final class BulkDeckImportTests: XCTestCase {
    func test_tabSeparatedLinesWithOptionalImage() {
        let result = BulkDeckImport.parse("犬\tchó\n猫\tmèo\thttps://example.com/cat.jpg")
        XCTAssertEqual(try result.get(), [.init(front: "犬", back: "chó", imageUrl: nil),
                                         .init(front: "猫", back: "mèo", imageUrl: "https://example.com/cat.jpg")])
    }

    func test_pipeSeparatedLinesAndBlankLinesAreSkipped() {
        let result = BulkDeckImport.parse("\n犬 | chó\n\n猫|mèo|https://example.com/a.png\n")
        XCTAssertEqual(try result.get().map(\.front), ["犬", "猫"])
        XCTAssertEqual(try result.get().last?.imageUrl, "https://example.com/a.png")
    }

    func test_lineWithoutSeparatorReportsItsNumber() {
        XCTAssertEqual(BulkDeckImport.parse("犬|chó\nbroken line").failure, .invalidLine(2))
    }

    func test_emptyFrontOrBackIsInvalid() {
        XCTAssertEqual(BulkDeckImport.parse("|chó").failure, .invalidLine(1))
        XCTAssertEqual(BulkDeckImport.parse("犬|").failure, .invalidLine(1))
    }

    func test_onlyHTTPSImagesAreAccepted() {
        XCTAssertEqual(BulkDeckImport.parse("犬|chó|http://example.com/a.jpg").failure, .invalidImageUrl(line: 1))
        XCTAssertEqual(BulkDeckImport.parse("犬|chó|file:///etc/passwd").failure, .invalidImageUrl(line: 1))
        XCTAssertEqual(BulkDeckImport.parse("犬|chó|not a url").failure, .invalidImageUrl(line: 1))
    }

    func test_moreThanTheLimitIsRejectedButTheLimitItselfIsAccepted() {
        func lines(_ count: Int) -> String { (0..<count).map { "f\($0)|b\($0)" }.joined(separator: "\n") }
        XCTAssertEqual(BulkDeckImport.parse(lines(BulkDeckImport.maximumRows + 1)).failure, .tooManyRows)
        XCTAssertEqual(try BulkDeckImport.parse(lines(BulkDeckImport.maximumRows)).get().count, BulkDeckImport.maximumRows)
    }

    func test_emptyInputYieldsNoRows() {
        XCTAssertEqual(try BulkDeckImport.parse("  \n\n").get(), [])
    }
}

private extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
