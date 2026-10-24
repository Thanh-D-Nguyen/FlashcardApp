# Today · Life hub — hợp đồng server và trạng thái triển khai

**Ngày:** 2026-10-24 · **Phía client:** đã triển khai · **Phía server:** đã triển khai local ở commit `7c039cbc`; chưa bật production

Màn Today hiện có *life hub*: tiêu đề ngày, và dải thẻ chủ đề cuộc sống (ngày hôm nay, thời tiết, quanh bạn, tàu điện, mua sắm, tin tức, ẩm thực, mùa & văn hóa, tiền bạc, xổ số). Mỗi thẻ mở cùng một hành trình học (câu chuyện → bài nhớ lại → bài nhận biết → lưu từ → hoàn tất). Client đã gọi endpoint dưới đây và tự thay nội dung mẫu bằng nội dung thật khi nhận feed hợp lệ.

Backend `7c039cbc` đã có `GET /api/life/feed` cho 10 thành phố, ngày/ngày lễ từ Cabinet Office, thời tiết MET Norway (CC BY 4.0) với cache/rate limit, schema + migration PostgreSQL, workflow admin tạo/kiểm duyệt/xuất bản với RBAC + audit log, validator nội dung/thời hạn/nguồn/giấy phép, OpenAPI và tài liệu tích hợp mobile. Báo cáo backend: 1.514 test Go + 490 test frontend, race/build/browser PASS; independent review APPROVE; LIFE-2 CLOSED/VERIFIED.

Trước production còn ba gate: chạy migration, cấu hình `MET_NORWAY_USER_AGENT`, và xuất bản ít nhất một bài đã `reviewed` + xác nhận quyền sử dụng. Cho đến lúc đó feed chủ động trả 404 nên iOS tiếp tục dùng nội dung fallback. Chưa xác minh E2E đầy đủ iOS ↔ backend mới và đăng nhập admin thật; dữ liệu ngày lễ hiện chỉ đến hết 2027.

## 1. Hôm nay mỗi thẻ lấy dữ liệu từ đâu

| Thẻ | Nguồn hiện tại | Nhãn trên thẻ | Trạng thái / việc còn lại |
| --- | --- | --- | --- |
| Ngày hôm nay | Feed server dùng dữ liệu ngày/ngày lễ Cabinet Office; khi feed 404 thì dùng lịch của máy | `LIVE` hoặc `ON THIS DEVICE` | Đã triển khai; dữ liệu ngày lễ hiện đến hết 2027 |
| Thời tiết | Feed server dùng MET Norway, CC BY 4.0, có cache/rate limit; khi feed không có thì client giữ fallback hiện tại | `LIVE` | Đã triển khai; production cần `MET_NORWAY_USER_AGENT` |
| Quanh bạn | **Trên máy**: CoreLocation một lần (khi người dùng bấm) + Apple Maps | `ON THIS DEVICE` | Không bắt buộc. Xem §4 nếu muốn bổ sung |
| Tàu điện, Mua sắm, Tin tức, Ẩm thực, Mùa & văn hóa, Tiền bạc, Xổ số | Bài server đã kiểm duyệt/xác nhận quyền khi có; nếu feed 404 thì dùng bài mẫu trong app | `LIVE` hoặc `SAMPLE` | Workflow biên tập/xuất bản đã triển khai; cần có bài `reviewed` + rights-cleared trước production |

Khi `GET /api/life/feed` trả ≥ 1 thẻ hợp lệ: toàn bộ bài mẫu **biến mất** (không trộn thật và mẫu). Khi trả 404: hỏi lại sau 1 giờ; lỗi khác: hỏi lại sau 60 giây; trong lúc đó vẫn hiện bài mẫu.

## 2. Hợp đồng P0 — `GET /api/life/feed`

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

## 3. Nội dung, nguồn và quyền sử dụng

