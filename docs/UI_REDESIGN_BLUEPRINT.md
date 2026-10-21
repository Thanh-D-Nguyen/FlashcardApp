# UI redesign — nền tảng giao diện, shell và màn Cấp độ (P1)

Phạm vi: deployment target iOS 26, design system, shell/tab bar, màn Cấp độ và Nội dung cấp độ
(`HomeViewController`). Từ điển, Thẻ, Tạo bộ thẻ, Cài đặt **chưa** thiết kế lại (xem "Việc còn lại").

Nhãn nguồn: **[HIG/Apple]** tài liệu nền tảng · **[Bằng chứng]** nguyên lý UX/nhận thức đã được
nghiên cứu · **[Giả thuyết]** quyết định thiết kế chưa kiểm chứng với người dùng · **[Gu]** ưu tiên thẩm mỹ.
Dự án chưa đo usability; các nguyên lý dưới đây là ràng buộc thiết kế, không phải chứng minh hiệu quả.

## 1. Nghiên cứu (nguồn chính, đã đọc)

| Phát hiện | Loại | Áp dụng |
| --- | --- | --- |
| iOS 26: tab bar/nav bar là Liquid Glass, trong suốt mặc định; `UIBarAppearance`/`backgroundColor` tuỳ biến làm hỏng hiệu ứng; nội dung nên chạy xuống dưới bar, scroll-edge effect tự xử lý độ đọc (WWDC25 "Build a UIKit app with the new design") | HIG/Apple | Không đặt nền cho bar. Container tab bar full-bleed; bảng kéo sát mép màn hình |
| `tabBarMinimizeBehavior` cho phép thu gọn tab bar khi cuộn | HIG/Apple | **Không dùng**: chỉ 4 tab, thu gọn làm mất nhãn (giảm nhận diện) |
| Dynamic Type 12 cỡ; tiêu đề phải luôn lớn hơn phần mô tả; mục nhỏ nhất vẫn phải co giãn | HIG/Apple | Mọi vai trò chữ dựa trên text style; bố cục đổi trục ở cỡ accessibility |
| Vùng chạm tối thiểu 44×44 pt | HIG/Apple | Hàng cấp độ ≥ 88 pt; nút `Thử lại` dùng `buttonSize = .large` |
| Tương phản chữ thường ≥ 4,5:1 (WCAG AA — kiến thức, chưa đối chiếu lại trang WCAG trong phiên này) | Bằng chứng | Chàm light 7,9:1 / dark 9,1:1 (tự tính); chữ phụ ≈ 4,7:1 |
| Giảm tải nhận thức, Hick–Hyman (ít lựa chọn đồng thời), Fitts (đích lớn), Gestalt (gần = liên quan), nhận biết thay vì nhớ lại | Bằng chứng | 6 hàng cấp độ cùng cấu trúc; bộ chọn Từ vựng/Kanji/Ngữ pháp luôn hiển thị |
| Một màu nhấn duy nhất, chữ Nhật cần nền yên tĩnh | Giả thuyết/Gu | Nền giấy washi + chàm 藍 |

Không có nghiên cứu người dùng riêng cho app này; không bịa số liệu tiến độ, streak hay SRS.

## 2. Ba hướng và lựa chọn

| Tiêu chí | A. Apple tối giản | B. Biên tập Nhật | C. Học tập |
| --- | --- | --- | --- |
| Đọc chữ Nhật | tốt (mặc định) | tốt nếu nền yên tĩnh, serif chỉ cho ký hiệu | trung bình (nhiều thành phần) |
| Đúng nền tảng | cao nhất | cao nếu giữ bar gốc | thấp (dễ thành dashboard) |
| Nhận diện riêng | thấp | **cao** | trung bình |
| Truy cập | tốt | tốt | rủi ro (nhiều màu/huy hiệu) |
| Độ phức tạp/bảo trì | thấp | thấp | cao, và cần dữ liệu tiến độ chưa tồn tại |

**Chọn A + B**: khung điều hướng/điều khiển hoàn toàn native (Liquid Glass, large title, segmented, UIButton
configuration); chữ và khoảng cách theo tinh thần biên tập Nhật (nền giấy ấm, ký hiệu cấp độ bằng serif,
đường kẻ mảnh thay vì thẻ nổi). C bị loại vì phụ thuộc dữ liệu tiến độ không có thật.

