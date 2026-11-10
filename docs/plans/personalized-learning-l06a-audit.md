# L06a — Audit sẵn sàng cho bài tình huống (API, nội dung, kiến trúc, UX)

Ngày: 2026-10-23. Phạm vi: chỉ đọc/xác minh và tài liệu; **không có mã L06 nào được viết**. Kế hoạch tổng:
[personalized-learning.md](personalized-learning.md) (mục L06). Đặc tả UX nền: [personalized-learning-ux.md](personalized-learning-ux.md) S05/W04.

Mức xác minh dùng trong tài liệu: `SOURCE` (đọc mã), `TEST` (test tự động đã chạy), `RUNTIME` (gọi backend local thật),
`UNVERIFIED`, `BLOCKED`.

## A. Quyết định

**`L06b_CONDITIONALLY_READY` — chỉ cho một lát cắt kỹ thuật dọc, chỉ văn bản.** Hợp đồng API, xác thực, CSRF và chiến lược
retry đã được xác minh đủ để dựng một vòng chơi hoàn chỉnh trên đúng một tình huống đang có. **Chấp nhận sản phẩm L06**
(nghe trước khi hiện lời thoại, tình huống sinh hoạt, quyền dùng nội dung) **vẫn `BLOCKED` bởi nội dung/âm thanh/bản quyền**,
không phải bởi kỹ thuật.

Căn cứ:
- 5 endpoint scenario có thật, đã gọi runtime và có test HTTP (mục B). Không cần đổi backend để bắt đầu.
- Backend local có **1** tình huống chơi được (`email-late-meeting`, 3 bước, email công sở, chỉ vi/ja, không audio).
  2 tình huống còn lại có 0 bước nên không được phục vụ (mục C).
- Không có audio gắn với tình huống, không có thông tin tác giả/giấy phép, không có công cụ soạn nội dung (mục C, D).
- Điều kiện vào L06 trong kế hoạch ("audio, nguồn/quyền dùng, đáp án được người có chuyên môn duyệt") **chưa đạt**.

Lát cắt kỹ thuật được phép làm trong bản dev; **không phát hành cho người học** và không mô tả là bài nghe cho đến khi
các cổng nội dung ở mục H được đóng.

## B. Ma trận hợp đồng API

Cơ sở: `apps/api-go/internal/httpserver/server.go:1707-1721` (đăng ký route), `handler_scenario.go`,
`internal/scenario/store.go`. Nguồn chuẩn: `nihongo-bjt/docs/openapi.json` (đã cập nhật, xem mục E). Tất cả route yêu cầu
phiên học viên (Bearer hoặc cookie `bjt_web_session`); route ghi thêm `CSRFGuard` (Origin/Referer phải nằm trong
`CORS_ORIGINS`). Chỉ đăng ký khi `ScenarioStore` và `SessionStore` khác nil.

