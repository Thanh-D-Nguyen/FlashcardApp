# UI/UX Overhaul Audit — FlashcardApp (2026-11-25)

- **Branch**: `uiux-overhaul-2026-11-25` (rebased onto `main` `bcd2608`, base commit `a3ff883`)
- **Simulator**: iPhone 17 (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS 27.2)
- **Language**: Vietnamese (`vi`)
- **Modes audited**: Light (`large`), Dark (`large`), Accessibility Extra-Extra-Large (`accessibility-extra-extra-large`)
- **Data sources**: `FlashcardApp-Production` (`https://kiokoto.com/api`, read-only live content) + `FlashcardApp-Local` (`-SeedCardsFixture` for offline populated decks & `CardStudy`)

---

## 1. Thống kê tổng quan vấn đề theo mức độ

| Mức độ | Số lượng | Tóm tắt |
| --- | ---: | --- |
| **P0 (Nghiêm trọng)** | 8 | Crash khi mở Magazine (`UICollectionViewDiffableDataSource` re-entrant apply); lỗi tương phản Dark Mode ở `LifeSceneView` (Today); vỡ/đè/cắt layout ở cỡ chữ AX tại Today, Home Content, Cards Library, CardStudy, Discover, Loto. |
| **P1 (Cao)** | 11 | Token legacy (`AppColors`, `PlaceholderView`); bán kính bo góc rời rạc (`12–28pt`); nút `.capsule` phình thành khối lớn ở cỡ AX; vùng chạm `< 44pt`; 5 màn thiếu `UIScrollView` tràn ở cỡ AX; chiều cao cố định bị cắt; `CGColor` không cập nhật khi đổi Light/Dark; font tĩnh không theo Dynamic Type; thiếu `StateView` đồng nhất. |
| **P2 (Trung bình)** | 7 | Phân cấp thị giác cạnh tranh (Today Scenario banner vs TodayHero, Discover Hero vs Loto Hero); nhãn/chip màu xám đục trên nền washi; toast tự chế ở Loto thay vì `NoticeToastView`; lệch bo góc nút Sign in with Apple; danh sách Lesson đơn điệu thiếu phân cấp Nhật/Việt. |

---

## 2. Danh sách ảnh hiện trạng (`before/`)

- **Today**: `before/today_light.png`, `before/today_dark.png`, `before/today_ax.png`, `before/today_scroll_light.png`
- **Home / Levels**: `before/home_levels_light.png`, `before/home_levels_dark.png`, `before/home_levels_ax.png`
- **Home / Level Content**: `before/home_content_light.png`, `before/home_content_dark.png`, `before/home_content_ax.png`
- **Lesson List & Reader**: `before/lesson_list_light.png`, `before/lesson_list_dark.png`, `before/lesson_list_ax.png`, `before/lesson_reader_light.png`, `before/lesson_reader_dark.png`, `before/lesson_reader_ax.png`
- **Dictionary**: `before/dictionary_empty_light.png`, `before/dictionary_results_light.png`, `before/dictionary_results_dark.png`, `before/dictionary_results_ax.png`
- **Dictionary Entry (Vocab & Kanji)**: `before/dictionary_entry_vocab_light.png`, `before/dictionary_entry_vocab_dark.png`, `before/dictionary_entry_vocab_ax.png`, `before/dictionary_entry_kanji_light.png`, `before/dictionary_entry_kanji_dark.png`, `before/dictionary_entry_kanji_ax.png`
- **Cards Library (Empty & Seeded) & Review**: `before/cards_library_light.png`, `before/cards_library_dark.png`, `before/cards_library_ax.png`, `before/cards_library_seeded_light.png`, `before/cards_library_seeded_dark.png`, `before/cards_library_seeded_ax.png`, `before/cards_review_light.png`, `before/cards_review_dark.png`
- **Card Study**: `before/card_study_light.png`, `before/card_study_dark.png`, `before/card_study_ax.png`
- **Discover**: `before/discover_light.png`, `before/discover_dark.png`, `before/discover_ax.png`
- **Magazine**: *Không thể chụp trước khi sửa* — app crash ngay khi mở do lỗi P0 `BUG_IN_CLIENT_OF_DIFFABLE_DATA_SOURCE__APPLYING_SNAPSHOTS_REENTRANTLY_OR_ON_MAIN_AND_BACKGROUND_THREADS` tại `MagazineViewController.swift:219-224`.
- **Loto**: `before/loto_light.png`, `before/loto_dark.png`, `before/loto_ax.png`
- **Settings**: `before/settings_light.png`, `before/settings_dark.png`, `before/settings_ax.png`
- **MailLogin**: `before/maillogin_light.png`, `before/maillogin_dark.png`, `before/maillogin_ax.png`

---

