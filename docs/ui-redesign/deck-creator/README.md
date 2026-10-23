# Tạo bộ thẻ: tạo thủ công, tạo tự động, gợi ý từ điển, gợi ý ảnh

Tài liệu này ghi lại những gì **đã kiểm chứng trên mã backend Go thật và chạy thật** khi nâng cấp màn "Tạo bộ thẻ"
(repo backend: `nihongo-bjt/apps/api-go`, backend local `http://localhost:18081`, ngày 2026-10-23).
Không có DTO nào được suy ra từ tên endpoint; mỗi dòng dưới đây có nguồn.

## 1. Ma trận tương đương tính năng

| Tính năng | Web (`auto-gen-dialog.tsx`, `deck-composer-panel.tsx`) | Backend Go (đọc mã + chạy thật) | iOS trước | iOS sau |
| --- | --- | --- | --- | --- |
| Tạo thủ công | Có | `POST /api/flashcards/decks` | Có (Realm, offline) | Giữ nguyên |
| Xem trước số thẻ | `POST …/generate/preview` | Chỉ nhận `levels`, `sourceTypes`; trả `{availableCount}` | Không | Có |
| Tạo tự động | Cấp độ, loại nội dung, chiều học, số thẻ 5–50 | `POST …/generate`: `name`, `sourceTypes`, `levels`, `limit` (≤0 hoặc >500 → **âm thầm thành 50**), `direction` (`jp_to_vn`, `vn_to_jp`, `both`). Trả bộ thẻ **không có thẻ**. | Không | Có (5–100, bước 5) |
| Lọc theo chủ đề / "vùng yếu" (`adaptive`) | Có trên giao diện | **Không có**: handler bỏ qua các trường này | Không | **Không hiển thị** (không bịa) |
| Gợi ý từ điển khi gõ | Chỉ gợi ý cách đọc (`/api/reading-assist`) | `GET /api/search` công khai (headword, reading, nghĩa tiếng Việt, JLPT); `GET /api/search/suggest` không có nghĩa; `POST /api/flashcards/cards/suggest` cần đăng nhập, `ORDER BY RANDOM()`, khớp chuỗi con | Chỉ từ điển offline (Realm), ánh xạ **toàn bộ** kết quả | Chỉ `/api/search` (đã bỏ từ điển offline), có debounce, huỷ, chống kết quả cũ, IME |
| Gợi ý ảnh | `POST /api/media/search-images` → `{images:[{id,thumbUrl,fullUrl,source}]}` | **Chỉ là stub**: sau khi kiểm tra đầu vào luôn trả **503** ("provider integration is missing") | Chọn từ Ảnh hoặc dán URL https | Thêm "Tìm ảnh…"; xử lý 503 như trạng thái bình thường |
| CSRF cho POST native | Cookie + Origin | `CSRFGuard`: thiếu `Origin`/`Referer` → **403 `forbidden: missing origin`** (đã chạy thật); origin phải nằm trong `CORS_ORIGINS` (local có `http://localhost:18081`) | Login/logout gửi origin của chính API | Dùng lại đúng cách đó; 403 hiển thị là lỗi tích hợp |

Bằng chứng chạy thật (tài khoản local dùng một lần, token không ghi vào repo):

- Không bearer → `401 {"error":"unauthorized"}`. Có bearer, không `Origin` → `403 {"error":"forbidden: missing origin"}`.
  Có bearer và `Origin: http://localhost:18081` → `200 {"availableCount":80}` (N5, từ vựng).
- DB local chỉ có thẻ cho **N5 từ vựng (80)**; N4–N1, kanji, ngữ pháp đều trả `0`. Giao diện hiển thị "Không đủ thẻ" đúng như vậy.
- `POST /api/media/search-images` → `503 image search unavailable: Go API provider integration is missing; configure UNSPLASH_ACCESS_KEY or PIXABAY_API_KEY`.

## 2. Quyết định kiến trúc

**Định danh local ↔ server (không đổi schema Realm).** Server tạo bộ thẻ rồi chỉ trả `id`; thẻ lấy bằng `GET /api/flashcards/decks/{id}` (chỉ đọc).
Bộ thẻ local dùng **đúng id của server**; mỗi thẻ local dùng **`deck_card.id`** (duy nhất trong bộ), không dùng id `flashcard_variant`
(server chọn ngẫu nhiên nên một variant có thể nằm ở nhiều bộ, sẽ đụng khoá chính `RCard.id`).
Nhập cùng một bộ hai lần gặp lại bộ cũ (`alreadyPresent`) thay vì nhân đôi. Đã kiểm trên máy: id dòng thư viện = id server.

**Không có đồng bộ.** Sau khi nhập, sửa trên iOS không đẩy lên server, xoá trên iOS không xoá bản trên server. Giao diện nói rõ điều này.

**Tạo bộ thẻ không idempotent** (`ORDER BY RANDOM()`, không có khoá idempotency) nên:
- chỉ chạy khi người dùng bấm, không retry tự động, chặn bấm lặp, khoá lựa chọn và nút đóng khi đang chạy;
- ngắt kết nối giữa chừng (kết quả không rõ) → cảnh báo "có thể đã tạo trên website, kiểm tra trước khi tạo lại";
  chưa kết nối được (chắc chắn chưa gửi) → "Chưa có gì được tạo";
