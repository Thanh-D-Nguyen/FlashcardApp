# Báo cáo Đại tu UI/UX Toàn Ứng dụng FlashcardApp (2026-11-25)

- **Branch:** `uiux-overhaul-2026-11-25` (rebased trên `main` mới nhất `bcd2608`, giữ nguyên commit `REVIEW.md` tại `a3ff883`)
- **Worktree:** `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul`
- **Simulator kiểm chứng:** iPhone 17 (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS 27.2)
- **Phạm vi tuân thủ ràng buộc:** Giữ nguyên kiến trúc VIPER (`View -> Presenter -> Interactor`), UIKit, cấu trúc 5 tab và luồng điều hướng, toàn bộ nghiệp vụ, schema Realm 7, API/DTO/auth/signing; không thêm dependency mới; không viết lại SwiftUI; không chèn quảng cáo vào màn học/ôn thẻ; toàn bộ text dùng `NSLocalizedString` + `Localizable.xcstrings` (`LocalizationTests` 10/10 pass).

---

## 1. Tổng hợp tiến trình & lịch sử commit

| Pha / Slice | Commit | Mô tả chính |
|---|---|---|
| Review (giữ từ branch cũ) | `a3ff883` | `docs(review): record adversarial review verdict for uiux-overhaul-2026-11-25` |
| Audit + Before | `76ebd66` | Chụp 49 ảnh hiện trạng (Light/Dark/AX-XXL) tại `before/` và lập `AUDIT.md` (8 P0, 11 P1, 7 P2) |
| Design System | `74295ad` | Hợp nhất token (`Design.Color`, `Design.Radius`, `Design.HitTarget`, `Design.TextRole`, `Design.Button`), chuẩn hoá `AppColor`, nâng cấp `StateView` cuộn được + `topContentInset`, viết `DESIGN_SYSTEM.md` |
| Slice (a) — Main & Today | `fa82d1a` | Sửa lỗi P0 tương phản Dark Mode ở `LifeSceneView`, vỡ layout AX ở `TodayLifeHubView`/`TodayDateHeaderView`/`TodayScenarioBanner`/`TodayRowView`, loại bỏ khoảng trắng thừa trong thẻ Life |
| Slice (b) — Home/Levels | `dabde61` | Sửa lỗi P0 cắt chữ nút `Bài học` ở AX bằng `LevelLessonsRowControl`, đồng bộ target chạm `>= 44pt`, chuẩn hoá `sizeHeaderToFit()` và `stateView.topContentInset` |
| Slice (c) — Dictionary + Entry/Saved/Scan/Voice/Handwriting | `8fbe9e8` | Sửa lỗi tràn/cắt chữ ở AX (`DictionaryResultCell`, `DictionarySavedViewController` chuyển sang bar button menu ở AX), thay thế các nút `.gray()` mờ đục bằng surface + viền mảnh, bổ sung `UIScrollView` cho Scan/Voice, target `>= 44pt` cho Handwriting |
| Slice (d) — Cards + CardStudy/CardReview/RemoteDeck/CreateDesk | `1803b54` | Sửa lỗi P0 `StateView` đè lên search/scope bar ở AX, tự co giãn chiều cao `CardScopeBar`, bố cục 2 hàng cho nút học ở AX trong `CardStudyViewController`, `UIScrollView` + `StateView` cho `KanjiWriting` và `SharedDeck` |
| Slice (e) — Discover / Magazine / Loto | `9e4ca24` | Sửa lỗi crash P0 re-entrant `UICollectionViewDiffableDataSource.apply` của Magazine (+ regression unit test), sửa P0 cắt chữ đếm ngược Loto ở AX bằng lưới 2×2, sửa P0 cắt chữ thẻ niêm phong Discover ở AX và chip đen trên nền chàm ở Dark Mode, thay toast tự chế của Loto bằng `NoticeToastView` |
| Slice (f) — Lesson + Today-life | `39e6100` | Nâng cấp hierarchy `LessonList`/`LessonReader`/`LessonPractice` (icon + màu `success` cho đáp án đúng + highlight nhất quán), thêm `UIScrollView` + `StateView` + card surface cho `Shadowing`, sửa viền `CGColor` chết khi đổi Dark Mode và nút nguồn `<44pt` ở `LifeLesson`, bỏ chiều cao chip cố định `52pt` ở `ScenarioList`, adaptive border ở `ScenarioPlay`, bọc card surface cho `DailyRadarCard` |
| Slice (g) — Settings + MailLogin + StartUp | `f0e5575` | Đồng bộ bo góc cả 4 nút đăng nhập trên `MailLogin` (kể cả `ASAuthorizationAppleIDButton` theo standard/AX), dùng `Design.Button.secondary` cho `Continue without login`, bỏ font cố định `20pt` ở `AccountCell`, đảm bảo nút menu `>= 44pt` ở `SettingsRowCell`, nâng cấp `DataExportViewController` lên `UIScrollView` + `StateView` + card surface |

