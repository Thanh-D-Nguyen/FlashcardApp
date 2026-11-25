# Design System Specification — FlashcardApp (2026-11-25)

Tài liệu này chốt hệ thống token, component và quy tắc bố cục dùng chung cho toàn bộ ứng dụng FlashcardApp trên nền UIKit (`DesignSystem.swift`, `StateView.swift`, `NoticeToastView.swift`, `CardSurfaceView.swift`). Mọi màn hình trong 7 slice triển khai đều kế thừa trực tiếp từ hệ token này, không tạo framework UI mới và không hardcode màu/bán kính/font tĩnh.

---

## 1. Hệ thống màu (`Design.Color`)

| Token | Light | Dark | Mục đích |
| --- | --- | --- | --- |
| `background` | `#F6F3ED` (giấy washi ấm) | `#0F0F10` | Nền toàn màn hình |
| `surface` | `#FFFFFF` | `#1C1C1E` | Bề mặt thẻ, nhóm nội dung, ô nhập |
| `surfaceElevated` | `#FFFFFF` | `#242426` | Khối nổi lồng trên `surface` ở Dark Mode |
| `surfaceTint` | `#ECE8DF` | `#242426` | Ô biểu tượng phụ, nền đệm nhẹ, tag trầm |
| `textPrimary` | `UIColor.label` | `UIColor.label` | Văn bản chính (WCAG AAA) |
| `textSecondary` | `UIColor.secondaryLabel` | `UIColor.secondaryLabel` | Mô tả, metadata, đọc âm (WCAG AA) |
| `placeholder` | `UIColor.placeholderText` | `UIColor.placeholderText` | Gợi ý trong ô nhập |
| `separator` / `border` | `UIColor.separator` | `UIColor.separator` | Đường ngăn & viền hairline 1pt |
| `accent` | `UIColor.tintColor` (`#23406B` / `#8FB4F0`) | `UIColor.tintColor` | Điểm nhấn chàm 藍 thống nhất toàn app |
| `onAccent` | `#FFFFFF` | `#0F0F10` | Chữ/icon trên nút nền `accent` (≥ 7:1 ở cả 2 chế độ) |
| `highlight` | `accent @ 10%` | `accent @ 10%` | Phản hồi chạm/chọn hàng |
| `hero` | `#23406B` | `#24406E` | Khối nổi bật duy nhất trên một màn hình |
| `heroDeep` | `#1B2F52` | `#1B2F52` | Chữ chàm đậm trên nút sáng đặt trên `hero` |
| `onHero` | `#F6F3ED` | `#F6F3ED` | Chữ/icon chính trên nền `hero` (≥ 8:1) |
| `onHeroSecondary` | `#F6F3ED @ 82%` | `#F6F3ED @ 82%` | Chữ phụ trên nền `hero` |
| `heroChipFill` | `#F6F3ED @ 16%` | `#F6F3ED @ 16%` | Nền chip/tag mờ đặt trên `hero` |
| `error` | `#B3261E` | `systemRed` | Lỗi (luôn kèm icon/chữ) |
| `success` | `#1E6B34` | `systemGreen` | Thành công (luôn kèm icon/chữ) |
| `warning` | `#8A4B00` | `systemOrange` | Cảnh báo / chuỗi ngày học (luôn kèm icon/chữ) |

- **Khử legacy**: `AppColors` trong `AppColor.swift` không còn force-unwrap asset màu (`UIColor(named:)!`), mà trỏ toàn bộ về `Design.Color` như lớp tương thích mỏng.
- **Viền `CGColor` động**: Mọi bề mặt dùng `layer.borderColor` bắt buộc gọi `applyCardSurface(...)` hoặc `observeAdaptiveBorder { ... }` để tự cập nhật `CGColor` khi chuyển Light/Dark.

---

## 2. Lưới khoảng cách & Hình khối (`Design.Spacing`, `Design.Radius`, `Design.HitTarget`)