- tạo xong mà tải thẻ lỗi → chỉ **tải lại** (GET), không tạo lại.

**Hạn chế đã biết:** server đã tạo bộ (và `user_flashcard` ở trạng thái `new`) ngay cả khi người dùng bỏ bộ local; không có API huỷ an toàn ngoài `archive`,
nên iOS không tự xoá phía server. App bị kill giữa "server tạo xong" và "nhập local" → bộ chỉ còn trên server.

**Hướng "Cả hai" (`both`)** của server xen kẽ chiều theo từng thẻ (không thêm bản đảo của mọi thẻ). Bộ local chỉ có một chiều,
nên cách đọc (reading) được đặt theo **chữ viết của từng thẻ** (dưới mặt trước nếu mặt trước là tiếng Nhật, vào ghi chú nếu mặt sau là tiếng Nhật),
và phát âm khi học chọn ja-JP/vi-VN theo từng thẻ (sửa `CardStudyPresenter`).

**Dữ liệu seed local có thẻ lẫn chiều:** kho `flashcard_variant` đã chứa cả bản đảo (front tiếng Việt) và trùng lặp, nên cả bộ `jp_to_vn` cũng có thẻ tiếng Việt ở mặt trước.
Đây là chất lượng dữ liệu backend, không phải do iOS.

## 3. Gợi ý từ điển

- `SuggestionQuery`: tối thiểu 1 ký tự Nhật hoặc 2 ký tự Latin, tối đa 40; chữ viết của text đã gõ quyết định tra Nhật→Việt hay Việt→Nhật (không dựa vào chiều bộ thẻ).
- Debounce 300 ms, `flatMapLatest` huỷ yêu cầu mạng cũ; mỗi phản hồi chỉ được hiển thị nếu vẫn khớp yêu cầu hiện tại (xoá chữ / đổi trường / đang gõ IME thì bỏ).
- Đang soạn IME (`markedTextRange != nil`) **không gọi API**.
- Kết quả `/api/search` được xếp hạng (khớp-chính-xác → tiền tố → chứa), loại trùng, loại kết quả "nhiễu" do tìm kiếm chịu lỗi gõ (ví dụ "食べ" → "イベント駆動").
- Điền thẻ: ô đang gõ được hoàn thành; ô khác chỉ điền khi trống; nếu ô đã có chữ khác thì hỏi "Thay nội dung bạn đã viết?" (Thay thế / Giữ của tôi).
- Chỉ điền trường có thật: từ, cách đọc, nghĩa. `/api/search` không trả từ loại hay câu ví dụ; nên **không** điền từ loại/ví dụ ở bước này. Mất mạng thì không có gợi ý (app không còn từ điển offline).

## 4. Gợi ý ảnh

- Từ khoá: nghĩa đầu tiên của mục từ điển đã chọn; nếu không có, mặt không phải tiếng Nhật; cuối cùng là mặt tiếng Nhật. Người dùng sửa được ô tìm.
- Chỉ lưu ảnh khi người dùng bấm "Dùng ảnh này"; ảnh tải qua `RemoteImageLoader` (https, ≤10 MB) và lưu bằng `CardImageStore` như ảnh thủ công; ảnh cũ chỉ bị thay khi người dùng chủ động chọn.
- 503, chưa đăng nhập, 429, offline, 403 origin, rỗng đều có trạng thái riêng; không chặn việc sửa thẻ, vẫn dùng được "Chọn từ Ảnh" và "Dùng địa chỉ web".
- Ghi nguồn: hợp đồng chỉ có tên nhà cung cấp (`source`), không có tên tác giả/giấy phép, nên chỉ lưu `source`, `id`, URL gốc cạnh file ảnh (`*.attribution.json`, bị dọn cùng ảnh). **Chưa hiển thị trong màn học**, và không đủ để đáp ứng yêu cầu ghi công của Unsplash khi backend bật nhà cung cấp.
- **Chưa kiểm chứng:** hình dạng phản hồi thành công của Go (stub chưa bao giờ trả 200). DTO theo cách web đọc (`data.images`).

## 5. Việc backend cần làm để hoàn thiện (ngoài phạm vi iOS)

1. Tích hợp nhà cung cấp ảnh cho `/api/media/search-images` (hiện luôn 503) và trả thêm tác giả + giấy phép.
2. Trường `imageUrl`/liên kết ảnh cho thẻ (`DeckCardInput` chưa có), để ảnh đồng bộ được.
3. `Idempotency-Key` cho `POST …/generate`, hoặc cho phép `preview` trả luôn danh sách thẻ, để tạo mà không phải tạo bộ ở server.
4. Lọc chủ đề cho generate (hiện chỉ có trên giao diện web).
5. Cho phép origin của app native trong `CORS_ORIGINS` cho từng môi trường (production hiện chưa cấu hình URL).