---

## 2. Thay đổi theo màn & Đối chiếu ảnh Before / After

Tất cả ảnh đối chiếu nằm trong:
- Trước đại tu: `docs/ui-redesign/overhaul-2026-11-25/before/` (49 ảnh)
- Sau đại tu: `docs/ui-redesign/overhaul-2026-11-25/after/` (54 ảnh, bổ sung `magazine_{light,dark,ax}.png` sau khi sửa crash, cùng `life_lesson_{light,dark}.png` và `daily_radar_light.png`)

### 2.1. Hệ thống Thiết kế (Design System)
- **`FlashcardApp/Commons/Utils/DesignSystem.swift`**: Bổ sung `Design.HitTarget.minimum = 44`, thang bo góc chuẩn (`panel=28`, `card=20`, `control=14`, `chip=12`, `badge=8`), token màu mới (`surfaceElevated`, `surfaceTint`, `placeholder`, `border`, `heroChipFill`, `statusFill(_:)`), font scale theo Dynamic Type (`weighted`, `mincho`), cấu hình nút nhất quán (`Design.Button.primary`, `secondary`, `surfaceChip`, `hero`, `heroChip`, `cornerStyle(for:)`), cùng helper `applyCardSurface`, `observeAdaptiveBorder`, `enableAdaptiveCornerStyle`.
- **`FlashcardApp/Commons/Utils/AppColor.swift`**: Loại bỏ toàn bộ force-unwrap `UIColor(named:)!`, chuyển thành lớp tương thích an toàn trỏ sang `Design.Color`.
- **`FlashcardApp/Commons/Views/StateView.swift`** & **`PlaceholderView.swift`**: Bọc `StateView` trong `UIScrollView` có `topContentInset` động (chống che lấp header/search bar ở AX); chuẩn hoá `PlaceholderView` sang `Design.Color` + Auto Layout.

### 2.2. Slice (a) — Main & Today
- **Thay đổi:**
  - `LifeSceneView.swift`: sửa tương phản Dark Mode cho chữ số ngày lớn (`Design.Color.textPrimary`), nền thời tiết/chủ đề thích ứng, font Mincho/rounded hỗ trợ Dynamic Type.
  - `TodayLifeHubView.swift`: áp dụng `applyCardSurface(radius: .card)`, badge `LIVE`/`Đang dùng` nội tuyến không đè chữ ở AX, bỏ khoảng trắng thừa ~45pt dưới mỗi thẻ Life, chuyển thanh tiêu đề `TodayLifeHubView` và `TodayDateHeaderView` sang xếp dọc ở AX (hết vỡ `"Toky\no"`), đảm bảo nút đổi thành phố `>= 44pt`.
  - `TodayScenarioBanner.swift` & `TodayViewController.swift`: hạ mức độ nhấn của banner tình huống xuống card phẳng + nút `secondary` để không tranh điểm nhấn với `TodayHeroView`; tăng target chạm `>= 44pt` cho `titleControl` và `TodayRowView`; xếp dọc `TodayRowView` ở AX.