- **Spacing (lưới 4pt)**: `xs = 4`, `s = 8`, `m = 12`, `l = 16`, `xl = 24`, `xxl = 32`, `gutter = 16`.
- **Corner Radius (5 cấp chuẩn, luôn dùng `.continuous`)**:
  - `panel = 28`: Khối hero chính, thẻ học flashcard.
  - `card = 20`: Thẻ nội dung, banner, hộp thông tin.
  - `control = 14`: Ô nhập liệu, nút phụ, thẻ gọn, nút dạng chữ nhật ở cỡ AX.
  - `chip = 12`: Chip lọc, ô kanji, tag nội dung.
  - `badge = 8`: Nhãn nhỏ, huy hiệu metadata.
- **Vùng chạm tối thiểu**: `Design.HitTarget.minimum = 44pt` trên cả hai trục cho mọi nút/control tương tác.

---

## 3. Hệ thống chữ (`Design.TextRole`)

- 100% text hiển thị dùng `Design.TextRole` hoặc `UIFontMetrics` + `adjustsFontForContentSizeCategory = true` + `numberOfLines = 0` (chữ Nhật/Việt không bị cắt ngang).
- Đã sửa `eyebrow` và `sectionTitle` sang `Design.TextRole.weighted(_:weight:)` (xây trên `UIFontMetrics`) để tự động phóng to/thu nhỏ theo Dynamic Type khi người dùng đổi cỡ chữ mà không cần khởi động lại app.
- Phân tách vai trò rõ:
  - **Tiêu đề biên tập / Kanji**: New York + cascade Hiragino Mincho (`display`, `articleTitle`, `entryHeadword`, `kanjiGlyph`, `numeral`, `numeralDisplay`, `heroFigure`).
  - **Nội dung học tập**: `headword` (`title2`), `sentence` (`title3`), `meaning`/`explanation` (`body`), `reading` (`subheadline`), `metadata` (`footnote`), `figure` (tabular `footnote` semibold).

---

## 4. Nút bấm & Component dùng chung (`Design.Button`, `StateView`, `NoticeToastView`)

- **Adaptive Corner Style (`Design.Button.cornerStyle(for:)`)**:
  - Ở cỡ chữ thường: dùng `.capsule` tạo cảm giác gọn, thân thiện.
  - Ở cỡ chữ Accessibility (`isAccessibilityCategory == true`): tự chuyển sang `.large` (bo góc chữ nhật mềm) thông qua `enableAdaptiveCornerStyle()`, chấm dứt tình trạng nút phình thành khối bầu dục khổng lồ.
- **Chuẩn hoá 4 mẫu nút**:
  1. `Design.Button.primary(title:systemImage:traits:)`: Hành động chính duy nhất trên màn.
  2. `Design.Button.secondary(title:systemImage:traits:)`: Hành động thứ cấp trên nền `surface` + viền hairline `border`.
  3. `Design.Button.surfaceChip(title:systemImage:selected:traits:)`: Chip lọc / nút hành động nhỏ thay cho `.gray()` xám đục.
  4. `Design.Button.hero(title:traits:)`: Nút chính trên khối `hero` (tự bỏ mũi tên ngang ở cỡ AX để ưu tiên độ rộng chữ).
- **`StateView`**:
  - Bọc nội dung trong `UIScrollView` nên không bao giờ bị cắt ở cỡ AX.
  - Bổ sung `topContentInset` cho các màn gắn `StateView` vào `tableView.backgroundView` dưới header/search bar (như Cards Library).
  - Tự động kích hoạt `enableAdaptiveCornerStyle()` cho nút hành động/thử lại.
- **`NoticeToastView`**:
  - Thành phần duy nhất cho thông báo ngắn cuối màn (kèm thông báo VoiceOver `.announcement`), thay thế toàn bộ toast tự chế ở từng màn (như `PaddedToastLabel` của Loto).
