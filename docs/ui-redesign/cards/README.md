# Thiết kế lại tab Thẻ (Cards): thư viện, trình soạn bộ thẻ, học thẻ

Phạm vi: tab **Thẻ** (`Modules/Card`), màn **Tạo/Sửa bộ thẻ** (`Modules/CreateDesk`), màn **Học thẻ** mới (`Modules/CardStudy`),
lớp dữ liệu Realm của bộ thẻ và việc lưu ảnh của thẻ. Bộ thẻ vẫn là **dữ liệu cục bộ** (Realm); không có đồng bộ với server.
Ảnh chụp thật từ app đang chạy nằm cạnh tài liệu này (`before/`, `iphone17-ios27/`, `iphone17e-ios26.5/`, `ui-test-attachments/`).

Nhãn: **[Đã kiểm chứng]** = đã chạy và quan sát/đo; **[Chưa kiểm chứng]** = chưa thể kiểm chứng trong môi trường này.

## 1. Audit trước khi sửa (đọc mã + chạy thật)

| # | Phát hiện | Bằng chứng |
| --- | --- | --- |
| 1 | `DeskEntity.toRealm()` **không ghi `sortingLanguage`** → chiều thẻ luôn về "Nhật–Việt" sau khi lưu | Test `test_addPersistsTheCardDirection` đỏ trước khi sửa |
| 2 | `DeskManagement.delete` xoá **một object chưa được quản lý** → `RLMException` (app sẽ crash) và thẻ con không bị xoá | Test `test_deleteOfAnUnknownDeckThrowsInsteadOfCrashing`/`test_deleteRemovesTheDeckAndItsCards` đỏ |
| 3 | `update` với `.modified` **giữ lại thẻ đã bị bỏ khỏi bộ** (mồ côi trong Realm) và để sai thứ tự (`[c,a,b]` thay vì `[a,c]`) | `test_updateRemovesCardsDroppedFromTheDeck` đỏ |
| 4 | Trình soạn cũ **không sửa được bộ đã lưu** (chỉ tạo mới); `CardDataModel.toCardEntity` ghi đè `frontExtraText`/`backExtraText` bằng chuỗi rỗng; id thẻ sinh lại mỗi lần | Đọc `DeskDataModel.swift` |
| 5 | Ô ảnh trong trình soạn chỉ là placeholder, không chọn/đổi/xoá được ảnh | `before/create_desk.png` |
| 6 | Thanh trên cùng xanh dương hệ thống (lệch bảng màu chàm/giấy), tiêu đề Tab nhỏ, ô chọn bộ trống | `before/cards_tab.png`, `before/create_desk.png` |
| 7 | Đóng trình soạn chỉ kiểm tra "dữ liệu chưa hợp lệ" chứ không biết có thay đổi hay không; không có khôi phục bản nháp | Đọc `CreateDeskPresenter.close()` |
| 8 | `print("Current Page:")`, `unowned self` trong subscription, `reloadData` mỗi lần có sự kiện; module `DeskList` (chọn bộ qua modal) là đường vòng không cần thiết | Đọc mã |
| 9 | Lưu thẻ thiếu một mặt thì **bị bỏ lặng lẽ** (`compactMap`) | Đọc `toCardEntity` |

## 2. Ma trận tương đương tính năng (iOS / Web / Backend)

Web = `apps/web/app/[locale]/flashcards/*` của `nihongo-bjt`; Backend = `apps/api-go/internal/flashcarddeck` + `httpserver`.