- **Ảnh đối chiếu:**
  - Light: `before/today_light.png` → `after/today_light.png` (`before/today_scroll_light.png` → `after/today_scroll_light.png`)
  - Dark: `before/today_dark.png` → `after/today_dark.png`
  - AX-XXL: `before/today_ax.png` → `after/today_ax.png`

### 2.3. Slice (b) — Home / Levels & Nội dung cấp độ
- **Thay đổi:**
  - `HomeViewController.swift`: thay nút `Bài học` bị cắt chữ ở AX bằng `LevelLessonsRowControl` (hàng card có icon, tiêu đề đầy đủ không bị cắt, mũi tên dẫn hướng, chiều cao `>= 44pt`, giữ nguyên `accessibilityIdentifier = "level_lessons"`). Gọi `headerView.layoutIfNeeded()` trong `sizeHeaderToFit()` và đồng bộ `stateView.topContentInset`.
  - `HomeCells.swift`: tăng chiều cao tối thiểu các nút `LevelKindStrip` lên `>= 44pt`, dùng `Design.TextRole.weighted` và `Design.Button.hero(title:traits:)` cho thẻ cấp độ nổi bật.
- **Ảnh đối chiếu:**
  - Levels: `before/home_levels_{light,dark,ax}.png` → `after/home_levels_{light,dark,ax}.png`
  - Level Content: `before/home_content_{light,dark,ax}.png` → `after/home_content_{light,dark,ax}.png`

### 2.4. Slice (c) — Dictionary + Entry / Saved / Scan / Voice / Handwriting
- **Thay đổi:**
  - `DictionaryResultCell.swift`: theo dõi `UITraitPreferredContentSizeCategory` để chuyển `rowStack` sang xếp dọc và mở không giới hạn số dòng (`numberOfLines = 0`) ở AX; đồng bộ highlight chọn dòng.
  - `DictionaryViewController.swift` & `DictionarySavedViewController.swift`: tự tính kích thước footer động (giữ đúng kiểu `UIActivityIndicatorView` / `UIButton` cho test contract); ở AX chuyển thanh chọn 3 mục của `DictionarySaved` thành menu bar button để không bị cắt nhãn.
  - `DictionaryEntryViewController.swift` (+ `+Vocabulary`, `+Kanji`, `EntryRows`, `StrokeOrderView`): nâng cấp nút hành động và chip từ/kanji từ `.gray()` mờ sang `Design.Color.surface` + viền mảnh `Design.Color.border`, scale glyph kanji bằng `Design.TextRole.mincho`, target `>= 44pt` cho `moreButton` và action header, bọc `StrokeOrderView` bằng `applyCardSurface`.
  - `DictionaryHandwritingViewController.swift`, `DictionaryScanViewController.swift`, `DictionaryVoiceViewController.swift`: bọc nội dung Scan/Voice trong `UIScrollView`, nâng kích thước nút xoá/lùi/làm mới Handwriting lên `>= 44pt`, chiều cao thanh ứng viên động theo Dynamic Type.
- **Ảnh đối chiếu:**
  - Kết quả tìm kiếm: `before/dictionary_results_{light,dark,ax}.png` → `after/dictionary_results_{light,dark,ax}.png`
  - Chi tiết từ vựng: `before/dictionary_entry_vocab_{light,dark,ax}.png` → `after/dictionary_entry_vocab_{light,dark,ax}.png`
  - Chi tiết Kanji: `before/dictionary_entry_kanji_{light,dark,ax}.png` → `after/dictionary_entry_kanji_{light,dark,ax}.png`

