import XCTest
@testable import FlashcardApp

final class FlashcardAppTests: XCTestCase {
    func testSavedCardKeepsImageAndUUIDAfterRealmRoundTrip() {
        let card = CardEntity()
        card.id = "34794e77-e71b-4c29-afdf-996041567096"
        card.frontText = "日本"
        card.backText = "Nhật Bản"
        card.imageUrl = "https://images.test/saved.jpg"
        let restored = card.toRealm().toEntity()
        XCTAssertEqual(restored.id, card.id)
        XCTAssertEqual(restored.imageUrl, card.imageUrl)
        XCTAssertEqual(restored.frontText, card.frontText)
        XCTAssertEqual(restored.backText, card.backText)
    }
}