| Tính năng | iOS trước | Web | Backend Go | iOS sau | Dữ liệu cần migrate | Ưu tiên |
| --- | --- | --- | --- | --- | --- | --- |
| Danh sách bộ thẻ | Modal chọn bộ (lưới/danh sách) | Duyệt, tìm, nhân bản, chia sẻ | `GET /api/flashcards/decks` | **Thư viện**: tìm kiếm (tên, mô tả, nội dung thẻ), sắp xếp (nhớ lựa chọn), xoá có xác nhận, sửa, menu ngữ cảnh, trạng thái trống | Không | P0 |
| Tạo bộ | Tên, mô tả, chiều thẻ, ≥2 thẻ | `titleVi/titleJa/description/visibility`, 1–200 thẻ | `POST` | Tên, mô tả, chiều thẻ, 2–200 thẻ (giữ luật cũ ≥2). `titleJa`, `visibility` không có vì thuộc phía server | Không | P0 |
| Sửa bộ đã lưu | **Không có** | `PATCH` | `PATCH` giữ `cardId` | **Có**, giữ nguyên id bộ/thẻ, ngày tạo, thẻ không bị mất | Không đổi schema | P0 |
| Mặt trước/sau | Có | Có | Có | Có | – | P0 |
| Cách đọc | Lưu trong Realm (`frontExtraText`) nhưng không nhập được và bị xoá khi lưu | `reading` | `reading` | Nhập/sửa/hiển thị (ẩn/hiện khi học). **Không mất dữ liệu cũ** | Dùng lại cột `frontExtraText` | P0 |
| Ghi chú (nội dung phụ mặt sau) | Cột `backExtraText` có nhưng bị xoá khi lưu | Không có | Không có | Nhập/sửa/hiển thị ở mặt sau | Dùng lại `backExtraText` | P1 |
| Thêm/xoá/sắp xếp thẻ | Thêm, vuốt xoá, vuốt lên/xuống | Kéo thả, chuyển lên/xuống | Thứ tự `position` | Thêm, nhân bản, xoá (hỏi nếu thẻ có nội dung), lên/xuống, kéo-thả ở chế độ sắp xếp, VoiceOver qua menu | Không | P0 |
| Ảnh minh hoạ | Ô trống không dùng được | Tải lên (presign), tìm ảnh, proxy, URL | **Không lưu ảnh cho thẻ** (xem §3) | Chọn từ Ảnh (PHPicker), địa chỉ `https`, xem/đổi/xoá, trạng thái đang tải/lỗi; lưu **cục bộ** | Dùng lại `imageUrl` (`local-image:<tệp>` hoặc URL) | P0 |
| Tìm ảnh trên web | Đã gỡ khi dọn khoá nhúng | `/api/media/search-images` | **Luôn 503** (chưa tích hợp nhà cung cấp) | Không làm (không có nguồn thật) | – | Chặn bởi backend |
| Nhập hàng loạt | Không | `trước\|sau\|ảnh` / tab, tối đa 200 | – | Cùng cú pháp, tối đa 200, báo số dòng sai, ảnh phải `https` | Không | P1 |
| Gợi ý từ từ điển offline | Có (JaVi/ViJa) | `cards/suggest` | có | Giữ; không ghi đè chữ người dùng đã viết | Không | P1 |
| Bản nháp | Không | Không thấy | – | Tự lưu, hỏi khôi phục sau khi app bị đóng đột ngột | UserDefaults (khoá `…cards.draft.<id\|new>`) | P1 |
| Xác thực/hủy/bỏ | Cảnh báo "dữ liệu dở dang" | – | – | Thay đổi chưa lưu → hỏi bỏ; vuốt đóng bị chặn khi đang dở; lỗi từng ô; thẻ thiếu một mặt báo lỗi thay vì bỏ | Không | P0 |
| Học thẻ | Lật bằng chạm, vuốt ngang | `flip`, `shuffle`, `quiz`, đọc to, ẩn/hiện cách đọc & ảnh, thanh tiến độ, màn hoàn thành | – | Lật (hiệu ứng, giảm chuyển động → mờ dần), trước/sau, **xáo trộn**, **trắc nghiệm** (đáp án + lời giải), **đọc to** (ja-JP/vi-VN, tự động), ẩn/hiện cách đọc/ảnh, tiến độ, **màn kết quả** thật | Tuỳ chọn học lưu `UserDefaults` | P0 |
| Ôn tập SRS (đánh giá, streak, "mentor") | – | Có (cần server) | `flashcardreview` | **Không làm**: cần đồng bộ và dữ liệu thật; không bịa tiến độ/streak | – | Ngoài phạm vi |
| Chia sẻ / nhân bản / tạo tự động | – | Có | Có | Không làm (cần đồng bộ bộ thẻ cục bộ ↔ server, chưa có hợp đồng định danh) | – | Ngoài phạm vi |
| Xoá bộ | **Crash** (xem §1) | Lưu trữ (archive) | `DELETE` | Xoá có xác nhận từ thư viện (vuốt/menu giữ lâu) hoặc từ menu "…" của trình soạn; xoá thẻ con, bản nháp và ảnh mồ côi | Không | P0 |