### 2.5. Slice (d) — Cards + CardStudy / CardReview / RemoteDeck / CreateDesk
- **Thay đổi:**
  - `CardViewController.swift` & `CardLibraryViews.swift`: sửa lỗi P0 `StateView` chồng lên thanh tìm kiếm và thanh scope ở AX bằng cách tính `topContentInset` theo toạ độ thực của `CardScopeHeaderView`; chuyển `CardScopeBar` sang chiều cao tự co giãn theo Dynamic Type; dùng `UITableView.automaticDimension` cho section header; giữ nguyên `often_missed_button` và `create_deck_button`.
  - `CardStudyViewController.swift`, `StudyReviewViews.swift`, `CardReviewViewController.swift`: ở AX chuyển điều khiển học sang bố cục 2 hàng (`Hiện đáp án` full-width phía trên `[Trước, Tiếp]`), nút trắc nghiệm dạng card surface `>= 44pt`, góc bo nút thích ứng (`.capsule` / `.large`), tổng kết dùng `applyCardSurface`.
  - `KanjiWritingViewController.swift`, `SharedDeckViewController.swift`, `RemoteDeckViewController.swift`, `NewDeckOptionsViewController.swift`, `DeckGeneratorViewController.swift`, `OftenMissedViewController.swift`, `ExampleEditorViewController.swift`: bổ sung `UIScrollView` + `StateView` thống nhất, xếp dọc ở AX, `applyCardSurface` và `Design.Color.highlight`.
- **Ảnh đối chiếu:**
  - Thư viện trống: `before/cards_library_{light,dark,ax}.png` → `after/cards_library_{light,dark,ax}.png`
  - Thư viện có bộ thẻ (fixture): `before/cards_library_seeded_{light,dark,ax}.png` → `after/cards_library_seeded_{light,dark,ax}.png`
  - Ôn tập: `before/cards_review_{light,dark}.png` → `after/cards_review_{light,dark}.png`
  - Học thẻ: `before/card_study_{light,dark,ax}.png` → `after/card_study_{light,dark,ax}.png`

### 2.6. Slice (e) — Discover / Magazine / Loto
- **Thay đổi:**
  - **Sửa P0 Crash `MagazineViewController.swift`:** `willDisplay` gọi `presenter.loadMore()` đồng bộ ngay trong lúc `dataSource.apply(snapshot)` đang chạy gây crash re-entrant diffable data source. Đã sửa bằng cờ `isApplyingSnapshot` + hàng đợi trì hoãn sang `DispatchQueue.main.async` (`drainQueuedWillDisplay`), kèm regression unit test `test_willDisplayNearEndDefersLoadMoreSoDiffableSnapshotApplyNeverReenters` trong `MagazinePresenterTests.swift`. Đồng thời tính `stateView.topContentInset` bên dưới `MagazineFilterBar`.
  - `MagazineCells.swift`, `MagazineArticleViews.swift`, `MagazineArticleSections.swift`: viền mảnh thích ứng trên filter chip và card bài viết, xếp dọc `MagazineRowCell` ở AX, adaptive border cho tag JLPT và `QuizOptionControl`, `Design.Button.secondary` cho nút thử lại/làm lại.
  - `DiscoverViewController.swift` & `DiscoverHeroViews.swift`: sửa P0 cắt chữ `"Phát hiện hôm nay"` ở AX bằng cách chuyển mặt niêm phong `DiscoverFindCard` sang xếp dọc ở AX; sửa tag `Loto 6`/`Loto 7` trên nền chàm bị đen đặc ở Dark Mode bằng `Design.Color.heroChipFill` + `Design.Color.onHero`; xếp dọc thẻ gọn ở AX.
  - `LotoViewController.swift`, `LotoViews.swift`, `LotoLabView.swift`, `LotoChaosViews.swift`: sửa P0 cắt chữ bộ đếm ngược (`ng.../ph.../gi...`) ở AX bằng cách chuyển sang lưới 2×2 ở AX; cập nhật gradient hero/lab khi đổi Dark Mode; thay `PaddedToastLabel` bằng `NoticeToastView` dùng chung; xếp dọc `LotoWeightBar` và tiêu đề slider lab ở AX; `applyCardSurface` cho `LotoPanel`.
