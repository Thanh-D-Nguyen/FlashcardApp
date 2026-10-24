# Today · Life hub — những gì server cần bổ sung

**Ngày:** 2026-10-24 · **Phía client:** đã xong và đã kiểm thử · **Phía server:** chưa có (mục này là danh sách việc)

Màn Today hiện có *life hub*: tiêu đề ngày, và dải thẻ chủ đề cuộc sống (ngày hôm nay, thời tiết, quanh bạn, tàu điện, mua sắm, tin tức, ẩm thực, mùa & văn hóa, tiền bạc, xổ số). Mỗi thẻ mở cùng một hành trình học (câu chuyện → bài nhớ lại → bài nhận biết → lưu từ → hoàn tất). Client **không cần sửa gì** khi server sẵn sàng: nó đã gọi endpoint dưới đây và tự thay nội dung mẫu bằng nội dung thật.

## 1. Hôm nay mỗi thẻ lấy dữ liệu từ đâu

| Thẻ | Nguồn hiện tại | Nhãn trên thẻ | Việc server cần làm |
| --- | --- | --- | --- |
| Ngày hôm nay | Lịch của máy (ngày, thứ, năm Reiwa, mùa, lời chào — chính xác, tính tại chỗ) | `ON THIS DEVICE` | Trả thẻ `date` có **ngày lễ, 今日は何の日, lịch sự kiện** (client dùng thẻ của server thay thẻ tính tại máy) |
| Thời tiết | `GET /api/life/lessons/weather` (đã có, Open-Meteo, **giấy phép thương mại chưa giải quyết**) | `LIVE` | Đưa vào feed; chuyển nguồn sang nơi có quyền thương mại |
| Quanh bạn | **Trên máy**: CoreLocation một lần (khi người dùng bấm) + Apple Maps | `ON THIS DEVICE` | Không bắt buộc. Xem §4 nếu muốn bổ sung |
| Tàu điện, Mua sắm, Tin tức, Ẩm thực, Mùa & văn hóa, Tiền bạc, Xổ số | Bài **mẫu viết tay** trong app | `SAMPLE` + “Example content · not live data yet” | Cung cấp bài thật qua feed (§2) |

Khi `GET /api/life/feed` trả ≥ 1 thẻ hợp lệ: toàn bộ bài mẫu **biến mất** (không trộn thật và mẫu). Khi trả 404: hỏi lại sau 1 giờ; lỗi khác: hỏi lại sau 60 giây; trong lúc đó vẫn hiện bài mẫu.

## 2. Việc ưu tiên P0 — `GET /api/life/feed`

Công khai, không cần phiên, giới hạn tốc độ như các route public khác. Query: `city=<id>` (một trong `tokyo, yokohama, osaka, nagoya, kyoto, sapporo, sendai, hiroshima, fukuoka, naha`; id khác → 400). Client gọi **tối đa một lần/ngày/thành phố** khi còn hiệu lực.