Chiều thẻ (`sortingLanguage`) bây giờ có tác dụng cụ thể: quyết định ngôn ngữ đọc to của từng mặt, nhãn ngôn ngữ trên thẻ, và hướng gợi ý từ điển.

## 3. Kiểm chứng backend (đọc mã Go thật + chạy)

Nguồn: `nihongo-bjt/apps/api-go` (chỉ **đọc**; không sửa repository này vì ngoài phạm vi được giao và cây làm việc của nó đang có thay đổi chưa commit).

- **Ảnh của thẻ KHÔNG được lưu ở backend.** `flashcarddeck.DeckCardInput` chỉ có `cardId, frontText, backText, reading`. Web gửi thêm `primaryImageAssetId` và `imageUrl`; `json.Decoder` bỏ qua trường lạ nên **bị mất lặng lẽ** (HTTP vẫn 201/200).
  `insertDeckCards` chỉ ghi `front_text, back_text, reading` vào `learning.flashcard_variant`; `GetDeck` không đọc media. Bảng `learning.card_media_link` có trong migration `20260425221000_learning_flashcards_srs` nhưng **không có mã Go nào ghi hoặc đọc nó** (`rg card_media apps/api-go` không có kết quả).
- Upload: `POST /api/media/presign-upload` → `PUT /api/media/upload/{id}` → `POST /api/media/complete-upload` tạo `media.asset` thuộc người dùng (kiểm chứng bằng đọc mã + test Go `TestAudit159Wave9MediaSignedLocalUploadFlowPersistsOwnedAsset`), nhưng **không có gì gắn asset đó vào thẻ**. Do đó "upload trả 200" không chứng minh ảnh đồng bộ; iOS không dùng upload.
- `POST /api/media/search-images` luôn trả **503** ("provider integration missing"); có test Go khẳng định (`…SearchImagesRequiresConfiguredProvider`).
- Sở hữu & xung đột: `UpdateDeck` kiểm tra `owner_user_id`, trả 403 `ErrNotOwner`; `loadDeckCard` từ chối `cardId` của người khác; sửa thẻ chuẩn (lexeme/grammar/kanji) tạo bản sao thuộc bộ; thẻ `custom` mồ côi bị `archived`. Không có `If-Match`/phiên bản → **last-write-wins**.
- UUID: server giữ UUID `deck.id`, `flashcard_variant.id`; iOS giữ UUID chuỗi tự sinh. Không có ánh xạ nên **không đồng bộ** (đúng yêu cầu: không dựng đồng bộ hai chiều chưa kiểm chứng).
- Test tích hợp Go cần `TEST_DATABASE_URL`; trong phiên này chúng **bị SKIP** (không chạy) — kết luận trên dựa vào mã nguồn và test đọc được, không phải chạy DB. Không gọi API ghi bằng tài khoản thật.
- Backend local (`localhost:18081`) đang chạy; các UI test cũ của Cấp độ/Từ điển dùng nó và đã qua.

**Đề xuất cho backend (chưa áp dụng, cần repository/chủ sở hữu duyệt):** thêm `PrimaryImageAssetID *string` vào `DeckCardInput` và `UpdateDeckInput`; trong `insertDeckCards`/`UpdateDeck` ghi/xoá `learning.card_media_link(card_id, asset_id, role='primary_image')` sau khi kiểm tra `media.asset.owner_user_id = userID AND status='active'`; trả `primaryImage{assetId, readUrl}` trong `GetDeck`; thêm test tích hợp "tạo → đọc lại → ảnh còn" và "asset của người khác bị từ chối". Chỉ khi đó app mới nên thêm upload + đồng bộ ảnh, kèm ánh xạ UUID.

## 4. Thiết kế

Kết hợp hướng A+B của `UI_REDESIGN_BLUEPRINT.md` (Biên tập Nhật × Apple native), dùng lại token sẵn có.