- **Ảnh đối chiếu:**
  - Discover: `before/discover_{light,dark,ax}.png` → `after/discover_{light,dark,ax}.png`
  - Magazine: *(before bị crash nên không chụp được)* → `after/magazine_{light,dark,ax}.png` (chạy ổn định, hiển thị bài viết live)
  - Loto: `before/loto_{light,dark,ax}.png` → `after/loto_{light,dark,ax}.png`

### 2.7. Slice (f) — Lesson + Today-life Modules
- **Thay đổi:**
  - `LessonListViewController.swift`, `LessonReaderViewController.swift`, `LessonPracticeViewController.swift`: nền cell `Design.Color.surface` + `Design.Color.highlight` đồng bộ; nâng tiêu đề `LessonReader` lên `.title2` semibold + cập nhật `stateView.topContentInset` trong `sizeHeaderToFit()`; thêm icon SF Symbols cho hàng Thực hành và Lưu tất cả từ; đổi badge đáp án đúng ở `LessonPractice` sang `Design.Color.success` (phân biệt rõ với màu accent).
  - `ShadowingViewController.swift`: bọc `UIScrollView`, thêm `StateView` cho trạng thái rỗng, đặt câu mẫu trong card `applyCardSurface`, nâng cấp nút Nghe/Thu âm/Nghe lại lên `Design.Button.primary`/`secondary` + target `>= 44pt`.
  - `LifeLessonViewController.swift`: áp dụng `applyCardSurface` cho card và `answerField`, sửa viền `CGColor` đứng hình khi đổi Dark Mode bằng `observeAdaptiveBorder`, tăng nút nguồn thông tin lên `>= 44×44pt`, đồng bộ `primaryButton`/`secondaryButton` với góc bo thích ứng.
  - `ScenarioListViewController.swift`, `ScenarioPlayViewController.swift`: thay chiều cao chip cố định `52pt` bằng Auto Layout động theo `chipStack`, theo dõi Dynamic Type/Dark Mode, sửa adaptive border trên `ScenarioChoiceControl`, chuẩn hoá `card` và `button`.
  - `DailyRadarCardViewController.swift`: bọc từng biểu đạt và ghi chú cách dùng trong `applyCardSurface(radius: .card)`, nâng cấp tiêu đề có trait `.header`.
- **Ảnh đối chiếu:**
  - LessonList: `before/lesson_list_{light,dark,ax}.png` → `after/lesson_list_{light,dark,ax}.png`
  - LessonReader: `before/lesson_reader_{light,dark,ax}.png` → `after/lesson_reader_{light,dark,ax}.png`
  - LifeLesson & DailyRadar (bổ sung): `after/life_lesson_{light,dark}.png`, `after/daily_radar_light.png`

### 2.8. Slice (g) — Settings + MailLogin + StartUp
- **Thay đổi:**
  - `AccountCell.swift`: bỏ font cố định `20pt`, dùng `Design.TextRole.weighted(.title3, weight: .semibold)`; bật `enableAdaptiveCornerStyle()` + chiều cao `>= 50pt` cho nút Đăng nhập; dùng `observeAdaptiveBorder` cho vòng avatar.
  - `SettingsRowCell.swift`: đảm bảo `menuButton` luôn đạt kích thước chạm tối thiểu `44×44pt` (kể cả ở AX khi chỉ hiển thị biểu tượng chevron).
  - `DataExportViewController.swift`: bọc `UIScrollView`, dùng `StateView` cho trạng thái đang tải, bọc nội dung trong card `applyCardSurface`, nâng cấp nút hành động lên `Design.Button.primary` + `enableAdaptiveCornerStyle()`.
  - `MailLoginViewController.swift`: đồng bộ hình dáng bo góc cho cả 4 nút (`Sign In`, `Google`, `Apple`, `Continue without login`) — capsule ở cỡ chữ thường và bo `14pt`/`.large` ở AX (kể cả `ASAuthorizationAppleIDButton`); chuyển `Continue without login` sang `Design.Button.secondary`; scale dấu ấn thương hiệu `単` theo Dynamic Type; đồng bộ viền mặc định `LoginFieldView` sang `Design.Color.border`.
