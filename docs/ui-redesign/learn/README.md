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