| Method | Path | Auth | Request | Response 200 | Lỗi đã thấy | Ghi dữ liệu | Mức |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/api/scenarios` | Bearer | — | mảng `ScenarioSummary` (`id, slug, titleVi, titleJa?, descriptionVi?, difficulty, category, iconEmoji, estimatedMin, _count{steps,attempts}`); chỉ tình huống active, ≥1 bước, mọi bước có lựa chọn | 401 | không | SOURCE+TEST+RUNTIME |
| GET | `/api/scenarios/{scenarioId}` | Bearer | — | `ScenarioDetail` + `steps[]` (`id, stepOrder, situationVi, situationJa?, speakerName?, speakerRole?, choices[]{id, choiceKey, textVi, textJa?}`); **không** có đáp án/điểm/phản hồi | 401, 404 (không có/không chơi được), 500 (id không phải UUID) | không | SOURCE+TEST+RUNTIME |
| POST | `/api/scenarios/steps/{stepId}/answer` | Bearer + Origin | `{choiceKey}` hoặc `{choiceId}` (`choiceKey` ưu tiên; giá trị khớp `choice_key` **hoặc** id) | `{choiceKey, isOptimal, pointsAwarded, feedbackVi?}` | 400 (rỗng/JSON hỏng), 401, 403 (thiếu/không tin cậy Origin), 404 (không có lựa chọn), 500 (stepId hỏng) | **không** (không lưu gì) | SOURCE+TEST+RUNTIME |
| POST | `/api/scenarios/{scenarioId}/complete` | Bearer + Origin | `{choices:[{stepId,choiceId}\|{stepOrder,choiceKey}]}`, đúng một mục mỗi bước; `points` do client gửi bị **bỏ qua** | `{id, totalPoints, maxPoints}` (server tự tính) | 400 (sai số lượng/trùng bước/lựa chọn lạ), 401, 403, 404 | **có**: một dòng `user_scenario_attempt` mỗi lần gọi thành công | SOURCE+TEST+RUNTIME |
| GET | `/api/scenarios/{scenarioId}/attempts` | Bearer | — | mảng `{id,totalPoints,maxPoints,choices,completedAt}` mới nhất trước; **chỉ của người gọi** | 401; lỗi DB bị nuốt thành `200 []` | không | SOURCE+TEST+RUNTIME |

Bằng chứng:
- TEST: `go test ./internal/scenario/...` (3 PASS, DB tạm `with-test-db.sh`) và **test mới**
  `TestScenarioLearnerHTTPContract` (`internal/httpserver/handler_scenario_test.go`, 6 nhóm con PASS) đi qua `NewRouter`.
- RUNTIME: tài khoản dùng một lần trên DB local, Bearer + `Origin: http://localhost:18081`, gọi đủ cả 5 route và các nhánh lỗi
  ở bảng trên (kết quả khớp test). Tài khoản chỉ nằm trong DB local; không có token/mật khẩu nào được ghi vào tài liệu.
- `x-contract-verification` của 5 operation trong OpenAPI giờ là `test-evidenced` (cùng mức với `/api/auth/*`, `/api/levels`,
  `/api/search`). Đây **không** là "verified" đầy đủ: không kiểm cạn từng trường/status.

Hành vi quan trọng cho client:
1. **`answer` không lưu và lặp lại an toàn** — nhưng cũng là nơi duy nhất lộ đáp án; client gọi sau khi người học chọn.
2. **`complete` không idempotent**: không có khóa idempotency, không ràng buộc duy nhất (user, scenario); hai lần gửi cùng nội dung
   tạo hai attempt (RUNTIME: 3 lần gọi → 3 dòng; TEST khẳng định 2). Retry mù sẽ nhân đôi lịch sử.
3. **Điểm do server tính**; điểm không tối ưu có giá trị khác nhau (ví dụ 3, 5), nên `totalPoints/maxPoints` không phải thước đo
   "độ lưu loát". Hiển thị số lựa chọn tốt (`isOptimal`) thay vì phần trăm điểm.
4. `attempts[].choices` là **chuỗi base64** của mảng JSON `[{"stepOrder":1,"choiceKey":"A"},…]` (trường Go `[]byte`).
   Client phải giải base64 rồi parse. Nếu backend sửa sang `json.RawMessage` thì kiểu đổi thành mảng — decode phải chấp nhận cả hai
   hoặc ghim bằng test hợp đồng.
5. `_count.attempts` tính **mọi** người học, không chỉ người gọi; đừng hiển thị như tiến độ cá nhân.
6. Chuỗi thiếu ở API: phản hồi chỉ có `feedbackVi`; không có `en`. Không có trường audio/giấy phép/tác giả.
7. ID là UUID chuỗi; giữ nguyên. Id sai định dạng cho 500 (detail/answer) hoặc `200 []` (attempts) — client chỉ dùng id lấy từ list/detail.

## C. Ma trận sẵn sàng nội dung

Nguồn dữ liệu: bảng `content.business_scenario/scenario_step/scenario_choice` của DB local, gieo bởi migration
`packages/database/prisma/migrations/20260515153000_business_scenario/migration.sql` (RUNTIME + SOURCE). Không thấy API/UI quản trị để
soạn tình huống (chỉ SQL/migration) — nội dung hiện **không có đường soạn và duyệt**.