| Chủ đề | Nguồn | Trạng thái quyền / vận hành |
| --- | --- | --- |
| Ngày/ngày lễ | Cabinet Office | Backend đã tích hợp; dữ liệu hiện chỉ đến hết 2027 |
| Thời tiết | MET Norway | CC BY 4.0; backend đã tích hợp cache/rate limit; production cần cấu hình User-Agent đúng yêu cầu |
| Tàu điện, Tin tức, Mua sắm, Ẩm thực, Mùa & văn hóa | Nội dung biên tập + nguồn theo từng bài | Chỉ bài đã kiểm duyệt, còn hạn và xác nhận quyền sử dụng mới được xuất bản |
| Tiền bạc | Nội dung biên tập; **chỉ giải thích** từ vựng/số liệu được phép dùng | Không khuyến nghị mua/bán; validator publication phải giữ rào chắn nội dung và quyền |
| Xổ số | Nội dung biên tập; **chỉ giải thích** từ vựng/đọc số | Không dự đoán, không liên kết cá cược; validator publication phải giữ rào chắn nội dung và quyền |

Backend đã có schema/migration và trang admin cho bài học, với tạo → kiểm duyệt → xuất bản, RBAC, audit log và validation nội dung/thời hạn/nguồn/giấy phép trước khi publish. Quy tắc client ở §2 vẫn là lớp phòng thủ cuối: feed/thẻ không hợp lệ bị bỏ hoặc từ chối.

## 4. “Quanh bạn”: vì sao nằm trên máy và khi nào cần server

Hiện tại: người dùng bấm “Dùng vị trí của tôi” → hệ thống hỏi quyền (When-In-Use) → app đọc **một** vị trí, đặt tên địa danh bằng tiếng Nhật (CLGeocoder, `ja_JP`) và lấy loại địa điểm quanh đó (MapKit). Chỉ tên và loại địa điểm được giữ trong bộ nhớ; **không lưu và không gửi toạ độ**; không chạy nền; ngoài Nhật Bản thì báo rõ thay vì dạy sai.

Giới hạn cần server mới khắc phục: (a) tên địa điểm cụ thể bằng tiếng Nhật chỉ có khi máy dùng ngôn ngữ cho phép (nên app chỉ dạy *loại* địa điểm); (b) cách đọc tên địa danh (furigana) không có sẵn trên máy; (c) nội dung “lịch sử/địa danh nổi tiếng quanh đây”. Nếu cần, hợp đồng đề xuất: `GET /api/life/places?area=<mã khu vực thô>` — **không nhận toạ độ chính xác** (làm tròn ≥ 1 km hoặc dùng mã quận/huyện do client tự suy ra), người dùng đã đồng ý, không lưu log theo người dùng, trả cùng cấu trúc `lesson` ở trên (`provenance: live`). Cho đến khi có, đừng thêm tham số vị trí vào feed.

## 5. Việc tùy chọn (P1)

1. `level=N5..N1` (hoặc suy từ hồ sơ) để chọn độ khó; hiện bài ghi `level` nhưng app chưa lọc.
2. Số thẻ tối đa 10–12; thứ tự do server quyết (app giữ nguyên thứ tự server, đặt thẻ “Quanh bạn” sau `date` và `weather`).
3. Ghi nhận hoàn thành bài (nếu cần số liệu): `POST /api/life/lessons/{id}/complete` **có khóa idempotency** (app không retry thay đổi dữ liệu khi không có idempotency). Hiện app không gửi gì về server.
4. Thông báo/nhắc học: không làm trong phạm vi này.

## 6. Cách kiểm tra trước production

1. Chạy migration, cấu hình `MET_NORWAY_USER_AGENT`, rồi xuất bản ít nhất một bài đã kiểm duyệt và xác nhận quyền sử dụng.
2. Với response thật: giữ `LifeFeedMapperTests` làm contract test và thêm fixture lấy từ server thật nếu payload thực tế có khác biệt cần khóa lại.
3. Mở app (scheme Local, `PRODUCT_BASE_URL` trỏ server): response 200 hợp lệ phải thay bài mẫu bằng feed, giữ đúng `cityId`, ngôn ngữ chip và mở được lesson; response 404 phải tiếp tục hiển thị fallback.
4. Chạy E2E iOS ↔ backend mới và đăng nhập admin thật trước khi coi integration production là VERIFIED.