## 3. Quyết định design system (`Commons/Utils/DesignSystem.swift`)

- **Màu**: `background` giấy `#F6F3ED` / dark `#0F0F10`; `surface` trắng / `#1C1C1E`; nhấn **chàm** `#2A4B7C` / dark `#8FB4F0` qua
  `AccentColor.colorset` (tint toàn app: tab chọn, link, nút). Màu trạng thái giữ như P0 (đỏ/xanh/cam tối hơn ở light).
  Đỏ lỗi ≠ màu nhấn nên không nhầm "lỗi" với "đang chọn".
- **Chữ**: thêm `mark` (serif, `largeTitle`, màu nhấn — ký hiệu J5/J1+) và `figure` (số cách đều, semibold). `headword` nâng
  `title3 → title2`. Tiếng Việt và tiếng Nhật dùng cùng text style; font hệ thống tự fallback Hiragino.
- **Khoảng cách**: thêm `xxl = 32`, `gutter = 16` (thẳng hàng với large title).
- **Điều khiển**: `Design.Button.primary(title:)` (`borderedProminent`, capsule, 44 pt+). Chỉ một nơi dùng (StateView) — không tạo
  thêm style cho đến khi có màn thứ hai.
- **Trạng thái**: `StateView` (tải/trống/lỗi) dùng cho cả danh sách cấp độ và nội dung cấp độ; luôn có icon/spinner + chữ.
- Không thêm bo góc, bóng, gradient hay blur tự dựng. Bar giữ giao diện hệ thống.
- Không dùng test cho giá trị màu/khoảng cách.

## 4. Cấu trúc điều hướng

`MainViewController` (storyboard, container full-bleed) → `MainTabbarController` (`UITabBarController` hệ thống) → bốn tab,
giữ nguyên thứ tự, route và identifier (`tab_levels/dictionary/cards/settings`):

| Tab | Nhãn | Icon (thường / chọn) |
| --- | --- | --- |
| 1 | Cấp độ | `graduationcap` / `.fill` |
| 2 | Từ điển | `character.book.closed` / `.fill` |
| 3 | Thẻ | `rectangle.stack` / `.fill` |
| 4 | Cài đặt | `gearshape` / `.fill` |

`MainTabbarName.tabBarItem` là nguồn duy nhất cho tiêu đề/icon/tag (trước đó 4 wireframe tự dựng riêng).
`BaseNavigationController`: large title, bar mặc định hệ thống (không `UIBarAppearance`), vẫn ẩn bar mặc định cho Thẻ/Cài đặt.
Status bar luôn `.default` (tự theo light/dark); đã bỏ biến toàn cục `Constants.currentBarStyle`.

## 5. Đặc tả màn Cấp độ

- Large title **Cấp độ** + một dòng hướng dẫn. Mỗi cấp độ là một hàng phẳng (không thẻ nổi, đường kẻ mảnh):
  ký hiệu serif màu chàm (`J5`) · tên tiếng Việt (`Sơ cấp`) · mô tả · `574 từ vựng · 79 kanji · 194 ngữ pháp` (số cách đều, định dạng
  `vi_VN`). Tên được tách khỏi tiền tố mã (`"J5 — Sơ cấp"` → mã + `Sơ cấp`); backend không đổi.
- Cấp độ không có dữ liệu (J1+ hiện 0/0/0) hiển thị `Chưa có nội dung` thay vì ba số 0; vẫn mở được như trước.
- Chạm: nền nhấn chàm 10%; cell là một phần tử VoiceOver ("J5, Sơ cấp, mô tả, 574 từ vựng, …").
- Cỡ chữ accessibility: ký hiệu chuyển lên trên văn bản (trục dọc).
- **Nội dung cấp độ**: title inline; segmented `Từ vựng | Kanji | Ngữ pháp` + tổng số của mục đang chọn (từ dữ liệu cấp độ);
  ở cỡ accessibility segmented ẩn và dùng menu trên nav bar (cùng identifier `level_content_kind`). Hàng: từ → cách đọc → nghĩa.
- Trạng thái: tải / trống / lỗi + `Thử lại` toàn vùng khi chưa có hàng; hàng chân trang cho "tải thêm" và lỗi trang sau (như cũ).
- Đã bỏ `UITableView.insetGrouped`; bảng sát mép để nội dung trượt dưới glass bar.