| Tình huống | Loại | Độ khó | Tiếng Nhật | Dịch | Audio | Quyền | Phân loại |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `email-late-meeting` — Email xin lỗi đến muộn họp (3 bước × 3 lựa chọn, ~3 phút, 2 attempt cũ trong DB local) | email công sở | beginner | có (`situationJa`, `textJa`); không furigana/reading | vi đầy đủ; **en: không có**; phản hồi chỉ vi | không | **UNVERIFIED** (không có tác giả/giấy phép) | `NEEDS_CONTENT_REVIEW` + `NEEDS_TRANSLATION` + `MISSING_AUDIO` |
| `phone-complaint` — Xử lý khiếu nại qua điện thoại | cuộc gọi công sở | intermediate | chỉ tiêu đề | vi | không | UNVERIFIED | `INCOMPLETE` (0 bước; API không phục vụ) |
| `meeting-proposal` — Trình bày đề xuất trong họp | họp | advanced | chỉ tiêu đề | vi | không | UNVERIFIED | `INCOMPLETE` (0 bước; API không phục vụ) |

Phát hiện nội dung của tình huống duy nhất chơi được (cần chuyên gia, **không tự sửa bằng AI**):
- Đây là **luyện đọc/viết email**, không phải nghe-hiểu hay hội thoại sinh hoạt; không đáp ứng "nghe trước khi hiện lời thoại".
- `speakerName/Role` đều là "Hệ thống/Narrator" — không có người nói thật để gắn audio.
- `textVi` của lựa chọn trộn tiếng Nhật + chú thích Việt trong ngoặc, trùng với `textJa`: cần tách để hiển thị ja chính + nghĩa.
- Bước 2 mở đầu "Tốt lắm!" bất kể người học đã chọn gì ở bước 1.
- Điểm một phần không tối ưu không nhất quán (bước 1: B=3, C=5 dù B "quá chung chung", C "không thể hiện xin lỗi").
- Các nhận định keigo (ví dụ 殿 ít dùng, 様 đúng) cần người có chuyên môn duyệt trước khi trình bày như quy tắc.
- Chưa có tình huống sinh hoạt (cửa hàng tiện lợi, nhà ga, bệnh viện…): các chủ đề đó trong đề bài chỉ là ứng viên.

**Tình huống đề xuất cho lát cắt đầu: `email-late-meeting`** — duy nhất có cấu trúc đầy đủ — **chỉ để chứng minh luồng kỹ thuật**.
Giả thuyết sản phẩm (người N4–N3 đi làm ở Nhật) khiến chủ đề công sở có thể liên quan, nhưng cần chủ sản phẩm xác nhận (mục H).

## D. Âm thanh và bản quyền

- Backend: **không** có trường audio cho tình huống/bước (RUNTIME: không cột audio trong `scenario_*`). Có bảng
  `content.lexeme_audio` / `content.example_sentence_audio` (cột `media_asset_id`, `tts_provider`, `voice_name`, `voice_actor`,
  `duration_ms`) nhưng **0 dòng** và không liên kết tới tình huống. `nhk_article.audio_url` thuộc tính năng tin tức, không liên quan.
- iOS: `SystemSpeechService` (nằm trong `FlashcardApp/Services/SpeechService.swift`; **không** có file `SystemSpeechService.swift` như đề bài
  nhắc) dùng `AVSpeechSynthesizer` `ja-JP`/`vi-VN`, phát theo yêu cầu, tự tắt phiên audio, lỗi giọng chỉ bỏ qua âm thanh.
  Chưa kiểm giọng `ja-JP` nào có sẵn trên máy người dùng (UNVERIFIED).
- Giấy phép/tác giả: **không có metadata** (migration gieo nội dung, không ghi tác giả). Quyền dùng, phân phối, thương mại: `UNVERIFIED`.
  Không tải bản ghi bên ngoài.

Khuyến nghị cho L06b (đơn giản nhất, hợp pháp và đúng giáo dục):
1. **Văn bản + "Nghe đọc" bằng giọng hệ thống làm hỗ trợ**, ghi rõ là giọng tổng hợp. Nút nghe là gợi ý đọc, **không** được tính là bằng chứng
   nghe-hiểu hay phát âm tự nhiên (nhất quán `personalized-learning-ux.md` S05).
