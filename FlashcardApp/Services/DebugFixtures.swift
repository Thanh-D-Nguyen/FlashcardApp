#if DEBUG
import UIKit

/// Debug builds only: `-SeedCardsFixture` fills an empty library with sample decks (some with pictures) so the Cards
/// screens can be inspected and screenshotted without typing data in. Never runs in Release, never touches a library
/// that already has decks.
enum DebugFixtures {
    static func seedCardsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-SeedCardsFixture"),
              DeskManagement.shared.getAll().isEmpty else { return }
        let store = CardImageStore.shared
        func picture(_ text: String, _ color: UIColor) -> String {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 520))
            let image = renderer.image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 520))
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                (text as NSString).draw(in: CGRect(x: 0, y: 150, width: 800, height: 260), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 220, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: style])
            }
            return (try? store.save(image: image)) ?? ""
        }
        func card(_ front: String, _ reading: String, _ back: String, note: String = "", image: String = "") -> CardEntity {
            let entity = CardEntity()
            entity.frontText = front
            entity.frontExtraText = reading
            entity.backText = back
            entity.backExtraText = note
            entity.imageUrl = image
            return entity
        }
        func deck(_ name: String, _ details: String, _ direction: LanguageSortingType, _ cards: [CardEntity], age: TimeInterval) -> DeskEntity {
            let entity = DeskEntity()
            entity.name = name
            entity.description = details
            entity.sortingLanguage = direction
            entity.cards = cards
            entity.date = Date(timeIntervalSinceNow: -age)
            return entity
        }
        let decks = [
            deck("JLPT N5 · Everyday words", "Greetings, food and places", .normal, [
                card("犬", "いぬ", "con chó", image: picture("犬", .systemIndigo)),
                card("猫", "ねこ", "con mèo", note: "Also 猫ちゃん for a pet cat", image: picture("猫", .systemTeal)),
                card("水", "みず", "nước"),
                card("学校", "がっこう", "trường học"),
                card("食べる", "たべる", "ăn", note: "Group 2 verb"),
                card("電車", "でんしゃ", "tàu điện"),
                card("友達", "ともだち", "bạn bè"),
                card("先生", "せんせい", "giáo viên")
            ], age: 3_600),
            deck("Văn phòng", "Words from the office", .normal, [
                card("会議", "かいぎ", "cuộc họp"),
                card("資料", "しりょう", "tài liệu"),
                card("予定", "よてい", "kế hoạch"),
                card("締め切り", "しめきり", "hạn chót", note: "Often used with 〜まで")
            ], age: 90_000),
            deck("Vietnamese to Japanese", "Recall the Japanese word", .opposite, [
                card("xin chào", "", "こんにちは"),
                card("cảm ơn", "", "ありがとう"),
                card("tạm biệt", "", "さようなら")
            ], age: 400_000)
        ]
        decks.forEach { try? DeskManagement.shared.add($0) }
    }

    /// `-FailReviewSaves N`: the first N attempts the study screen saves fail, as if the disk were full, so the unsaved
    /// state and its retry can be inspected and tested on the real UI. Without the argument the real store is used.
    static func reviewHistory() -> ReviewHistoryStoreInterface {
        let failures = UserDefaults.standard.integer(forKey: "FailReviewSaves")
        return failures > 0 ? FlakyReviewHistoryStore(failures: failures) : RealmReviewHistoryStore()
    }
}

private final class FlakyReviewHistoryStore: ReviewHistoryStoreInterface {
    struct DiskFull: LocalizedError { var errorDescription: String? { "The disk is full (debug fixture)." } }
    private let real = RealmReviewHistoryStore()
    private var remainingFailures: Int

    init(failures: Int) { remainingFailures = failures }

    func save(_ attempt: ReviewAttempt, ownerKey: String) throws -> Bool {
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw DiskFull()
        }
        return try real.save(attempt, ownerKey: ownerKey)
    }

    func attempts(ownerKey: String, cardId: String?) -> [ReviewAttempt] { real.attempts(ownerKey: ownerKey, cardId: cardId) }
}
#endif