- **Ảnh đối chiếu:**
  - Settings: `before/settings_{light,dark,ax}.png` → `after/settings_{light,dark,ax}.png`
  - MailLogin: `before/maillogin_{light,dark,ax}.png` → `after/maillogin_{light,dark,ax}.png`

---

## 3. Kết quả kiểm thử (Thực chạy trên Simulator)

### 3.1. Environment Validation
```
sh scripts/tests/environment-validation.sh
→ Environment validation: 26 cases passed.
```

### 3.2. Full Unit Test Suite (`FlashcardAppTests`)
Lệnh thực chạy:
```bash
xcodebuild test -project FlashcardApp.xcodeproj \
  -scheme FlashcardApp-Local \
  -destination "id=AAEE78CE-966D-4502-B637-C4A5C83CDC36" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:FlashcardAppTests
```

Kết quả thực tế:
- **Tổng số test thực thi:** `1546`
- **Pass:** `1533`
- **Fail:** `0` (`0 unexpected`)
- **Skipped:** `13` (giống hệt baseline, đều do điều kiện môi trường opt-in/signing):
  - `5` test `KeychainAuthTokenManagerTests` (`AuthSessionTests.swift:768`): skip vì chạy không ký (`CODE_SIGNING_ALLOWED=NO`, Keychain trả `-34018`).
  - `7` test `LiveProductionContractTests` (`LiveProductionContractTests.swift:15`): opt-in, không có file token live để không chạm dữ liệu production.
  - `1` test `LocalBackendReviewSyncTests` (`ReviewSyncTests.swift:155`): opt-in, không bật local backend IOSK-18.
- **`LocalizationTests`:** `10/10` pass (0 lỗi key thiếu hoặc sai 3 ngôn ngữ vi/en/ja).
- **Regression test mới thêm:** `MagazinePresenterTests.test_willDisplayNearEndDefersLoadMoreSoDiffableSnapshotApplyNeverReenters` — **PASSED**.
- **Production Simulator Build (`FlashcardApp-Production`):** `** BUILD SUCCEEDED **`.

---

## 4. Hạng mục chưa thực hiện được & Lý do

1. **Chụp ảnh các màn yêu cầu đăng nhập tài khoản thật** (`CardReview` có thẻ đến hạn live, `DictionarySaved` có bookmark tài khoản, `ScenarioList`/`ScenarioPlay` live, `DataExport` đã có yêu cầu export trên server): Không sử dụng tài khoản thật hoặc ghi dữ liệu lên server production theo ràng buộc an toàn; toàn bộ các màn này đã được nâng cấp UI trong code, biên dịch thành công và kiểm thử qua unit test presenter/view tương ứng.
2. **Chụp ảnh `DictionaryScan` / `DictionaryVoice` với camera/micro thật:** iOS Simulator không có phần cứng camera thực và yêu cầu quyền hệ thống tương tác; đã nâng cấp layout (`UIScrollView`, card surface, adaptive buttons, `>= 44pt`) và kiểm thử qua `DictionaryScanPresenterTests` + `DictionaryVoicePresenterTests`.
3. **5 test Keychain & 8 test live/local backend contract (13 skipped):** Bị bỏ qua bởi chính điều kiện `XCTSkip` của test suite khi chạy không có code signing entitlement (`CODE_SIGNING_ALLOWED=NO`), không có local server `localhost:18081` và không có live auth token.
4. **Kiểm thử giao diện trực quan đa ngôn ngữ (vi/en/ja) đầy đủ từng màn hình:** Tuân theo Single-Simulator Fast Loop trong `docs/ENGINEERING_GUARDRAILS.md` §3; ảnh đối chiếu tập trung vào Light, Dark và AX-XXL trên iPhone 17. Tất cả chuỗi hiển thị đã được kiểm chứng tự động qua `LocalizationTests`.
