# Màn học thẻ: câu ví dụ và kiểu thẻ

Ghi lại những gì đã **kiểm chứng trên mã backend Go và chạy thật** (backend local `http://localhost:18081`, 2026-10-23).
Quyết định nền: app không có từ điển cục bộ, dữ liệu từ điển lấy từ API (xem `AGENTS.md`).

## 1. So với web

| | Web (`deck-study-session.tsx`) | Backend Go | iOS |
| --- | --- | --- | --- |
| Câu ví dụ theo thẻ | Panel "Câu ví dụ liên quan" dưới thẻ: tiêu đề + số lượng, Ẩn/Hiện, ô lọc, mỗi câu có Nhật, cách đọc, nghĩa Việt, nút Đọc và Copy. Đọc `row.card.examples` | **`GET /api/flashcards/decks/{id}` không trả `examples`** (`DeckCardData` chỉ có `frontText, backText, reading, sourceId, sourceType`); `GET /api/content/lexemes/{id}` cũng không. Tài liệu `docs/mobile/DECK_FLASHCARD_API_CONTRACT.md` mô tả service Node cũ | Panel "Câu ví dụ" dưới thẻ: số lượng, Ẩn/Hiện (nhớ lựa chọn), Đọc, Sao chép. Không có ô lọc (tối đa 5 câu) và không có nhãn nguồn (API không có) |
| Chọn kiểu thẻ | `FlashcardStylePickerModal`: 7 kiểu, tier free/premium/exclusive, `PUT /api/flashcards/styles/active` | `GET /api/flashcards/styles` (cần đăng nhập) trả `slug, nameKey, config, tier, locked`; `locked` luôn `false` (TODO trong `store.go`) | Sheet "Giao diện thẻ" với đúng 7 kiểu của web + "Mặc định" (thẻ thích ứng Sáng/Tối của app). Lưu trên thiết bị |

Câu ví dụ vì vậy **không có sẵn theo thẻ** trên Go. Nguồn đã kiểm chứng: `GET /api/search?scope=example&q=<từ>` (công khai):
`title` = câu tiếng Nhật, `reading` = hiragana, `description` = nghĩa tiếng Việt, `kind = "example"`.

## 2. Câu ví dụ

- **Từ tra:** mặt tiếng Nhật của thẻ (theo chữ viết, không theo chiều bộ thẻ), tối đa 20 ký tự; thẻ chỉ có tiếng Việt hoặc mặt Nhật là cả một câu thì không có panel.
- **Lọc:** chỉ giữ câu chứa đúng từ (hoặc có cách đọc chứa cách đọc của thẻ). Chỉ mục tìm kiếm chịu lỗi gõ nên trả cả câu không liên quan (vd. "会議" trả 7 kết quả không chứa từ nào). Xếp: câu trọn vẹn (kết thúc bằng 。！？) trước cụm từ, ngắn trước, bỏ trùng, tối đa 5.
- **Khi nào tải, khi nào hiện:** tải ngay khi thẻ xuất hiện (mặt trước) nhưng chỉ **hiện sau khi lật** (hoặc sau khi trả lời câu trắc nghiệm), để không lộ cách dùng từ trước khi người học nhớ lại.
- **Trạng thái:** đang tìm, có kết quả, không có câu, cần kết nối (có "Thử lại"). Không chặn việc học.
- **Huỷ và chống kết quả cũ:** đổi thẻ hoặc rời màn huỷ request; kết quả của thẻ đã rời bị bỏ. Bộ nhớ đệm trong phiên (60 từ, kể cả kết quả rỗng; lỗi không được nhớ).
- **Câu của server không được lưu**: mất mạng thì không có câu của server (câu của người học vẫn có, xem §3). Khi làm cơ chế tải từ điển về Realm, nguồn này sẽ được thay bằng bộ nhớ đệm bền.

## 3. Câu ví dụ của người học (thêm, sửa, xoá)

Backend **không có** khái niệm ví dụ riêng của người học (`content.example_sentence` là nội dung dùng chung, chỉ admin sửa), nên các thay đổi
lưu **trong Realm trên thiết bị, theo tài khoản**, và **không đồng bộ lên server**. Form có ghi chú nói rõ điều này.

- **Mô hình** (`RCardExample`, schema 3, thêm bảng không cần migration): mỗi dòng gắn với `(ownerKey, cardId)`; `ownerKey` là id tài khoản đang đăng nhập,
  hoặc rỗng khi chưa đăng nhập. Ba loại: `custom` (câu người học tự viết), `edited` (bản của người học thay cho câu server `serverExampleId`),
  `hidden` (câu server bị gỡ cho tài khoản này, không giữ chữ). Dòng của câu server có khoá chính cố định `owner|card|serverId` nên sửa hay gỡ cùng một câu
  chỉ cập nhật một dòng.