2. **Bản ghi người bản ngữ** (chuẩn cho L06 sau này) cần: quyết định nguồn (thuê thu âm/giấy phép), mô hình dữ liệu audio theo bước
   (backend), CDN/`media.asset`, điều khoản. Đây là việc backend + nội dung, không làm trong L06a/L06b.

## E. Hợp đồng chuẩn (OpenAPI)

Đã cập nhật **trong repo backend** (chủ sở hữu hợp đồng chuẩn), không có bản hợp đồng thứ hai ở iOS:
- `docs/openapi.json`: 5 operation có `security`, tham số, `requestBody`, `responses`, schema `Scenario*` (11 schema), `x-ios`
  (idempotency/Origin), `x-runtime-verification` và `x-known-issues`. Không đổi route nào khác.
- `docs/api-route-inventory.json`: sinh lại (5 contract → `test-evidenced`, tổng 12).
- `apps/api-go/cmd/route-contract/main.go`: đăng ký 5 operation vào `verifiedOperations` (bắt buộc để bộ sinh giữ mức `test-evidenced`).
- `apps/api-go/internal/httpserver/handler_scenario_test.go`: test hợp đồng HTTP mới (cần `TEST_DATABASE_URL`).
- Lệnh đã chạy: `go run ./cmd/route-contract -root ../.. -check` OK; `jq empty docs/openapi.json` OK;
  `go test ./internal/httpserver -run 'TestOpenAPIHasEverySourceRegisteredAPIRoute|TestIOSOpenAPIContract'` OK;
  `go test ./internal/routecontract ./cmd/...` OK; `go vet` sạch; test mới + `./internal/scenario` PASS qua `scripts/quality/with-test-db.sh`.
- Chưa commit (không có ủy quyền). Các sửa đổi không liên quan sẵn có trong repo backend (`.claude/settings.local.json`,
  `next-env.d.ts`, `tsconfig.tsbuildinfo`) không bị chạm.

Khoảng trống schema còn lại: giá trị hợp lệ của `difficulty`/`category` (cột chuỗi tự do), phản hồi khi DB lỗi giữa chừng, thứ tự `choices`
ngoài `choice_key ASC`, tải khi danh sách lớn (không phân trang; hiện 1 dòng). Test không phủ rate limit (không thấy middleware giới hạn
trên nhóm route này — `SOURCE`, chưa thử).

## F. Xác thực, CSRF và lưu tiến độ

- Đăng nhập native: `POST /api/auth/login` → token mờ (không phải JWT), **TTL cố định 24 giờ** (`handler_login.go:28`), **không** có route
  refresh/rotate (`RotateLearnerSession` tồn tại nhưng không có caller trong handler — SOURCE). Hết hạn → 401 → đăng nhập lại.
- iOS đã đúng cơ chế: `BJTLearnerAPI.perform` đọc token từ Keychain qua `AuthSession.shared.bearerToken`, gửi `Origin` = origin của chính API
  và bỏ kết quả nếu token đổi trong lúc chạy (`staleSession`). **Không cần giả Origin hay bypass CSRF.** Điều kiện triển khai: origin của API phải
  nằm trong `CORS_ORIGINS` (local: có `http://localhost:18081`; **production chưa cấp** — theo AGENTS.md). Thiếu → 403 `forbidden: …` →
  `LearnerAPIError.originRejected` (đã có).
- Lỗi đã phân loại sẵn: `offline` = chưa tới server (an toàn thử lại), `interrupted` = không biết server có xử lý hay chưa,
  `signInRequired`, `originRejected`, `notFound`, `rateLimited`, `serviceUnavailable`, `server(n)`.
- Tiến độ là **chỉ trên server (remote only)**. iOS chưa có model Realm cho tình huống và L06b không cần thêm (không đổi schema 6).
- Khác nhau giữa "trả lời đúng" và "đã lưu": `answer` chỉ cho phản hồi; **chỉ `complete` lưu**. Do đó "đã hoàn thành" chỉ được hiển thị sau khi
  `complete` trả 200.

