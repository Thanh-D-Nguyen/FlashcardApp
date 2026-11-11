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
