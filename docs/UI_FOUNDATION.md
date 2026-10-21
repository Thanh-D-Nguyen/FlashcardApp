# Nền tảng giao diện (P0)

Phạm vi: token thiết kế, điều hướng 4 tab và màn Cấp độ/Nội dung cấp độ (`HomeViewController`).
Các màn khác (Từ điển, Thẻ, Cài đặt, tạo bộ thẻ) chưa được thiết kế lại.

Phân biệt rõ: **[HIG]** = hướng dẫn nền tảng của Apple, **[Yêu cầu]** = suy ra từ app,
**[Quyết định]** = lựa chọn thiết kế của dự án, chưa được kiểm chứng bằng nghiên cứu người dùng.
Các nguyên lý (giảm tải nhận thức, nhận biết thay vì nhớ lại, hiển thị dần) được dùng làm ràng
buộc thiết kế, không phải bằng chứng rằng giao diện này hiệu quả. Dự án chưa đo usability.

## Kết quả audit (trước khi sửa, quan sát trên iPhone 16 Pro, iOS Simulator)

| Vấn đề | Bằng chứng | Xử lý |
| --- | --- | --- |
| Giờ/pin status bar màu trắng trên nền sáng | Ảnh baseline light: `MainViewController` là root nhưng không chuyển `childForStatusBarStyle` cho tab controller | `MainViewController.childForStatusBarStyle = children.first` |
| Dải trắng dưới tab bar ở dark mode | `.white` cứng ở `MainTabbarController`, `BaseNavigationController`, `MainViewController`, `barTintColor` | Dùng token/`systemBackground`, bỏ `barTintColor` (dùng appearance mặc định) |
| Nhãn tab tiếng Anh (Home/Dictionary/Card) trong app tiếng Việt | `MainTabbarName.title` lấy khoá `NSLocalizedString` không có bản dịch | Nhãn tiếng Việt: Cấp độ, Từ điển, Thẻ, Cài đặt. `accessibilityIdentifier` giữ nguyên |
| Hàng cấp độ: tiêu đề, mô tả, số lượng cùng cỡ/màu, không phân cấp | Ảnh baseline | Vai trò chữ `.title` + `.reading` (secondary) |
| Trạng thái lỗi chỉ là chữ thường | `statusText` | Icon + màu lỗi + gợi ý thử lại |
| `AppColors` (asset catalog) có 20+ màu tuỳ biến (tím, cam, màu thẻ…) | Đang được màn Tạo bộ thẻ, Thẻ và Đăng nhập dùng (22 tham chiếu `AppColors.`) | Không dùng cho P0, không xoá; thống nhất ở P1 |
| `PlaceholderView` hardcode `.white`, frame thủ công, không Dynamic Type | Không có nơi nào gọi | Không dùng; ứng viên xoá ở P1 |

Chưa audit bằng hình ảnh: Từ điển, Thẻ, Bộ thẻ, Tạo bộ thẻ, Cài đặt (chỉ đọc mã nguồn các điểm chung).

## Token (`Commons/Utils/DesignSystem.swift`)

- **Màu**: nền `systemGroupedBackground`, bề mặt hàng `secondarySystemGroupedBackground`,
  chữ `label`/`secondaryLabel`, phân cách `separator`, nhấn `tintColor`. Dùng màu hệ thống nên
  tự theo light/dark/Increase Contrast **[HIG: Color, Dark Mode]**.
- **Trạng thái** (lỗi/thành công/cảnh báo): bản light tối hơn màu hệ thống vì `systemRed` trên
  nền trắng chỉ đạt 3,55:1 (tự tính theo công thức WCAG 2.x), dưới 4,5:1 cho chữ nhỏ. Giá trị light
  `#B3261E`/`#1E6B34`/`#8A4B00` đạt 6,5–6,8:1 trên trắng; bản dark dùng màu hệ thống
  (≥ 5:1 trên `#1C1C1E`). **[Quyết định]** Luôn kèm icon hoặc chữ, không chỉ dựa vào màu **[HIG: Color]**.