Chiến lược mạng/kết quả không chắc chắn cho `complete` (đề xuất, chưa cài):
1. Bắt đầu tình huống: gọi `GET …/attempts` lấy `n0` (số attempt) — đồng thời cho "kết quả trước đó".
2. Giữ các lựa chọn trong bộ nhớ (một phiên ~3 phút; kill app giữa chừng thì làm lại — chấp nhận ở L06b).
3. Gửi `complete` một lần. `200` → xong. `offline`/`403`/`400` (chưa tới nơi hoặc bị từ chối) → hiện Thử lại, an toàn.
   `interrupted`/`5xx`/timeout → **không gửi lại ngay**: gọi `GET …/attempts`; nếu có attempt mới (số lượng > `n0` **và** `choices` giải mã trùng
   lựa chọn vừa gửi) thì coi là đã lưu; ngược lại mới cho Thử lại. So sánh theo số lượng + nội dung, không theo giờ (lệch đồng hồ).
4. `401` → giữ lựa chọn trong bộ nhớ, yêu cầu đăng nhập lại, rồi cho gửi tiếp; đăng xuất/đổi tài khoản → bỏ (`staleSession`).
5. Hủy khi rời màn: hủy request đang chờ (Rx dispose) nhưng nếu đã gửi thì không coi như chưa lưu — màn kế tiếp đọc lại attempts.
Giới hạn chấp nhận: hai thiết bị cùng hoàn thành cùng lúc có thể làm bước 3 nhầm; hiếm, ghi nhận.

## G. Kiến trúc iOS đề xuất cho L06b (nhỏ nhất)

Tái dùng (không đổi): `BJTLearnerAPI` (transport, Origin, bearer, stale-session, ánh xạ lỗi — hiện `perform` là `private`, mở rộng cùng file hoặc
nới thành `fileprivate`/internal), `AuthSession`, `LearnerAPIError`, `StateView`, `Design.*`/`TextRole`, `StudyHaptics`, `SystemSpeechService`,
`LocalizationTests`, mẫu `TodayWireframe` (đẩy màn từ hàng "Cấp độ").

Thêm (cần thật sự):
| Thành phần | Trách nhiệm |
| --- | --- |
| `Networks/BJTClient/Models/BJTScenarioDTO.swift` | DTO giá trị: summary, detail/step/choice, answer result, complete request/result, attempt (giải base64 `choices`, chấp nhận cả mảng) |
| mở rộng `BJTLearnerAPI` + protocol `BJTScenarioAPIInterface` (riêng, để không đổi mock deck) | `scenarios()`, `scenario(id:)`, `answer(stepID:choiceID:)`, `complete(scenarioID:choices:)`, `attempts(scenarioID:)`; chỉ nhận UUID hợp lệ làm đoạn đường dẫn |
| `Entities/ScenarioSession.swift` | máy trạng thái thuần: bước hiện tại, lựa chọn, phản hồi đã nhận, chặn trả lời đôi, dựng payload `complete` đúng một mục mỗi bước, theo thứ tự |
| `Interactors/ScenarioInteractor.swift` | thư viện, chi tiết, `answer`, `complete` + quy tắc không chắc chắn ở mục F |
| `Modules/Scenario…` (Library, Play) + `ScenarioWireframe` | Presenter/ViewController/Wireframe theo VIPER; điều hướng trong wireframe |
| `Resources/Localizable.xcstrings` | chuỗi UI vi/en/ja (nội dung server giữ nguyên ngôn ngữ nguồn) |

Điểm vào: hàng "Tình huống" trên Today cạnh "Cấp độ" (id `today_scenarios_row`) — không thêm tab (giữ bốn tab).
**Không** thêm: engine tổng quát, lớp cache, model Realm, thư viện mạng, khóa idempotency giả, header Origin tự chế.

Rủi ro tích hợp chính: (1) người dùng khách chưa đăng nhập — toàn bộ route 401, cần trạng thái "Đăng nhập để luyện tình huống" dẫn tới màn đăng nhập
hiện có; (2) hết hạn phiên 24 giờ giữa bài; (3) `choices` base64 có thể đổi kiểu; (4) CORS production chưa cấp; (5) `perform` private.

## H. Đặc tả UX năm màn hình