## 6. Ràng buộc kiến trúc (giữ nguyên)

View chỉ vẽ và chuyển sự kiện; `HomePresenter` giữ trạng thái và huỷ request (`cancelLoading` ở `viewWillDisappear`);
`HomeInteractor` ánh xạ DTO; điều hướng trong `HomeWireframe`. `HomeRow` thêm trường tuỳ chọn (có mặc định) nên mọi nơi gọi cũ
còn biên dịch. Không đụng API, DTO, Realm, Keychain, `AuthSession`. File mới đã thêm vào target `FlashcardApp`:
`Commons/Views/StateView.swift`, `Modules/Home/Cells/HomeCells.swift`.

## 7. Bằng chứng kiểm chứng

Môi trường: Xcode 27.2, iPhone 17 Pro, iOS 26.5 Simulator, scheme `FlashcardApp-Local`, backend local đang chạy (`/api/levels` 200).

| Kiểm tra | Kết quả |
| --- | --- |
| Build deployment target 26.0 (Realm, RxSwift, Alamofire, Kingfisher, SwipeCellKit, CollectionViewPagingLayout) | SUCCEEDED |
| Unit test `FlashcardAppTests` | 84/84 passed (gồm 3 test mới cho Home) |
| UI test `FlashcardAppUITests` (backend local thật, gồm test cỡ chữ accessibility và 4 tab) | 6/6 passed |
| Chụp ảnh thật | Light, Dark, Accessibility XXXL, trạng thái lỗi (API trỏ cổng đóng); 4 tab + Nội dung cấp độ (Từ vựng, Kanji) |

Ảnh (từ app đang chạy, không phải mockup) trong `docs/ui-redesign/`: `home_light/dark/ax_xxxl`, `home_error_light`, `content_light`,
`content_kanji_dark`, `content_ax_xxxl`, `dictionary_light`, `cards_light`, `settings_light`. Ảnh gốc P0 ở `docs/ui-p0/`.

Review độc lập (agent `flashcard-reviewer`, chỉ đọc mã, không build): 3 lỗi được xác nhận và đã sửa — font serif/số bị scale hai lần ở
cỡ chữ lớn (sửa bằng cỡ cơ sở Large + `UIFontMetrics`, kiểm lại bằng ảnh XXXL), tiêu đề Thẻ trắng trên nền cố định sáng ở Dark Mode,
header bảng không đo lại khi đổi mục. Hai góp ý nhỏ về `StateView` (ràng buộc đáy, thông báo VoiceOver) cũng đã áp dụng.

Quan sát khi chụp: dữ liệu backend local chứa bản ghi fixture (`audit141 lexeme <uuid>`); đó là dữ liệu, không phải lỗi giao diện.

Chưa kiểm chứng: VoiceOver trên thiết bị thật, Reduce Motion, iPad, thiết bị thật, iOS 27, Increase Contrast, màn hình nhỏ (iPhone SE).

## 8. Việc còn lại cho các milestone sau

1. **Thẻ** (`Card.storyboard`, `CardView.xib`): nền xanh nhạt cố định (màn vẫn sáng ở Dark Mode; chỉ sửa tiêu đề cho đọc được), ô chọn bộ thẻ viền tím `AppColors`, chưa theo token; Tạo bộ thẻ, Danh sách bộ thẻ cùng vấn đề.
2. **Cài đặt**: chuỗi tiếng Anh (Preferences, Sign In…), icon màu hệ thống; cần String Catalog và token.
3. **Từ điển**: chỉ sửa nền; hàng kết quả vẫn dùng `subtitle` mặc định, nút làm mới đơn lẻ trên nav bar; nên dùng `StateView` thay `message`.
4. `PlaceholderView` không dùng (ứng viên xoá); `AppColors` còn tham chiếu ở Thẻ/Tạo bộ thẻ.
5. Cảnh báo deprecated iOS 26 ngoài phạm vi: `UIScreen.main` (`ListFlowLayout`, `GridFlowLayout`, `FadingEdgeCollectionView`).
6. Furigana chưa có trong dữ liệu API; chưa chỉnh `lineHeightMultiple` cho đoạn tiếng Nhật dài.
7. Chưa có UI test cho trạng thái lỗi/trống của Home (đã kiểm bằng ảnh, không có test tự động).