Nguồn kỹ năng đã đọc và áp dụng: *UI UX Pro Max* (kiểm tra `ux`: giảm chuyển động, tiến độ nhiều bước, vùng chạm, tương phản; stack SwiftUI/Dynamic Type), *apple-skills:design* (UX writing, Dynamic Type, phản hồi xúc giác), *liquid-glass* (glass chỉ cho lớp chức năng; không glass trên nội dung; một hành động nhấn). Kỹ năng Liquid Glass là SwiftUI; app là UIKit nên chỉ áp dụng nguyên tắc.

- **Liquid Glass chỉ ở lớp điều khiển**: thanh điều hướng/tab hệ thống, nút trước/sau khi học (`UIButton.Configuration.glass()`), menu. Thẻ, hàng danh sách, ô nhập **không** có glass.
- **Hành động chính dùng nền đặc `Design.Button.primary`, không `prominentGlass`**: đo trên ảnh Dark Mode, chữ của `prominentGlass` mờ trên nền xanh nhạt (xem lịch sử trong phiên: `quiz_answered_dark` trước/sau). Nút đặc đạt độ tương phản ở cả hai giao diện.
- **Thư viện**: tiêu đề lớn + phụ đề "N bộ thẻ", hàng phẳng (không thẻ trong thẻ), ký tự Mincho của thẻ đầu làm "neo" như số kanji ở màn Cấp độ, dòng xem trước "犬 · 猫 · 水 …". Một chạm = học. Sửa/xoá qua vuốt, menu giữ lâu, nút sắp xếp. Trạng thái trống có lời mời và nút duy nhất.
- **Học**: một thẻ lớn (từ 52 pt, tối đa 96 pt theo Dynamic Type), nhãn ngôn ngữ, nút loa đặt ngay trên thẻ, nút chính đổi theo ngữ cảnh ("Hiện đáp án" → "Thẻ tiếp theo" → "Kết thúc"), nút trước/sau dạng glass, mọi tuỳ chọn ẩn trong menu "…" (hiển thị dần). Trắc nghiệm: lời giải **trên** các lựa chọn, đúng/sai có biểu tượng + chữ + màu (không chỉ màu).
- **Trình soạn**: form `insetGrouped` hệ thống; chi tiết (tên, mô tả, chiều thẻ) rồi danh sách thẻ; mỗi thẻ chỉ có Mặt trước/Mặt sau, "＋ Cách đọc / ＋ Ghi chú / ＋ Ảnh" hiện dần; thanh trên bàn phím có gợi ý từ điển, "Thẻ 3/12", ô tiếp theo, thêm thẻ, hạ bàn phím.
- **Chuyển động**: lật 3D 0,45 s; trượt nhẹ khi đổi thẻ; **Giảm chuyển động** → mờ dần 0,15 s, không trượt. Xúc giác (lật, đúng/sai) chỉ khi bật "Âm thanh và rung" trong Cài đặt — công tắc này trước đây được lưu nhưng không có mã nào đọc.
- **Trợ năng**: thẻ là một phần tử VoiceOver (nhãn mặt đang xem, gợi ý "Chạm hai lần để lật", hành động tuỳ chỉnh: đọc to / tiếp / trước), thông báo khi lật và khi trả lời, lỗi nhập là văn bản có biểu tượng, vùng chạm ≥ 44 pt, bố cục đổi trục ở cỡ chữ trợ năng, nút chính đổi capsule → chữ nhật bo ở cỡ chữ trợ năng (capsule thành hình bầu dục khi chữ xuống dòng — lỗi bắt được trên ảnh thật).

## 5. Kiến trúc (thay đổi)