Đã áp dụng các skill thiết kế đã cài (ghi trung thực phạm vi):
- **UI UX Pro Max** (`.claude/skills/ui-ux-pro-max`): đã đọc `SKILL.md`; công cụ `search.py` sinh design system **web**, nên **không chạy**; áp dụng
  checklist: tương phản ≥ 4.5:1, vùng chạm ≥ 44 pt, trạng thái tải không làm nhảy bố cục, motion 150–300 ms và tôn trọng Reduce Motion,
  không dùng emoji làm icon (**backend trả `iconEmoji` — không dùng làm icon điều hướng; dùng SF Symbol theo `category`, emoji chỉ là chữ trang trí hoặc bỏ**).
- **Apple Skill** (`apple-skills:design`): đã đọc chỉ mục. Các skill con (ux-writing, typography, sf-symbols, game-feel) **chưa mở**; quy tắc rút ra ở
  mức chỉ mục: dùng API/kiểu chữ hệ thống, Dynamic Type, phản hồi qua đúng kênh, không "juice" thừa.
- **Liquid Glass** (`liquid-glass:liquid-glass`): skill chỉ phủ **SwiftUI**, loại trừ UIKit; chỉ áp dụng quy tắc thiết kế: kính chỉ ở lớp chức năng (thanh
  điều hướng, tab bar, sheet — hệ thống tự cấp khi build với SDK mới), **không** đặt kính lên thẻ nội dung, lựa chọn hay chữ Nhật; không dựng
  `UIGlassEffect` tùy biến trong L06b; chữ trên kính dùng `.primary`.

Hướng "Biên tập Nhật × Apple native" **vẫn phù hợp** cho nội dung đọc nhiều: chữ Nhật là nhân vật chính, chrome là native. Điều chỉnh: bỏ trang
trí chia sẻ sự chú ý với đáp án (không kanji cỡ lớn lộ đáp án, không màu một mình để báo đúng/sai, không bảng điểm kiểu trò chơi).

Nguyên tắc chung: nhận biết (chọn) thay vì nhớ lại ở bản đầu; **phản hồi ngay sau khi chọn** (đúng lúc người học còn nhớ lý do), không phạt đỏ;
một hành động chính mỗi màn; không đếm ngược, không streak; sai không khóa — luôn xem giải thích rồi đi tiếp; tiến độ bằng "Bước n/N" thật.
Tiếng Nhật: dòng riêng, `.term`/`.headword`, tự xuống dòng, không co chữ; nghĩa Việt ở vai trò `.meaning` ngay dưới; không furigana vì chưa có dữ liệu reading (dòng
reading riêng khi có).

