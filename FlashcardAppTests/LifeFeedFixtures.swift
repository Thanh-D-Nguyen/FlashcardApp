import Foundation
@testable import FlashcardApp

/// A server feed as the contract in docs/plans/today-life-hub-server-needs.md describes it. The server does not provide it yet;
/// these fixtures are what the app is tested against so that it works the day the server answers.
enum LifeFeedFixtures {
    static func text(_ vi: String, _ en: String) -> [String: Any] { ["vi": vi, "en": en] }

    static func lesson(id: String, title: String = "今日は祝日です", exercisesValid: Bool = true, url: String? = "https://example.org/source") -> [String: Any] {
        var source: [String: Any] = ["providerName": "Cabinet Office", "licenseStatus": "commercial",
                                     "observedAt": "2026-10-24T06:00:00+09:00", "fetchedAt": "2026-10-24T06:01:00+09:00",
                                     "expiresAt": "2026-10-24T23:59:00+09:00", "freshness": "live"]
        if let url { source["url"] = url; source["attributionText"] = "Source: Cabinet Office" }
        return [
            "id": id, "level": "N4",
            "title": ["japanese": title, "reading": "きょうはしゅくじつです", "vi": "Hôm nay là ngày lễ", "en": "Today is a holiday"],
            "source": source,
            "chips": [["symbol": "calendar", "text": text("Ngày lễ", "Holiday")], ["text": text("Nghỉ", "Day off")]],
            "sentences": [["id": "s1", "basis": "fact", "japanese": "今日は祝日です。", "reading": "きょうはしゅくじつです。",
                           "translations": text("Hôm nay là ngày lễ.", "Today is a public holiday."), "explanation": text("祝日 là ngày lễ.", "祝日 is a public holiday.")]],
            "vocabulary": [["id": "holiday:shukujitsu", "japanese": "祝日", "reading": "しゅくじつ", "meanings": text("ngày lễ", "public holiday"), "exampleJapanese": "今日は祝日です。"]],
            "exercises": exercisesValid ? [
                ["id": "r", "kind": "recall_text", "skillType": "recall", "promptJapanese": "今日は＿＿です。", "prompt": text("Gõ “ngày lễ”.", "Type “public holiday”."),
                 "acceptedAnswers": ["祝日", "しゅくじつ"], "explanation": text("Đáp án: 祝日", "Answer: 祝日")],
                ["id": "c", "kind": "choice", "skillType": "recognition", "promptJapanese": "祝日", "prompt": text("Đọc là gì?", "How is it read?"),
                 "choices": [["id": "a", "text": "しゅくじつ"], ["id": "b", "text": "しゅくひ"]], "correctChoiceId": "a", "explanation": text("しゅくじつ", "しゅくじつ")]
            ] : [],
            "estimatedMinutes": 2
        ]
    }

    static func card(id: String, topic: String, provenance: String = "live", scene: [String: Any]? = nil, lesson: [String: Any]? = nil) -> [String: Any] {
        ["id": id, "topic": topic, "provenance": provenance, "summary": text("Tóm tắt", "Summary"), "meta": text("Nguồn", "Source"),
         "scene": scene ?? ["kind": topic == "weather" ? "weather" : "date", "weatherCode": 61, "temperatureC": 15.8, "day": 24, "weekday": "土"],
         "lesson": lesson ?? Self.lesson(id: id)]
    }

    static func feed(cityId: String = "tokyo", schemaVersion: Int = 1, cards: [[String: Any]]) -> [String: Any] {
        ["schemaVersion": schemaVersion, "generatedAt": "2026-10-24T06:02:00+09:00", "cityId": cityId, "cards": cards]
    }

    static func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    static func dto(_ object: [String: Any]) throws -> BJTLifeFeedDTO { try JSONDecoder().decode(BJTLifeFeedDTO.self, from: try data(object)) }

    /// The cards of a normal feed: today's date (with the holiday), the weather, the trains, and a topic this app version does not know.
    static var typical: [String: Any] {
        feed(cards: [
            card(id: "date:2026-10-24", topic: "date"),
            card(id: "weather:tokyo:2026-10-24", topic: "weather", scene: ["kind": "weather", "weatherCode": 61, "temperatureC": 15.8], lesson: lesson(id: "weather:tokyo:2026-10-24", title: "今日の東京の天気")),
            card(id: "transit:1", topic: "transit", scene: ["kind": "transit"], lesson: lesson(id: "transit:1", title: "電車が遅れています")),
            card(id: "sports:1", topic: "sports", scene: ["kind": "transit"])
        ])
    }
}