- **Khoảng cách**: lưới 4 pt (4/8/12/16/24). **[Quyết định]** Chỉ `xs` đang được dùng ở P0.
- **Bo góc/bóng/gradient**: không thêm. Hàng nằm trong `insetGrouped` gốc của hệ thống.
- **Điều hướng**: giữ `UITabBarController` + `UINavigationController`, không custom bar;
  thanh tab/nav dùng giao diện mặc định của hệ thống nên tự theo phiên bản iOS.

## Chữ Nhật (`Design.TextRole`)

Mọi vai trò dựa trên text style Dynamic Type (`preferredFont(forTextStyle:)`) và
`adjustsFontForContentSizeCategory`, số dòng không giới hạn (không cắt chữ) **[HIG: Typography, Dynamic Type]**.
Font hệ thống tự fallback sang Hiragino cho kana/kanji, nên không nhúng font.

| Vai trò | Text style | Dùng cho |
| --- | --- | --- |
| `title` | headline | Tên cấp độ, tiêu đề danh sách |
| `headword` | title3 | Từ vựng/kanji/mẫu ngữ pháp (dòng chính trong nội dung cấp độ) |
| `reading` | subheadline, secondary | Cách đọc kana; dòng phụ của hàng cấp độ |
| `meaning` | body | Nghĩa tiếng Việt (nhiều dòng) |
| `explanation` | body | Giải thích ngữ pháp |
| `metadata` | footnote, secondary | Số lượng, cấp JLPT, ghi chú |

Giới hạn đã biết:
- **Furigana**: nội dung API không cung cấp phiên âm theo từng ký tự, nên chưa hiển thị (không bịa dữ liệu).
- Chưa tuỳ chỉnh `lineHeightMultiple` cho dòng tiếng Nhật; dùng mặc định hệ thống. Cần kiểm tra bằng
  văn bản dài thật ở P1 trước khi chỉnh.
- `.reading`/`.meaning` hiện được dùng làm dòng phụ; `explanation` chưa có nơi dùng (chưa có màn ngữ pháp riêng).

## Component dùng chung

P0 **không** thêm component mới. Chỉ có màn Home dùng trạng thái đang tải/lỗi/trống, và nó
đã dùng hàng trạng thái sẵn có (`home_status`, giữ nguyên identifier cho UI test). Theo yêu cầu
"không tạo component khi chưa có nhiều màn cần", việc gom `EmptyState/ErrorState` chờ P1 khi
Từ điển và Thẻ cùng dùng.

## Kiểm chứng

Xem báo cáo cuối của P0 trong phiên làm việc: build, unit test, UI test và ảnh chụp thực tế.
Mục chưa kiểm chứng được ghi ở "Rủi ro còn lại" trong báo cáo đó.

## Đề xuất P1 (có phạm vi)

1. Áp dụng vai trò chữ và `Design.Color` cho Từ điển (kết quả có headword/reading/meaning thật).
2. Gom trạng thái tải/trống/lỗi thành một view dùng chung khi có ≥ 2 màn dùng; xoá `PlaceholderView` không dùng.
3. Audit trực quan (ảnh) Thẻ, Bộ thẻ, Tạo bộ thẻ, Cài đặt ở light/dark và cỡ chữ accessibility.
4. Khi thiết kế lại Thẻ/Tạo bộ thẻ, thay dần `AppColors` bằng `Design.Color` và kiểm tra tương phản light/dark của các màu tuỳ biến còn lại (kể cả storyboard/xib).
5. Đưa chuỗi tab/giao diện vào String Catalog thay vì chuỗi cứng.
6. Chưa làm: lặp lại ngắt quãng, theo dõi tiến độ (ngoài phạm vi theo yêu cầu).