| | Library | Intro | Interaction | Feedback | Completion |
| --- | --- | --- | --- | --- | --- |
| **Mục đích** | chọn một tình huống | biết sẽ làm gì trước khi bắt đầu | đọc bối cảnh, chọn phản hồi | hiểu vì sao tốt/chưa tốt | thấy kết quả đã lưu, xem lại chỗ chưa tốt |
| **Hành động chính** | mở tình huống | Bắt đầu | chọn một phương án (hàng cả dòng) | Bước tiếp theo / Hoàn thành | Xong |
| **Phụ** | thử lại, đăng nhập | Quay lại; Nghe đọc (hỗ trợ) | Nghe đọc, Xem bản dịch | Nghe đọc câu mẫu (nếu ja) | Làm lại, Xem lại bước chưa tốt |
| **Thứ bậc nội dung** | tiêu đề (ja chính + vi) → mô tả → độ khó · số bước · ~phút ước tính | tiêu đề → mô tả → "bạn sẽ làm" (số bước) → ghi chú "đọc, không phải bài nghe" | người nói → bối cảnh (ja, vi) → các phương án (ja chính, vi phụ) | phương án đã chọn → kết quả (chữ + ký hiệu) → `feedbackVi` → phương án tốt nhất | "n/N lựa chọn tốt" → danh sách bước + lựa chọn → trạng thái lưu |
| **Component** | `UITableView` inset-grouped hàng nội dung (không kính); `StateView` | `UIScrollView` + nút `Design.Button` ghim đáy | stack cuộn: card bối cảnh (`CardSurfaceView`) + các hàng chọn `UIControl` cao tự co | cùng màn: hàng chọn đổi trạng thái + khối giải thích mở ra tại chỗ (không modal) | màn tóm tắt dạng danh sách như Results của Study |
| **Trạng thái tương tác** | highlight native khi chạm | nút vô hiệu hóa khi đang tải chi tiết | chọn → khóa các hàng khác, gọi `answer`; chạm lần hai bị bỏ qua | khối giải thích; "Bước tiếp theo" chỉ sau khi nhận phản hồi | đang lưu / đã lưu / lưu lỗi (Thử lại) |
| **Tải** | khung hàng giữ chỗ; không spinner toàn màn | tiêu đề có sẵn từ list, phần bước tải sau | hàng chọn vô hiệu + chỉ báo trên hàng đã chạm khi chờ `answer` | — | "Đang lưu kết quả" thật, không giả thành công |
| **Rỗng** | "Chưa có tình huống nào" (list rỗng) — không số liệu mẫu | — | — | — | — |
| **Lỗi** | offline/server/thiếu đăng nhập/`originRejected` bằng `StateView` có Thử lại (mapping `LearnerAPIError`) | 404 → "Tình huống không còn" + về thư viện | `answer` lỗi: ở lại bước, Thử lại (an toàn); 401 → đăng nhập, giữ bước | — | `complete` theo chiến lược F; không bao giờ hiện "đã lưu" khi chưa 200 |
| **Accessibility** | hàng gộp nhãn "tiêu đề, độ khó, n bước"; Dynamic Type đến AX XXXL, hàng tự cao | tiêu đề là header; nút ≥44 pt | mỗi lựa chọn là nút với nhãn ja+vi; trạng thái chọn nằm trong `accessibilityValue`; thông báo VoiceOver khi nhận phản hồi; không dùng màu một mình | phản hồi được đọc một lần, focus chuyển tới khối giải thích, rồi tới "Bước tiếp theo" | kết quả đọc dạng câu đầy đủ; Xong dùng được ngay |
| **Motion / haptic** | push native | push native | chọn: viền/ký hiệu đổi 120–180 ms; `StudyHaptics.answered` một lần | khối giải thích mở 180–220 ms; Reduce Motion: hiện ngay | một dấu tích tĩnh, success haptic một lần (nếu bật "Âm thanh và rung"), không confetti |
| **Điều hướng** | Today → Library (wireframe) | Library → Intro (push) | Intro → Interaction (push, Back hỏi xác nhận nếu đã chọn) | cùng màn | Completion thay Interaction trong ngăn xếp; Xong → Library |

Luồng trạng thái: `Library → Intro → (Interaction ⇄ Feedback)×N → Completion(saving → saved | saveFailed)`; mọi chuyển trạng thái do Presenter quyết
định, ViewController chỉ vẽ và phát haptic một lần mỗi sự kiện.

"Xem lại lỗi" (review mistakes): từ `attempts` (đã giải base64) + `detail`; phản hồi của từng lựa chọn lấy lại bằng `answer` (không đổi dữ liệu).
Chưa ghi vào lịch FSRS: L06 chưa có thẻ/ kỹ năng tương ứng; không giả lập điểm nghe/nói.

## I. Rủi ro

**P0 — chặn triển khai đúng/an toàn cho L06 (sản phẩm), không chặn lát cắt kỹ thuật**
- P0-1: không có tình huống sinh hoạt đã duyệt; duy nhất một tình huống email công sở, tác giả/giấy phép/chuyên gia duyệt chưa rõ.
- P0-2: không audio → không thể đạt tiêu chí "nghe trước khi hiện lời thoại" của L06; không được tuyên bố là bài nghe.
- P0-3: không có đường soạn/duyệt nội dung (không admin CRUD) → khó có ~10 tình huống được kiểm duyệt.

**P1 — thiếu sót chức năng/UX lớn**
- `complete` không idempotent (mitigate ở client theo mục F; nên thêm idempotency key ở backend).
- `attempts[].choices` base64 (nên sửa `json.RawMessage`; client phải chịu được cả hai).
- Toàn bộ API cần đăng nhập, trong khi app mở thẳng không cần đăng nhập → cần trạng thái khách và quyết định sản phẩm.
- Phiên 24 giờ không refresh; CORS production chưa cấp (`originRejected`).
- Thiếu bản dịch en; phản hồi chỉ `feedbackVi`.
- Id sai định dạng trả 500 (detail/answer).