- Giữ UIKit + VIPER (View → Presenter → Interactor → Repository/Service) và điều hướng qua Wireframe. Không thêm dependency; **gỡ** `SwipeCellKit` và `CollectionViewPagingLayout` (không còn caller), xoá `MMTextView` vendored, module `DeskList`, `GradientView`, `FadingEdgeCollectionView`, `TopBarView`, `DeskDataModel`.
- Mô hình soạn thảo là **kiểu giá trị** (`DeckDraft`/`CardDraft`) mang theo id của bộ/thẻ đã lưu; `StudySession` là máy trạng thái thuần (xáo trộn, trắc nghiệm, điểm) với nguồn ngẫu nhiên tiêm vào.
- `DeskManagement` giờ đọc/ghi trong một transaction trên đối tượng đã được quản lý, kiểm tra trùng khoá chính **trước** khi ghi (Realm ném ngoại lệ không bắt được) và từ chối thẻ thuộc bộ khác.
- **Realm schema không đổi** → không cần migration; `imageUrl` dùng lại với ba dạng: rỗng, URL cũ (giữ nguyên), `local-image:<tệp>`. Có test "bộ thẻ cũ + ảnh từ xa + không có phần phụ vẫn nguyên vẹn sau khi sửa".
- Ảnh cục bộ: `Application Support/CardImages/<uuid>.jpg` (≤ 1600 px, JPEG 0,85, nền trắng cho PNG trong suốt, ≤ 25 MB đầu vào); tham chiếu là tên tệp (không bị gãy khi đổi đường dẫn container; chặn `..` và `/`). `CardMediaMaintenance` xoá ảnh không còn được **bộ đã lưu hoặc bản nháp** tham chiếu, chạy sau lưu/huỷ/xoá bộ.
- Ảnh từ URL: chỉ `https`, tối đa 10 MB, kiểm tra `Content-Type`, không gửi header/cookie phiên, huỷ khi dispose; sau đó lưu cục bộ để ảnh không mất khi ngoại tuyến.

## 6. Kết quả kiểm chứng (chạy thật, 2026-10-22)

Môi trường: Xcode 27.2, scheme `FlashcardApp-Local`, iPhone 17 / iOS 27.0 (chính), iPhone 17e / iOS 26.5 (ảnh), backend local `/api/levels` trả 200.

