# Learn — lesson API contract (K-01)

Phạm vi K-01: client + DTO + test cho bài học có cấu trúc. **Chưa có UI, chưa có Realm.**
Code: `Networks/BJTClient/BJTLessonAPI.swift`, `Models/BJTLessonDTO.swift`;
test: `BJTLessonAPITests`, fixture `BJTLessonFixtures` (response thật, ẩn danh).

## Bảng contract

| Operation | Auth | Trạng thái | Bằng chứng |
| --- | --- | --- | --- |
| `GET /levels/{code}/lessons` | công khai | **VERIFIED** | GET production 2026-11-11: J5 trả 84 hàng (60 `lesson`, 12 `review`, 12 `checkpoint`, tuần 1–12, mỗi tuần 7). J4/J3/J2/J1 → 200; `J1+` và mã lạ → 404; `j5` (thường) cũng 200 nhưng app chỉ gửi mã chuẩn. Không phân trang. |
| `GET /levels/lessons/{slug}` | công khai (guard tuỳ chọn) | **VERIFIED** | 84/84 bài J5 có `lessonContent` đủ các section; 516 activity đều có đúng 4 option, đúng 1 `isCorrect` trùng `answer`; `contents` luôn rỗng (không dùng). Slug lạ → 404 `{"error":"lesson not found"}`. |
| `PUT /levels/lessons/{slug}/progress` `{"completed":true}` | learner + CSRF (Bearer + `Origin`) | **VERIFIED theo source, chưa gọi thật** | `apps/api-go/internal/httpserver/handler_lesson_detail.go` (`nihongo-bjt` @2ed75948): body chỉ nhận `completed` (bool, `DisallowUnknownFields`, ≤4 KB); `true` = `INSERT … ON CONFLICT DO NOTHING` (**idempotent**); 404 nếu slug không active; 200 `{"isCompleted":<giá trị gửi>}`. Không gọi PUT production. |

## Quyết định

- Đọc công khai **không** gửi Bearer/cookie ⇒ `isCompleted` luôn `false` và `canSaveProgress` luôn `false` ở response ẩn danh. Tiến độ tài khoản cần một GET có Bearer (server dùng `OptionalLearnerGuard`) — để K-04 quyết định.
- PUT dùng chung `BJTLearnerAPI.perform` (token từ `AuthSession`, `Origin` của API, loại kết quả đến muộn sau logout). Chỉ có `markLessonCompleted` (không có "bỏ hoàn thành"). Server idempotent nhưng app **không tự retry**; `.interrupted` nghĩa là chưa biết kết quả.
- Lỗi dùng `LearnerAPIError` (cùng bảng status với các API học viên khác).
- Giải mã nghiêm: thiếu `lessonContent`, hoặc activity có `answer` không khớp `isCorrect`/option (thiếu, trùng key, <2 option) ⇒ `invalidResponse`, không coi là bài rỗng. Section tuỳ chọn thiếu ⇒ rỗng. Key lạ bị bỏ qua. `unitType` giữ nguyên chuỗi.
- `audioUrl` null ở mọi activity hiện nay; chỉ giữ lại, chưa phát.

## Chưa biết / để story sau

- Chất lượng nội dung (content gate trước K-02) chưa được người đánh giá; K-01 chỉ chứng minh decode đúng. Số bài J4–J1 chưa kiểm đếm.
- Rate limit của `levelReadRateLimit` chưa đo.
- Progress web/iOS cùng bản ghi (cùng `user_id`) theo source, chưa kiểm bằng tài khoản thật.

## K-02 — danh sách bài trong cấp độ

- Lối vào: nút **Bài học** (`level_lessons`) ở đầu màn nội dung của cấp độ (`HomeViewController`), chỉ khi cấp độ nằm trong `BJTLessonAPI.levelCodes` (J1+ không có). Giữ nguyên 5 tab và các mục Từ vựng/Kanji/Ngữ pháp.
- `Modules/LessonList` (presenter/VC/wireframe) + `Interactors/LessonListInteractor`. Bảng nhóm theo `weekNumber` tăng dần, trong tuần theo `sortOrder`. Hàng hiển thị tiêu đề/mô tả theo `AppLanguage` (API chỉ có vi/ja: en dùng vi; trường rỗng dùng ngôn ngữ còn lại), loại `review`/`checkpoint`, số phút và số hoạt động **chỉ khi > 0**.
- Trạng thái: loading, empty, failed + Retry; rời màn thì huỷ request, quay lại thì tải lại; lỗi chỉ tải lại bằng Retry.
- Chưa có: mở bài (K-03), tiến độ hoàn thành (K-04).

## K-03 — lesson reader và bản đọc offline