**P2 — cải thiện về sau**
- `GET attempts` nuốt lỗi DB thành `200 []`; `_count.attempts` toàn cục; không phân trang list.
- Lưu bền lượt hoàn thành chưa gửi qua lần kill app (cần Realm — chưa thêm).
- Audio theo bước (backend + CDN), furigana/reading, biến thể ôn sau vài ngày (cần nhiều nội dung hơn).
- Lượt hoàn thành chưa đưa vào lịch ôn FSRS.

## J. Backlog L06b (có thứ tự)

Mỗi mục một commit review được; theo TDD (RED trước).

1. **DTO + giải mã** — Phạm vi: `BJTScenarioDTO.swift` + fixture đã che từ phản hồi thật. Phụ thuộc: không. Chấp nhận: giải mã list/detail/answer/complete/attempts;
   `choices` base64 và dạng mảng đều đọc được; trường thiếu → lỗi `invalidResponse`. Kiểm: XCTest.
2. **API client** — Phạm vi: các phương thức mới + `BJTScenarioAPIInterface`. Phụ thuộc: 1. Chấp nhận: gửi Bearer + Origin cho POST, chỉ UUID vào đường dẫn,
   ánh xạ 400/401/403/404/5xx/offline/interrupted, `staleSession`, hủy khi dispose. Kiểm: XCTest với URLProtocol (mẫu có sẵn).
3. **`ScenarioSession`** — Phụ thuộc: 1. Chấp nhận: không trả lời đôi; payload `complete` đúng một mục/bước, đúng thứ tự; không "xong" trước khi có phản hồi bước cuối.
   Kiểm: XCTest thuần.
4. **`ScenarioInteractor` + chiến lược không chắc chắn** — Phụ thuộc: 2, 3. Chấp nhận: bảng ở mục F, gồm `interrupted` → đọc lại attempts, không nhân đôi; 401 giữ lựa chọn.
   Kiểm: XCTest với API giả.
5. **Library + Intro + hàng trên Today** — Phụ thuộc: 4. Chấp nhận: trạng thái tải/rỗng/lỗi/khách; chuỗi vi/en/ja; `LocalizationTests` xanh.
   Kiểm: presenter test + một ảnh chụp iPhone 17.
6. **Interaction + Feedback + Completion** — Phụ thuộc: 5. Chấp nhận: bảng UX mục H; "Nghe đọc" chỉ là hỗ trợ; một haptic mỗi sự kiện; Reduce Motion.
   Kiểm: presenter test + UI test với backend thật (tài khoản dùng một lần qua `FLASHCARD_E2E_*`) + ảnh chụp.
7. **Đánh giá độc lập + cập nhật tài liệu** — `flashcard-reviewer`; ghi kết quả vào `personalized-learning.md`.

Song song, không chặn 1–7 nhưng chặn phát hành: các quyết định nội dung/giấy phép ở mục K.

## K. Quyết định còn mở

**Kỹ thuật (Claude tự quyết khi làm L06b):** điểm vào (hàng trên Today); tên DTO; mở rộng `BJTLearnerAPI` thay vì lớp mới; chiến lược retry ở mục F; không
cache/Realm ở L06b; `perform` nới phạm vi truy cập; trạng thái giữ trong bộ nhớ.

**Sản phẩm (cần chủ sản phẩm):** (1) có đòi đăng nhập để chơi tình huống hay xem trước cho khách; (2) có phát hành tình huống email công sở hay chờ nội dung sinh hoạt;
(3) cách hiển thị kết quả ("n/N lựa chọn tốt" thay cho điểm); (4) ngôn ngữ nội dung cho giao diện English (hiện chỉ vi/ja); (5) có cần thêm idempotency key/sửa `choices`
ở backend trước khi phát hành.

**Nội dung/giấy phép (cần bằng chứng):** tác giả và quyền dùng/thương mại của ba tình huống đang có; người có chuyên môn duyệt keigo và đáp án; nguồn audio bản ngữ
(thu âm mới hay có giấy phép), điều khoản phân phối; cách soạn và duyệt ~10 tình huống sinh hoạt.