## 3. Kiểm toán chi tiết theo hệ thống dùng chung & từng màn hình

### 3.0 Design System & Shared Components
- **[P1] Trùng lặp hệ token màu legacy**: `FlashcardApp/Commons/Utils/AppColor.swift` force-unwrap asset màu (`UIColor(named: ...)!`) song song với `Design.Color`; `MailLoginPresenter.swift:51` vẫn tham chiếu `AppColors.placeholderText`.
- **[P1] Thiếu token bán kính & control chuẩn**: `Design.Radius` hiện chỉ có `panel = 28`; các màn hardcode rải rác `12, 14, 16, 18, 20, 22, 24, 28`.
- **[P1] Nút `.capsule` biến dạng ở Dynamic Type AX**: `Design.Button.primary` luôn dùng `cornerStyle = .capsule`. Khi chữ bọc thành 2–3 dòng ở cỡ AX, nút biến thành khối bầu dục khổng lồ chiếm quá nhiều chiều cao (`cards_library_ax.png`, `card_study_ax.png`).
- **[P1] `StateView` không cuộn và đè header**: `StateView.swift:40-46` neo `stack.centerYAnchor` trực tiếp lên `safeAreaLayoutGuide` không bọc `UIScrollView`, dẫn tới va chạm với search bar và sticky header ở cỡ AX (`cards_library_ax.png`).
- **[P1] `PlaceholderView.swift` legacy**: Hardcode `.white`, `.systemGray` và manual frame layout, không dùng `Design.Color` hay Dynamic Type.

### 3.1 Main & Today (`Modules/Main`, `Modules/Today`)
- **[P0] Dark Mode contrast thất bại ở `LifeSceneView.swift`** (`before/today_dark.png`): Số ngày `"25"` trong khung lịch dùng màu chàm tối `#23406B` trên nền xanh đậm → độ tương phản ~1.4:1, gần như không đọc được. Nhiều giá trị `UIColor(red:...)` trong `LifeSceneView` cố định theo Light Mode.
- **[P0] Vỡ layout AX ở `TodayLifeHubView.swift`** (`before/today_ax.png`):
  - Hàng `bar` (`Hôm nay ở Nhật` + nút `Tokyo`) giữ trục ngang ở cỡ AX → `"Tokyo"` bị ngắt giữa từ thành `"Toky\no"`.
  - Huy hiệu `● TRỰC TIẾP` (`badgeBox`) phóng to và đè trực tiếp lên chữ số `"25"` trong `scene` có chiều cao cố định `120pt`.
  - `TodayDateHeaderView` giữ trục ngang với ô ngày cố định `56x64` và font tĩnh (`systemFont(ofSize: 11)`, `HiraMinProN-W6` 32pt), ép dòng lịch Reiwa xuống 4 dòng hẹp.
- **[P1] Vùng chạm `< 44pt`**: `TodayHeroView.titleControl` và `TodayLifeHubView.cityButton` không bảo đảm chiều cao tối thiểu 44pt.
- **[P1] `TodayRowView` không xếp dọc ở cỡ AX**: Nội dung dài bị ép ngang bên cạnh icon/chevron.
- **[P2] Phân cấp thị giác cạnh tranh** (`before/today_scroll_light.png`): `TodayScenarioBannerView` dùng nền gradient xanh đậm + nút primary đặc cạnh tranh trực tiếp với `TodayHeroView`; `LifeTopicCardView` còn khoảng trắng thừa ~45pt ở đáy do chênh chiều cao giữa 2 thẻ cùng hàng; `TodayStreakView` dùng `.systemOrange` thay vì `Design.Color.warning`.

### 3.2 Home / Levels & Level Content (`Modules/Home`)
- **[P0] Cắt chữ theo chiều dọc trên nút `Bài học` ở cỡ AX** (`before/home_content_ax.png`, `HomeViewController.swift:130-142`): Nút `lessonsButton` bị cắt mất biểu tượng sách và dấu nặng dưới chữ `"ọ"` do dùng nút `.tinted()` mặc định không set kích thước/cấu hình phù hợp và `sizeHeaderToFit` chưa phản ứng khi đổi cỡ chữ.
- **[P1] Vùng chạm `< 44pt`**: `HomeViewController.lessonsButton` (~34pt ở cỡ thường) và các nút trong `LevelKindStrip` không khai báo `height >= 44pt`.
- **[P1] Font cứng & CTA chưa tối ưu AX** (`HomeCells.swift`): `FeaturedLevelCell` hardcode `UIFont.systemFont(ofSize: 22, weight: .semibold)` cho tiêu đề và giữ mũi tên ngang trên CTA ở cỡ AX.
- **[P2] Nút `Bài học` thiếu tín hiệu điều hướng** (`before/home_content_light.png`): Trông giống hộp xám phẳng, không có chevron hoặc bề mặt thẻ phân biệt.