- **Mặc định là câu của server**; ghép theo `ExampleMerge`: câu server theo thứ tự (bản sửa đứng đúng chỗ, câu đã gỡ bị bỏ), rồi câu của người học.
  Bản sửa là chữ của người học nên vẫn hiện khi mất mạng hoặc khi server không còn trả câu đó.
- **Xoá chỉ có tác dụng với người dùng này**: gỡ câu server chỉ ẩn nó cho tài khoản này (người khác vẫn thấy), có "Khôi phục N câu đã gỡ" và "Khôi phục bản gốc" cho câu đã sửa.
  Xoá câu tự viết là xoá hẳn. Cả hai đều hỏi xác nhận, và lời nhắc nói rõ khác biệt.
- **Tách theo tài khoản**: tài khoản khác hoặc người chưa đăng nhập trên cùng máy không thấy thay đổi của nhau; đăng xuất không xoá dữ liệu (quay lại đăng nhập là thấy lại).
- **Kiểm tra dữ liệu**: câu bắt buộc, tối đa 500 ký tự (cách đọc 500, nghĩa 1000), tối đa 20 câu tự viết mỗi thẻ, không trùng với câu đang hiện (kể cả của server).
  Form giữ nguyên chữ đã gõ và hiện lý do khi bị từ chối; huỷ khi đang gõ dở thì hỏi trước. Lỗi lưu được báo, không tự thử lại.
- **Vòng đời thẻ**: xoá thẻ hoặc bộ thẻ xoá luôn các dòng của thẻ đó (mọi tài khoản) trong cùng transaction; lưu bộ thẻ giữ nguyên id thẻ nên giữ câu ví dụ.
  Nhân đôi thẻ trong trình soạn tạo thẻ mới nên **không** chép câu ví dụ.
- Câu ví dụ có ở mọi thẻ, kể cả thẻ không có chữ Nhật (không tra server, chỉ có câu của người học).

## 4. Kiểu thẻ

- Danh mục lấy từ `FLASHCARD_THEME_DEFINITIONS` (`packages/shared/src/flashcard-theme.ts`): cùng slug, bảng màu, bo góc, bóng đổ, hướng lật (`rotateX` lật dọc, `rotateY` lật ngang). Kiểm tra độ tương phản WCAG như web (chữ 4.5:1, viền và nhấn 3:1) trong `CardStyleTests`.
- Phông web (Noto Serif JP, Zen Maru Gothic…) ánh xạ sang phông hệ thống: serif → Hiragino Mincho, rounded → Hiragino Maru Gothic (kana/kanji), Latin và tiếng Việt dùng thiết kế serif/rounded của hệ thống. Không đóng gói phông.
- Kiểu gradient/khung vẽ bằng `CardSurfaceView` (dùng chung cho thẻ học và ô xem trước): nền (đặc hoặc gradient theo góc CSS), panel nội dung `contentSurface` bên trong khung, bóng đổ. Chỉ thẻ có kiểu riêng; phần còn lại của màn giữ giao diện hệ thống (quy ước "một khối nổi mỗi màn").
- Lựa chọn lưu ở `StudyPreferences` (`cardStyleSlug`), áp dụng ngay khi chọn; slug lạ (kiểu bị gỡ) rơi về thẻ mặc định.
- **Chưa đồng bộ với tài khoản** (`PUT /api/flashcards/styles/active`) và không khoá theo tier (server đang mở khoá tất cả). Có thể nối sau bằng đúng hai endpoint trên.

## 5. Kiểm chứng

- Unit: `CardExampleTests` (từ tra, lọc, xếp hạng, ghép thay đổi, bản nháp, bộ nhớ đệm, huỷ), `CardExampleStoreTests` (Realm thật: lưu, tách tài khoản, xoá theo thẻ), `ExampleEditorTests`, `CardStyleTests` (danh mục, tương phản, gradient, phông), `CardStylePickerTests`, `CardStudyPresenterTests` (ẩn trước khi lật, tải trước, kết quả cũ, thử lại, kiểu).
- UI (cần backend local): `testStudyShowsExampleSentencesAfterTheFlipAndTheCardStyleCanBeChosen`, `testExampleSentencesCanBeAddedEditedRemovedAndRestored`.
- Ảnh chụp thật trên iPhone 17, cỡ chữ mặc định: thẻ mặc định với ví dụ, sheet kiểu thẻ, Sakura Bloom, Gold Calligraphy.