Phản hồi 200 (ví dụ rút gọn; client kiểm bằng `LifeFeedFixtures.typical` và `LifeFeedMapperTests`):

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-10-24T06:02:00+09:00",
  "cityId": "tokyo",
  "cards": [
    {
      "id": "date:2026-10-24",
      "topic": "date",
      "provenance": "live",
      "summary": { "vi": "Hôm nay là ngày lễ.", "en": "Today is a public holiday." },
      "meta": { "vi": "Cabinet Office", "en": "Cabinet Office" },
      "scene": { "kind": "date", "day": 24, "weekday": "土" },
      "lesson": {
        "id": "date:2026-10-24",
        "level": "N4",
        "title": { "japanese": "今日は祝日です", "reading": "きょうはしゅくじつです", "vi": "Hôm nay là ngày lễ", "en": "Today is a holiday" },
        "source": {
          "providerName": "Cabinet Office", "url": "https://…", "attributionText": "Source: …", "licenseStatus": "commercial",
          "observedAt": "2026-10-24T06:00:00+09:00", "fetchedAt": "2026-10-24T06:01:00+09:00", "expiresAt": "2026-10-24T23:59:00+09:00", "freshness": "live"
        },
        "chips": [ { "symbol": "calendar", "text": { "vi": "Ngày lễ", "en": "Holiday" } } ],
        "sentences": [ { "id": "s1", "basis": "fact", "japanese": "今日は祝日です。", "reading": "きょうはしゅくじつです。",
                         "translations": { "vi": "…", "en": "…" }, "explanation": { "vi": "…", "en": "…" } } ],
        "vocabulary": [ { "id": "holiday:shukujitsu", "japanese": "祝日", "reading": "しゅくじつ", "meanings": { "vi": "ngày lễ", "en": "public holiday" }, "exampleJapanese": "今日は祝日です。" } ],
        "exercises": [
          { "id": "r", "kind": "recall_text", "skillType": "recall", "promptJapanese": "今日は＿＿です。", "prompt": { "vi": "…", "en": "…" },
            "acceptedAnswers": ["祝日", "しゅくじつ"], "explanation": { "vi": "…", "en": "…" } },
          { "id": "c", "kind": "choice", "skillType": "recognition", "promptJapanese": "祝日", "prompt": { "vi": "…", "en": "…" },
            "choices": [ { "id": "a", "text": "しゅくじつ" }, { "id": "b", "text": "しゅくひ" } ], "correctChoiceId": "a", "explanation": { "vi": "…", "en": "…" } }
        ],
        "estimatedMinutes": 2
      }
    }
  ]
}
```

Quy tắc hợp đồng (client **bỏ** thẻ vi phạm, và **từ chối cả feed** nếu sai schema/thành phố hoặc không còn thẻ nào dùng được):
- `schemaVersion = 1`; `cityId` phải đúng thành phố được hỏi; `cards[].id` duy nhất.
- `topic` ∈ `date, weather, nearby, transit, shopping, news, food, culture, money, lottery`. **Topic lạ bị bỏ qua** (thêm topic mới không cần cập nhật app). `nearby` từ server **bị bỏ qua** (xem §4).
- `provenance` ∈ `live | sample` (không có `onDevice`). Nội dung mẫu phải ghi `sample`; app sẽ gắn nhãn SAMPLE.
- `scene.kind` ∈ `weather` (cần `weatherCode` WMO, tùy chọn `temperatureC`), `date` (cần `day` 1–31, `weekday` một chữ Hán), `place, transit, shopping, news, food, culture, money, lottery`.
- `lesson.source.url` nếu có phải là **https**. `attributionText` hiển thị nguyên văn (giấy phép nguồn thường yêu cầu). `licenseStatus` ∈ `commercial | non_commercial_dev_only | not_applicable`; bản phát hành không được có `non_commercial_dev_only`.
- Mỗi bài: ≥ 1 câu, ≥ 1 từ, ≥ 1 bài tập; `recall_text` có `acceptedAnswers` không rỗng và **prompt không chứa đáp án**; `choice` có ≥ 2 lựa chọn duy nhất và `correctChoiceId` thuộc danh sách. Chấm bài chạy trên máy, server không nhận đáp án.
- `sentences[].basis`: `fact` (nhắc lại dữ kiện nguồn) hoặc `advice` (gợi ý của mẫu, không phải dữ kiện) — app gắn nhãn “Tip” cho `advice`. **Dữ kiện nguồn và lời giải thích do mẫu/biên tập tạo phải tách bạch.**
- `vocabulary[].id` ổn định và duy nhất (dùng làm khóa chống trùng khi người học lưu thẻ: `life:<bộ thẻ>:<id>`).
- Văn bản song ngữ `vi` + `en` bắt buộc (giao diện tiếng Nhật hiển thị `en`).
- Thời gian RFC 3339 có múi giờ (client chấp nhận có/không có phần giây lẻ). `expiresAt` không quá nửa đêm giờ Nhật.
- Header: `Cache-Control: public, max-age=60` (ngắn hơn nếu sát nửa đêm JST, `no-store` khi dữ liệu `stale`) như route thời tiết; `404` nếu chưa bật tính năng (không trả feed rỗng giả).

## 3. Nội dung và nguồn (blocker pháp lý nằm ở đây, không phải ở app)

| Chủ đề | Gợi ý nguồn | Tình trạng quyền (đã kiểm / chưa kiểm) |
| --- | --- | --- |
| Ngày/ngày lễ | CSV ngày lễ của Cabinet Office; “今日は何の日” cần bộ dữ liệu biên tập riêng | CSV có tới 2027; điều khoản và mã hóa **chưa xác nhận**; bản `date` của server nên thay thế thẻ tính tại máy chứ không bắt buộc |
| Thời tiết | Open-Meteo (đang dùng) hoặc JMA | Gói miễn phí **phi thương mại**; JMA JSON không được tài liệu hóa; xem [weather slice §3, §9](today-life-learning-weather-slice.md) |
| Tàu điện | ODPT hoặc thông báo biên tập (không cào trang công ty) | ODPT: **chưa đọc được điều khoản** |
| Tin tức | Tóm tắt tự biên soạn + liên kết nguồn; không sao chép/dịch NHK | Quyền NHK **chưa xác nhận** (không mặc nhiên cho phép) |
| Mua sắm, Ẩm thực, Mùa & văn hóa | Biên tập (lịch mùa/lễ hội tính theo ngày, thực đơn mùa) | Tự sở hữu nội dung |
| Tiền bạc | **Chỉ giải thích**: từ vựng, cách đọc số liệu đã công bố. Không tỷ giá trực tiếp trừ khi có giấy phép | J-Quants: **chưa xác nhận** được phép hiển thị lại; tuyệt đối không khuyến nghị mua/bán |
| Xổ số | **Chỉ giải thích**: từ vựng, đọc số. Không dự đoán, không liên kết cá cược | Dữ liệu kết quả: nguồn và quyền **chưa xác nhận** |

Cần một công cụ biên tập (admin) cho bài học: bảng `life_lesson` (hoặc mở rộng Daily Radar) với `topic, city, valid_from/valid_until, status (draft|reviewed|published), rights_status (unknown|cleared|blocked), reviewer, source_url`; chỉ `published` + `cleared` + còn hạn mới vào feed; người biên tập tiếng Nhật xác nhận cách đọc. Validator tự động chạy cùng quy tắc ở §2 (đáp án không nằm trong prompt, lựa chọn duy nhất, `https`) và **chặn từ khóa** cho `money`/`lottery` (khuyến nghị, dự đoán, liên kết cá cược).

## 4. “Quanh bạn”: vì sao nằm trên máy và khi nào cần server

Hiện tại: người dùng bấm “Dùng vị trí của tôi” → hệ thống hỏi quyền (When-In-Use) → app đọc **một** vị trí, đặt tên địa danh bằng tiếng Nhật (CLGeocoder, `ja_JP`) và lấy loại địa điểm quanh đó (MapKit). Chỉ tên và loại địa điểm được giữ trong bộ nhớ; **không lưu và không gửi toạ độ**; không chạy nền; ngoài Nhật Bản thì báo rõ thay vì dạy sai.

Giới hạn cần server mới khắc phục: (a) tên địa điểm cụ thể bằng tiếng Nhật chỉ có khi máy dùng ngôn ngữ cho phép (nên app chỉ dạy *loại* địa điểm); (b) cách đọc tên địa danh (furigana) không có sẵn trên máy; (c) nội dung “lịch sử/địa danh nổi tiếng quanh đây”. Nếu cần, hợp đồng đề xuất: `GET /api/life/places?area=<mã khu vực thô>` — **không nhận toạ độ chính xác** (làm tròn ≥ 1 km hoặc dùng mã quận/huyện do client tự suy ra), người dùng đã đồng ý, không lưu log theo người dùng, trả cùng cấu trúc `lesson` ở trên (`provenance: live`). Cho đến khi có, đừng thêm tham số vị trí vào feed.

## 5. Việc tùy chọn (P1)

1. `level=N5..N1` (hoặc suy từ hồ sơ) để chọn độ khó; hiện bài ghi `level` nhưng app chưa lọc.
2. Số thẻ tối đa 10–12; thứ tự do server quyết (app giữ nguyên thứ tự server, đặt thẻ “Quanh bạn” sau `date` và `weather`).
3. Ghi nhận hoàn thành bài (nếu cần số liệu): `POST /api/life/lessons/{id}/complete` **có khóa idempotency** (app không retry thay đổi dữ liệu khi không có idempotency). Hiện app không gửi gì về server.
4. Thông báo/nhắc học: không làm trong phạm vi này.

## 6. Cách kiểm tra khi server xong

1. Chạy `pnpm quality` backend cho route mới và thêm vào `docs/openapi.json` (schema `LifeFeed`, tái sử dụng `LifeText`).
2. Với response thật: `LifeFeedMapperTests` là hợp đồng — thêm một fixture lấy từ server thật (ẩn dữ liệu nhạy cảm) và chạy.
3. Mở app (scheme Local, `PRODUCT_BASE_URL` trỏ server): các thẻ mẫu biến mất, nhãn `SAMPLE` không còn, thẻ ngày hiện nhãn `LIVE`. Nếu vẫn thấy `SAMPLE`: kiểm tra `404`, `cityId`, `schemaVersion`, hoặc thẻ bị bỏ do vi phạm quy tắc §2.
