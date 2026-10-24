import Foundation
@testable import FlashcardApp

/// A response captured from the running backend (`GET /api/life/lessons/weather?city=tokyo`, 2026-10-24, Open-Meteo free tier).
/// Public data, no secrets. Tests derive variations from it instead of inventing payloads.
enum LifeLessonFixtures {
    static let tokyoJSON = #"""
{
  "schemaVersion": 1,
  "id": "weather:tokyo:2026-10-24",
  "topic": "weather",
  "level": "N4",
  "city": {
    "id": "tokyo",
    "nameJa": "東京",
    "readingJa": "とうきょう",
    "nameEn": "Tokyo",
    "nameVi": "Tokyo"
  },
  "source": {
    "provider": "open-meteo",
    "providerName": "Open-Meteo",
    "url": "https://open-meteo.com/",
    "attributionText": "Weather data by Open-Meteo.com",
    "licenseName": "CC BY 4.0",
    "licenseUrl": "https://creativecommons.org/licenses/by/4.0/",
    "licenseStatus": "non_commercial_dev_only",
    "observedAt": "2026-10-24T08:15:00+09:00",
    "fetchedAt": "2026-10-24T08:28:52.262537+09:00",
    "expiresAt": "2026-10-24T08:58:52.262537+09:00",
    "freshness": "live"
  },
  "facts": {
    "date": "2026-10-24",
    "weatherCode": 61,
    "weatherCodeSystem": "WMO",
    "temperatureMaxC": 15.8,
    "temperatureMinC": 14.1,
    "currentTemperatureC": 14.2,
    "precipitationProbabilityMaxPercent": 80,
    "precipitationSumMm": 22.4
  },
  "lesson": {
    "generatedBy": "deterministic_template",
    "templateVersion": "weather-v1",
    "title": {
      "japanese": "今日の東京の天気",
      "reading": "きょうのとうきょうのてんき",
      "vi": "Thời tiết hôm nay ở Tokyo",
      "en": "Today's weather in Tokyo"
    },
    "sentences": [
      {
        "id": "weather",
        "basis": "fact",
        "japanese": "今日の東京の天気は雨です。",
        "reading": "きょうのとうきょうのてんきはあめです。",
        "translations": {
          "vi": "Hôm nay thời tiết ở Tokyo là mưa.",
          "en": "Today's weather in Tokyo is rain."
        },
        "explanation": {
          "vi": "「A は B です」nghĩa là “A là B”. 天気 là thời tiết.",
          "en": "“A は B です” means “A is B”. 天気 means weather."
        }
      },
      {
        "id": "temperature",
        "basis": "fact",
        "japanese": "最高気温は16度、最低気温は14度です。",
        "reading": "さいこうきおんはじゅうろくど、さいていきおんはじゅうよんどです。",
        "translations": {
          "vi": "Nhiệt độ cao nhất là 16 độ, thấp nhất là 14 độ.",
          "en": "The high is 16 degrees and the low is 14 degrees."
        },
        "explanation": {
          "vi": "最高 là cao nhất, 最低 là thấp nhất, 気温 là nhiệt độ không khí. Số + 度 đọc là “…ど”.",
          "en": "最高 is highest, 最低 is lowest and 気温 is air temperature. A number + 度 is read “…do”."
        }
      },
      {
        "id": "precipitation",
        "basis": "fact",
        "japanese": "降水確率は80パーセントです。",
        "reading": "こうすいかくりつははちじゅっパーセントです。",
        "translations": {
          "vi": "Xác suất có mưa hoặc tuyết là 80%.",
          "en": "The chance of precipitation is 80%."
        },
        "explanation": {
          "vi": "降水確率 là xác suất có mưa hoặc tuyết trong ngày.",
          "en": "降水確率 is the chance of rain or snow during the day."
        }
      },
      {
        "id": "umbrella",
        "basis": "advice",
        "japanese": "傘を持っていきましょう。",
        "reading": "かさをもっていきましょう。",
        "translations": {
          "vi": "Hãy mang theo ô nhé.",
          "en": "Let's take an umbrella."
        },
        "explanation": {
          "vi": "〜ましょう là rủ hoặc đề nghị “hãy cùng…”. 持っていく là mang đi.",
          "en": "〜ましょう suggests “let's …”. 持っていく means to take along."
        }
      }
    ],
    "vocabulary": [
      {
        "id": "weather:rain",
        "japanese": "雨",
        "reading": "あめ",
        "meanings": {
          "vi": "mưa",
          "en": "rain"
        },
        "exampleJapanese": "今日の東京の天気は雨です。"
      },
      {
        "id": "weather:max-temperature",
        "japanese": "最高気温",
        "reading": "さいこうきおん",
        "meanings": {
          "vi": "nhiệt độ cao nhất",
          "en": "highest temperature"
        },
        "exampleJapanese": "最高気温は16度、最低気温は14度です。"
      },
      {
        "id": "weather:min-temperature",
        "japanese": "最低気温",
        "reading": "さいていきおん",
        "meanings": {
          "vi": "nhiệt độ thấp nhất",
          "en": "lowest temperature"
        },
        "exampleJapanese": "最高気温は16度、最低気温は14度です。"
      },
      {
        "id": "weather:precipitation-probability",
        "japanese": "降水確率",
        "reading": "こうすいかくりつ",
        "meanings": {
          "vi": "xác suất có mưa hoặc tuyết",
          "en": "chance of precipitation"
        },
        "exampleJapanese": "降水確率は80パーセントです。"
      },
      {
        "id": "weather:umbrella",
        "japanese": "傘",
        "reading": "かさ",
        "meanings": {
          "vi": "cái ô, cái dù",
          "en": "umbrella"
        },
        "exampleJapanese": "傘を持っていきましょう。"
      }
    ],
    "exercises": [
      {
        "id": "recall-weather",
        "kind": "recall_text",
        "skillType": "recall",
        "promptJapanese": "今日の東京の天気は＿＿です。",
        "prompt": {
          "vi": "Gõ từ tiếng Nhật chỉ “mưa” vào chỗ trống.",
          "en": "Type the Japanese word for “rain” in the blank."
        },
        "acceptedAnswers": [
          "雨",
          "あめ"
        ],
        "explanation": {
          "vi": "Đáp án: 雨 (あめ) — mưa.",
          "en": "Answer: 雨 (あめ) — rain."
        }
      },
      {
        "id": "read-temperature",
        "kind": "choice",
        "skillType": "recognition",
        "promptJapanese": "16度",
        "prompt": {
          "vi": "“16度” đọc là gì?",
          "en": "How do you read “16度”?"
        },
        "choices": [
          {
            "id": "a",
            "text": "じゅうななど"
          },
          {
            "id": "b",
            "text": "じゅうろくど"
          },
          {
            "id": "c",
            "text": "じゅうごど"
          }
        ],
        "correctChoiceId": "b",
        "explanation": {
          "vi": "16度 đọc là じゅうろくど.",
          "en": "16度 is read じゅうろくど."
        }
      }
    ],
    "estimatedMinutes": 2
  }
}
"""#

    static func dto(_ transform: (inout [String: Any]) -> Void = { _ in }) throws -> BJTLifeLessonDTO {
        var object = try XCTUnwrapJSON(tokyoJSON)
        transform(&object)
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(BJTLifeLessonDTO.self, from: data)
    }

    static func XCTUnwrapJSON(_ text: String) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { throw LearnerAPIError.invalidResponse }
        return object
    }

    /// The fixture as a lesson. `fetchedAt` is 2026-10-24 08:28:52 +09:00 and it expires 30 minutes later.
    static func lesson(_ transform: (inout [String: Any]) -> Void = { _ in }) throws -> LifeLesson {
        try LifeLessonInteractor.lesson(from: try dto(transform), requestedCityID: "tokyo")
    }

    /// 2026-10-24 08:30 in Japan.
    static let morning = Date(timeIntervalSince1970: 1_792_798_200)
}