### 3.3 Dictionary & Entry / Saved / Scan / Voice / Handwriting (`Modules/Dictionary*`)
- **[P1] Cắt nội dung & không reflow khi đổi Dynamic Type** (`DictionaryResultCell.swift`): `third.numberOfLines = 3` gây cắt chữ ở cỡ AX (`before/dictionary_results_ax.png`); `rowStack.axis` chỉ kiểm tra trong `configure`, không đăng ký `UITraitPreferredContentSizeCategory`.
- **[P1] Footer chiều cao cố định**: `DictionaryViewController.footerView()` (`56pt`) và `DictionarySavedViewController.footer()` (`64pt`) sẽ cắt chữ ở cỡ AX.
- **[P1] Segmented control trong `titleView` bị cắt ở AX**: `DictionarySavedViewController` đặt 3-segment `UISegmentedControl` vào `navigationItem.titleView` thay vì chuyển sang bar button menu ở cỡ AX.
- **[P1] Màn phụ thiếu `UIScrollView` & vùng chạm `< 44pt`**: `DictionaryVoiceViewController` và `DictionaryScanViewController` đặt stack trực tiếp trên `view`; `DictionaryHandwritingViewController` dùng `candidateScroll` cố định `60pt` và `backspaceButton` chưa bảo đảm `>= 44x44pt`.
- **[P2] Bề mặt nút & chip chưa sắc nét** (`before/dictionary_entry_vocab_light.png`, `before/dictionary_entry_kanji_light.png`): Các nút hành động và chip kanji dùng `.gray()` tạo nền xám đục trên nền giấy washi thay vì `Design.Color.surface` + viền hairline; `DictionaryQueryCell` thiếu `Design.Color.highlight` khi chạm.

### 3.4 Cards, Study, Review, RemoteDeck, CreateDesk (`Modules/Card*`, `CreateDesk`, `RemoteDeck`, `SharedDeck`, `OftenMissed`, `DeckGenerator`, `ExampleEditor`, `CardStyle`)
- **[P0] Va chạm trực tiếp giữa `StateView` và header ở AX** (`before/cards_library_ax.png`): Khi danh sách rỗng ở cỡ AX, `StateView` đặt ở `tableView.backgroundView` bị đè chồng lên thanh tìm kiếm và `CardScopeHeaderView` (`Ôn tập` / `Của tôi`).
- **[P0] `CardScopeHeaderView` cố định chiều cao `60pt`** (`CardLibraryViews.swift`, `before/cards_library_seeded_ax.png`): `heightForHeaderInSection` trả về hằng số `60`, khiến các chip phạm vi bị bó sát/cắt viền ở cỡ AX.
- **[P0] Đáy thẻ `StudyCardView` bị cắt phẳng và nút `Hiện đáp án` biến dạng ở AX** (`before/card_study_ax.png`): Nút `Hiện đáp án` phình lớn với `.capsule` ép vùng thẻ co lại làm mất góc bo dưới của thẻ học.
- **[P1] Màn phụ thiếu `UIScrollView` / `StateView` / chuẩn nút**: `KanjiWritingViewController` và `SharedDeckViewController` không bọc `UIScrollView`, chưa dùng `StateView` cho trạng thái loading/empty/error và còn dùng nút `.bordered()` thô.
- **[P1] `DeckLibraryCell.previewLabel`** dùng font cố định không scale theo Dynamic Type (`before/cards_library_seeded_ax.png`).
- **[P2] Thanh điều hướng Cards dày đặc** (`before/cards_library_seeded_light.png`): 4 nút bar button phải đặt liền kề (cần bảo toàn `create_deck_button` và `often_missed_button` do `FlashcardAppUITests` tham chiếu trực tiếp, đồng thời tổ chức gọn nút phụ `Sắp xếp` / `Chia sẻ`).