| Kiểm tra | Kết quả |
| --- | --- |
| Build (deployment target 26.0) | SUCCEEDED; không còn cảnh báo mới từ file đã thêm/sửa (đã sửa `groupedHeader/Footer` deprecated và cảnh báo `Sendable` của `SpeechService`) |
| Chạy toàn bộ unit + UI (`-parallel-testing-enabled NO`, có coverage) | **273/273 đạt** (gồm 8 UI test cũ dùng backend local và 5 UI test Thẻ mới/được cập nhật) |
| TDD cho lỗi dữ liệu | `DeskManagementTests`: **6/8 đỏ trước khi sửa** (hướng thẻ không lưu, xoá bộ ném `RLMException`, thẻ mồ côi, thứ tự, cập nhật bộ đã xoá), xanh 8/8 sau khi sửa |
| Test mới | `DeckDraftTests`, `BulkDeckImportTests`, `StudySessionTests`, `CardMediaTests` (tham chiếu ảnh, kho ảnh, kho bản nháp, tải ảnh bằng `URLProtocol`, vùng chạm, `CardImageView` huỷ/tải lại), `CardPresenterTests`, `CardStudyPresenterTests`, `CreateDeskPresenterTests`, `CardsIntegrationTests` (Realm trong bộ nhớ + kho ảnh + kho nháp thật; gồm "bộ thẻ cũ có ảnh từ xa vẫn nguyên sau khi sửa") |
| UI test (giao diện thật + Realm thật) | tạo bộ → lưu → xuất hiện trong thư viện → học (lật/tiếp/kết thúc/kết quả) → trắc nghiệm → sửa (thêm thẻ) → **mở lại app, thay đổi còn** → xoá từ trình soạn → **mở lại app, bộ đã mất**; khôi phục bản nháp sau khi app bị đóng; lỗi nhập hiện inline; tìm kiếm không kết quả; thanh trên bàn phím nằm trên bàn phím (test cũ, giữ nguyên hợp đồng) |
| Coverage dòng (unit + UI) của file thuộc phạm vi | `CardStudyPresenter` 100% · `StudySession` 98,4% · `CreateDeskPresenter` 97,7% · `CardPresenter` 96,9% · `DeskManagement` 98,9% · `CardImageStore` 94,2% · `RemoteImageLoader` 94,1% · `BulkDeckImport` 100% · `DeckDraft` 98,8% · `CardStudyViewController` 90,5% · `CardEditorCell` 91,2% · `CreateDeskViewController` 61,0% · `CardViewController` 72,4% · `CreateDeskInteractor` 65,9% · `BulkImportViewController` **0%** (chưa có test) · `SpeechService` 30,8% (cần âm thanh thật). **Không** suy ra coverage toàn app từ các số này |
| Ảnh thật | `iphone17-ios27/`: thư viện (sáng, tối, AX-XXXL), học (mặt trước/sau sáng, tối, AX-XXXL), menu học, trắc nghiệm đã trả lời (sáng/tối), kết quả, trình soạn (mới, lỗi, sửa sáng/tối, AX-XXXL, menu "…"). `iphone17e-ios26.5/`: thư viện trống (sáng/tối), thư viện, học, trình soạn sửa, menu ảnh, ảnh từ web thêm thành công, lỗi khi địa chỉ không phải ảnh, hỏi khôi phục bản nháp. `ui-test-attachments/`: ảnh chụp trong UI test **kèm bàn phím thật** (thanh gợi ý/vị trí thẻ ở trên bàn phím) |
| Lỗi chỉ lộ ra nhờ ảnh/chạy thật và đã sửa | nút nhấn thành hình bầu dục ở AX; nút nhấn glass mờ ở Dark Mode; ô ký tự đầu hàng thư viện giãn cả hàng; chip "Cách đọc/Ảnh" xuống dòng; ảnh vừa thêm đè lên chip (hàng không đo lại chiều cao); lời giải trắc nghiệm nằm khuất dưới nút; đáp án mờ sau khi chọn (nút bị disable); nhãn lỗi không hiện với XCUITest (bọc trong `UIView`); hàng đầu bị thanh tìm kiếm che khi đổi chiều cao thanh sau bố cục; ảnh tải từ web: HTML bị từ chối đúng (ảnh chụp lỗi) |
| Review độc lập (agent `flashcard-reviewer`, chỉ đọc) | Không có crash/mất dữ liệu. 9 điểm, đã xử lý: `CardImageView.cancel()` làm ảnh trống khi tái sử dụng ô/quay lại thẻ; lưu khi ảnh còn đang tải làm mất ảnh (nay chặn và báo); chèn/nhân bản thẻ không cập nhật số thứ tự các ô lân cận; bản nháp của bộ đã xoá giữ ảnh mãi (nay xoá cùng bộ); chip dưới 44 pt (vùng chạm mở rộng); chuyển hướng https→http/mạng nội bộ khi tải ảnh (nay chỉ theo https, phiên ephemeral); không giới hạn số điểm ảnh trước khi giải mã (trần 40 MP); thông báo sai khi trùng id thẻ; vài điểm yếu của test (thêm test hồi quy cho từng mục) |

## 7. Giới hạn đã biết / chưa kiểm chứng

- **[Chưa kiểm chứng]** VoiceOver thật, Increase Contrast, Reduce Motion/Transparency bật, iPad, thiết bị thật, xúc giác (simulator không phát), hộp chọn Ảnh (PHPicker chạy ngoài tiến trình, không tự động hoá được — đường xử lý dữ liệu ảnh được test bằng đơn vị; đường `https` được chạy thật bằng `https://httpbin.org/image/png`).
- Bản dịch tiếng Anh/Nhật do tôi viết, chưa được người bản ngữ rà soát.
- Ảnh của thẻ chỉ nằm trên thiết bị (và sao lưu iCloud/iTunes cùng app); không có trên server vì backend không hỗ trợ (§3).
- Bộ thẻ trên server không xuất hiện trong app (không có đồng bộ).
- Dữ liệu thử `DebugFixtures` chỉ có trong bản Debug (`-SeedCardsFixture`, chỉ khi thư viện trống); các ảnh trong thư mục này dùng nó để minh hoạ, còn luồng tạo/sửa/xoá/học được UI test chạy trên giao diện thật.
- SPM: `SwipeCellKit` và `CollectionViewPagingLayout` đã gỡ; nếu bản dựng phát hành dùng cache cũ, cần resolve lại package.