- Chọn một hàng ở danh sách bài → `Modules/LessonReader`. Thứ tự: Tình huống (bối cảnh JA/VI, mục tiêu, thách thức, kết quả mong muốn, "bạn sẽ học"), Từ vựng, Ngữ pháp, Ví dụ, Điểm cần nhớ, Lỗi thường gặp, rồi dòng Luyện tập (hiện số hoạt động của server, **tắt** đến K-04). Section rỗng bị ẩn; reading rỗng không hiện; mã máy như `relationship` không hiển thị.
- Không có link sang `DictionaryEntry`: bài chỉ có `japanese/reading/meaningVi`, **không có ID từ điển**, và ID không được ghép từ text.
- Offline: `Services/LessonCache` lưu **đúng bytes server gửi** trong envelope có version (`Application Support/Lessons/<slug>.json`, ghi atomic, loại khỏi backup, không chứa token vì GET ẩn danh). `LessonReaderInteractor` ưu tiên server; chỉ khi offline/ngắt kết nối/429/5xx mới dùng bản đã lưu và hiện banner. 404 hoặc dữ liệu hỏng **không** bị che bằng bản cũ. File hỏng/khác phiên bản/sai slug = miss. Chỉ bài đã mở thành công mới đọc được offline; không tải trước 420 bài.

## K-04 — luyện tập và hoàn thành

- Dòng **Luyện tập** của reader mở `Modules/LessonPractice`: một activity một lúc (câu hỏi, ngữ cảnh/đoạn hội thoại, 4 lựa chọn của server). Số câu lấy từ payload (bài J5 hiện có 5), không giả định.
- Chọn **một lần**: lưu trên máy trước, rồi mới hiện đúng/sai (biểu tượng + chữ, không chỉ màu), lý do (`rationaleVi`) của đáp án đã chọn và đáp án đúng, và phần giải thích. Lưu lỗi ⇒ báo lỗi, không hiện như đã trả lời.
- `RLessonProgress` (Realm **schema 7**, cộng thêm, không cần migrate; khoá `ownerKey|slug` như lịch sử ôn tập). `completedAt` = xong trên máy; `serverConfirmedAt` = server đã xác nhận cho đúng tài khoản. Tiến độ của guest không bị gộp vào tài khoản khi đăng nhập.
- Máy chỉ gửi `PUT /levels/lessons/{slug}/progress` khi đã đăng nhập, **một lần** ngay sau khi hoàn thành; không tự gửi lại. Lỗi ⇒ "chưa lưu vào tài khoản" + nút thử lại do người học bấm; mất kết nối giữa chừng ⇒ "chưa rõ"; kết quả đến sau khi đổi/đăng xuất tài khoản bị bỏ. Mở lại bài đã xong chỉ hiện nút "Lưu vào tài khoản", không tự gửi.
- Chưa kiểm với server thật (không gọi PUT production). Chưa có hiển thị tiến độ tài khoản từ server (GET ẩn danh luôn `isCompleted=false`).

## K-05 — lưu từ trong bài vào bộ thẻ

- Mục Từ vựng của reader: vuốt trái một từ (hoặc hành động VoiceOver "Lưu vào bộ thẻ") để lưu từ đó, hoặc hàng "Lưu tất cả các từ vào bộ thẻ". Luôn hỏi bộ thẻ trước (các bộ của người học, hoặc tạo bộ "Từ các bài học"); huỷ thì không ghi gì.
- `Interactors/LessonWordSaver` dùng cùng repository (`DeskManagement`/`CardManagement`) như `DictionaryDeckWriter`. Bài **không có ID từ điển** nên không tạo `DictionaryCard`; thẻ có id `lesson:<deck>:<slug>:<từ>` (xác định, không phải UUID giả), mặt trước là từ, reading ở phần phụ, mặt sau là `meaningVi`.
- Không tạo thẻ thiếu một mặt; bỏ qua từ trùng (cùng id, hoặc cùng chữ với thẻ tự gõ / từ vựng từ điển); lưu cả lô trong một transaction; thông báo số từ đã thêm / đã có / bị bỏ qua.

## K-06 — ô bài học trên Today

- `TodayLessonSlotView` nằm **dưới** khối ôn tập (hero giữ nguyên, nút chính của hero không đổi). Nội dung chỉ lấy từ tiến độ thật của người học trên máy (`RLessonProgress` theo `ownerKey`), không cần mạng: khách và từng tài khoản thấy tiến độ riêng.
- Thứ tự quyết định (`Interactors/TodayLessonSlot`): (1) bài đang làm dở (có câu trả lời, chưa xong) → "Học tiếp" + `n/m` câu đã trả lời; (2) bài đã xong gần nhất mà bản đã lưu (`LessonCache`) ghi `nextLesson` chưa làm → "Bài tiếp theo" (mở thẳng bài đó); (3) đã xong nhưng không biết bài kế (bài cuối cấp độ, hoặc bài chưa từng lưu trên máy) → "Chọn bài học" (mở danh sách cấp độ); (4) chưa có gì → "Chọn trình độ".
- Không hiển thị số thẻ ngày mai hay bất kỳ số suy đoán nào; số duy nhất là số câu đã trả lời / số bài đã xong lấy từ lưu trữ. Hai nguồn ôn tập (thẻ local, thẻ tài khoản) không được gộp ở đây.
- Chưa có: đồng bộ tiến độ từ server về (GET ẩn danh luôn `isCompleted=false`), nên bài hoàn thành trên web hay thiết bị khác không xuất hiện ở ô này.