### 3.5 Discover, Magazine, Loto (`Modules/Discover`, `Modules/Magazine`, `Modules/Loto`)
- **[P0] Crash khi mở Magazine** (`MagazineViewController.swift:219-224`): `collectionView(_:willDisplay:forItemAt:)` gọi `presenter.loadMore()` đồng bộ ngay trong lúc `dataSource.apply(snapshot)` đang chạy → crash UIKit assertion `BUG_IN_CLIENT_OF_DIFFABLE_DATA_SOURCE__APPLYING_SNAPSHOTS_REENTRANTLY_OR_ON_MAIN_AND_BACKGROUND_THREADS`.
- **[P0] Cắt chữ `DiscoverFindCard` ở AX** (`before/discover_ax.png`, `DiscoverHeroViews.swift:128`): Giữ bố cục ngang `[icon, text, spacer, seal]` khiến tiêu đề `"Phát hiện h..."` bị cắt ngắn.
- **[P0] Cắt chữ đồng hồ đếm ngược Loto ở AX** (`before/loto_ax.png`, `LotoViews.swift:71-74, 158-198`): 4 ô đếm ngược nằm cố định 1 hàng ngang khiến đơn vị bị cắt thành `"ng... | giờ | ph... | gi..."` (cần chuyển sang lưới 2×2 ở AX).
- **[P1] Viền `CGColor` không cập nhật khi đổi Light/Dark**: `MagazineArticleViews.swift` (`tag()`, `QuizOptionControl`) gán `.cgColor` một lần mà không theo dõi `UITraitUserInterfaceStyle`.
- **[P2] Phân cấp thị giác & đồng nhất thành phần** (`before/discover_light.png`, `before/discover_dark.png`, `before/loto_light.png`):
  - Hai khối chàm đậm (`DiscoverHeroView` và thẻ nổi bật Loto) xếp chồng nhau gây cạnh tranh điểm nhìn; thẻ tag trong Loto card dùng nền `Design.Color.background` (thành viên thuốc đen trên chàm ở Dark Mode).
  - `LotoViewController` tự tạo `PaddedToastLabel` (hardcode nền đen/chữ trắng) thay vì dùng `NoticeToastView`.

### 3.6 Lesson & Today-Life Modules (`Modules/LessonList`, `LessonReader`, `LessonPractice`, `Shadowing`, `LifeLesson`, `Scenario`, `DailyRadarCard`)
- **[P1] Thiếu `UIScrollView`, `StateView` và vùng chạm `< 44pt`**: `ShadowingViewController` không có `UIScrollView`, không dùng `StateView`, các nút control không theo `Design.Button` / 44pt.
- **[P1] Thanh chip chiều cao cố định `52pt`**: `ScenarioListViewController.chipScroll` cố định `height = 52`, cắt chip khi cỡ chữ AX.
- **[P1] Viền `CGColor` tĩnh trong Dark Mode**: `LifeLessonViewController` (`tag()`, `choiceButton()`) và `ScenarioPlayViewController` (`ScenarioChoiceControl`) không cập nhật `borderColor` khi đổi appearance.
- **[P2] Phân cấp danh sách & trình đọc bài học** (`before/lesson_list_light.png`, `before/lesson_reader_light.png`): `LessonList` và `LessonReader` dùng row đơn sắc phẳng, chưa phân tách rõ bề mặt thẻ câu, phân cấp Nhật/Việt và phản hồi chạm `Design.Color.highlight`.

### 3.7 Settings, MailLogin, StartUp, DataExport (`Modules/Setting`, `MailLogin`, `StartUp`, `DataExport`)
- **[P1] `DataExportViewController` thiếu `UIScrollView`, `StateView` và `Design.Button`**: Bố cục cố định trực tiếp trong `view`, có nguy cơ tràn ở cỡ AX.
- **[P1] Font cứng & hit target ở Settings** (`AccountCell.swift`, `before/settings_ax.png`): Tên tài khoản dùng `UIFont.systemFont(ofSize: 20, weight: .semibold)` không tối ưu qua `Design.TextRole`, nút `Đăng nhập` giữ `.capsule` ở AX, `menuButton` cần bảo đảm `>= 44x44pt`.
- **[P1] Legacy `AppColors.placeholderText` ở `MailLoginPresenter.swift:51`**.
- **[P2] Lệch hình khối nút ở `MailLogin`** (`before/maillogin_light.png`, `before/maillogin_dark.png`, `before/maillogin_ax.png`): `ASAuthorizationAppleIDButton` có bo góc ~6pt trong khi 3 nút anh em là capsule toàn phần; ấn dấu `単` giữ kích thước cứng `40x40` / `22pt` khi chữ `Flashcard` phóng to ở cỡ AX; các nút cần đổi góc bo `.large` ở cỡ AX để tránh phình bầu dục.

---

## 4. Kế hoạch triển khai nối tiếp

1. **Design System**: Chuẩn hoá `DesignSystem.swift`, `AppColor.swift`, `StateView.swift`, `PlaceholderView.swift` và tài liệu hoá tại `DESIGN_SYSTEM.md`.
2. **Triển khai 7 slice tuần tự**: `(a) Main/Today` → `(b) Home/Levels` → `(c) Dictionary` → `(d) Cards` → `(e) Discover/Magazine/Loto` → `(f) Lesson & Today-life` → `(g) Settings/MailLogin/StartUp`.
3. Mỗi slice: sửa code → build → chạy unit tests liên quan + `LocalizationTests` → chụp ảnh `after/` (Light, Dark, AX) → commit & push.
