# Báo cáo Review Độc lập & Đối kháng — `uiux-overhaul-2026-11-25`

- **Ngày kiểm chứng:** 2026-11-25
- **Phạm vi diff kiểm toán:** `main (bcd2608)...uiux-overhaul-2026-11-25 (69616f3)` (`68` file code + `104` file tài liệu/ảnh trong `docs/ui-redesign/overhaul-2026-11-25/`)
- **Worktree kiểm chứng:** `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul`
- **Simulator thực thi:** iPhone 17 (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS 27.2)
- **Kết luận trên `69616f3` (trước khi reviewer sửa):** **CHƯA ĐẠT** (`0 P0`, `5 P1`, `5 P2`, `2 P3`)
- **Kết luận sau khi áp dụng 5 bản sửa P1 + 5 regression tests + chụp lại bộ ảnh tiếng Việt:** **ĐẠT** (`0 P0`, `0 P1` tồn đọng; `5/5 P1` đã sửa và chạy pass `1538/1551` unit tests)

> [!IMPORTANT]
> Toàn bộ 12 file mã nguồn sửa lỗi P1, 4 file kiểm thử hồi quy (`+5` XCTests), bản đồng bộ `OVERHAUL_REPORT.md` và 26 ảnh chụp lại bằng tiếng Việt đã được ghi và kiểm chứng thực tế tại `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul`. Ở bước cuối (`git commit` / `git push`), quyền truy cập thư mục song song `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul` (nằm ngoài Active Workspace `/Users/thanhnguyen/Documents/Develop/FlashcardApp`) bị chặn bởi sandbox (`Operation not permitted`), nên cần thêm quyền workspace hoặc chạy lệnh commit/push trực tiếp trên worktree này.

---

## 1. Bảng tổng hợp Findings (`P0` / `P1` / `P2` / `P3`)

| Mã | Mức độ | Nhóm săn lỗi | Vị trí (File / Ảnh) | Mô tả lỗi thực tế tìm thấy trên `69616f3` | Trạng thái |
|---|---|---|---|---|---|
| **P1-01** | **P1** | **(a) Hồi quy tương tác / điều hướng** | `MagazineViewController.swift:42-46, 84-94, 211-218`; `StateView.swift:45-96` | `stateView` được gắn đè toàn màn (`topAnchor == view.topAnchor`) phía trên `collectionView`, còn `show(_:retry:)` xoá sạch section (`empty.appendSections([])`) khi một bộ lọc đang tải, rỗng hoặc lỗi mạng. Hệ quả: `MagazineFilterBar` vừa mất supplementary section vừa bị `StateView` nuốt trọn 100% thao tác chạm, làm người dùng bị kẹt cứng ở bộ lọc rỗng/lỗi không thể bấm sang tab lọc khác hay kéo làm mới. | **ĐÃ SỬA** (`MagazineViewController.swift`, `StateView.swift` + test `test_emptyAndFailedStatesKeepPinnedFilterBarTappableWhileRetryButtonWorks`) |
| **P1-02** | **P1** | **(c) Dynamic Type AX vỡ/che khuất layout + (2) Lệch báo cáo** | `StateView.swift:72-73`; `CardViewController.swift:121-130`; `after/cards_library_ax.png` | Khi `StateView` đặt làm `UITableView.backgroundView` (`CardViewController`, `DictionaryViewController`, `DictionarySavedViewController`, `HomeViewController`, `LessonListViewController`, `LessonReaderViewController`), UIKit hấp thụ safe area vào `tableView.adjustedContentInset` và truyền `safeAreaInsets == .zero` cho `backgroundView`. Trên `after/cards_library_ax.png`, nút CTA chính `"Tạo bộ thẻ đầu tiên"` bị chôn dưới thanh Tab Bar Liquid Glass và cắt cụt ở mép dưới `y = 874`, đồng thời `scrollView` không cuộn được vì `bounds.height` kéo tràn xuống đáy màn hình. | **ĐÃ SỬA** (`StateView.swift` tự bù `enclosingScrollView?.adjustedContentInset` top/bottom + thu gọn mật độ AX; `CardViewController.swift` chống cộng đúp `baseTop` + test `testStateViewInTableBackgroundRespectsTopAndBottomAdjustedContentInsetsAtAccessibilitySize`) |
| **P1-03** | **P1** | **(c) Lỗi AX trong `AUDIT.md` chưa được sửa thật trên ảnh `after/`** | `StudyCardView.swift:89-105`; `CardStudyViewController.swift:238-256`; `after/card_study_ax.png` | `AUDIT.md` §3.4 ghi nhận lỗi P0 *"Đáy thẻ `StudyCardView` bị cắt phẳng... ở AX"* và `OVERHAUL_REPORT.md` §2.5 tuyên bố đã xử lý, nhưng ảnh `after/card_study_ax.png` chứng minh đáy thẻ `StudyCardView` vẫn bị xén phẳng góc vuông 90° (mất bo góc `28pt` và viền đáy) do `imageHeight = 200` + ràng buộc đối xứng `stack.centerYAnchor` ở `.required` đẩy chiều cao thẻ vượt khung `scrollView`; ngoài ra biểu tượng `<` / `>` ở AX phình sát mép nút tròn `56×56pt`. | **ĐÃ SỬA** (`StudyCardView.swift` giảm mật độ ảnh/đệm ở AX + hạ `stackCenterY.priority = .defaultHigh`; `CardStudyViewController.swift` khóa symbol chevron `18pt semibold` + test `test_flipCardWithPictureFitsInsideScrollViewportWithoutBottomClippingAtAccessibilitySize` + chụp lại `after/card_study_ax.png`) |
| **P1-04** | **P1** | **(c) Cắt chữ ở cỡ AX (`...`)** | `DiscoverViewController.swift:418-446` (`DiscoverTagFlow`); `MagazineCells.swift:127-205` (`MagazineLeadCell`); `after/magazine_ax.png` | Trên `after/magazine_ax.png`, nhãn `eyebrow` của bài tiêu điểm bị cắt thành `"WORKPLACE\nJAPANESE · N3 ·..."`. Nguyên nhân gốc: `DiscoverTagFlow.fittedHeight` khởi tạo bằng `0` trong lượt đo `systemLayoutSizeFitting` đầu tiên của compositional layout khiến cell bị cấp thiếu chiều cao, ép `UIStackView` nén dọc `eyebrow` trong khi hàng `head` vẫn giữ trục ngang ở AX. | **ĐÃ SỬA** (`DiscoverViewController.swift` tính ngay `fittedHeight` trong `systemLayoutSizeFitting` + khóa hugging/compression `.required`; `MagazineCells.swift` khóa compression `.required` và chuyển `head` sang trục dọc ở AX + test `test_leadCellSizesEyebrowAndWordChipsWithoutCompressionAtAccessibilitySize` + chụp lại `after/magazine_ax.png`) |
| **P1-05** | **P1** | **(2) Sai lệch giữa `OVERHAUL_REPORT.md`, code và bộ ảnh `after/`** | `OVERHAUL_REPORT.md`; `after/cards_library_seeded_light.png`; `after/dictionary_empty_light.png`; `DictionarySavedViewController.swift:126-170`; `MailLoginViewController.swift:239-263`; `LifeSceneView.swift:133-163`; `DesignSystem.swift:408-433` | 1) `after/cards_library_seeded_light.png` (`61 KB`) là ảnh **đen đặc 100% (`#000000`)** do màn hình Simulator tắt khi chụp.<br>2) Thiếu hoàn toàn `after/dictionary_empty_light.png` dù `before/dictionary_empty_light.png` có trong `AUDIT.md`.<br>3) Các ảnh Slice (e)–(g) (`discover_*`, `magazine_*`, `loto_*`, `lesson_*`, `settings_*`, `maillogin_*`) chụp bằng tiếng Anh thay vì tiếng Việt như chuẩn `AUDIT.md`, còn `after/daily_radar_light.png` bị trộn tiếng Anh (`6 minutes`, `JAPANESE TO USE`) với tiếng Việt.<br>4) Báo cáo §2.4 nói `DictionarySavedViewController` giữ nguyên kiểu `UIActivityIndicatorView` / `UIButton` cho `tableFooterView`, nhưng code thực tế bọc cả hai trong `holder: UIView` (`sized(...)`); báo cáo §2.8 nói dấu `"単"` trên `MailLogin` scale theo Dynamic Type nhưng `UILabel` không có đệm nên kẹt ở `40×40pt`; số `"25"` trong `LifeSceneView` tràn ngang khỏi khung lịch nhỏ; `observeAdaptiveBorder` / `enableAdaptiveCornerStyle` đăng ký chồng observer mỗi lần tái sử dụng cell; `Design.Button.hero`/`heroChip` thiếu `compatibleWith: traits`. | **ĐÃ SỬA** (Sửa code tại `DictionarySavedViewController.swift`, `MailLoginViewController.swift`, `LifeSceneView.swift`, `DesignSystem.swift`, `DictionaryViewController.swift`; thêm test `testSavedViewControllerFooterPreservesSpinnerAndRetryButtonTypes`; chụp lại toàn bộ 26 ảnh lỗi/thiếu/sai ngôn ngữ bằng tiếng Việt; đồng bộ `OVERHAUL_REPORT.md`) |
| **P2-01** | **P2** | **(f) File rác trong git** | `.DS_Store` (11 file), `.claude/skills/ui-ux-pro-max/scripts/__pycache__/*.pyc` (3 file) | Diff `main...uiux-overhaul-2026-11-25` không thêm file rác mới (`0` file rác mới), nhưng nhánh vẫn kế thừa `14` file rác đã được track sẵn từ `main`. | **Chỉ ghi nhận** (theo quy tắc không sửa P2/P3) |
| **P2-02** | **P2** | **(c) Thanh scope cố định ở cỡ AX** | `DictionaryViewController.swift`; `after/dictionary_results_ax.png` | Khác với `Home` và `DictionarySaved` (chuyển sang menu bar button ở cỡ AX), thanh `scopeButtonTitles` 4 mục của `UISearchBar` gốc trên màn `Dictionary` vẫn giữ chiều cao ~36pt (`< 44pt`) và cỡ chữ nhỏ cố định ở AX-XXL. | **Chỉ ghi nhận** |
| **P2-03** | **P2** | **(c) Tương phản viền nhẹ & nền icon Google** | `MailLoginViewController.swift`; `after/maillogin_light.png`, `after/maillogin_dark.png` | Viền mặc định khi chưa focus của `LoginFieldView` (`Design.Color.border` = `UIColor.separator`) trên nền trắng/washi ở Light Mode có độ tương phản phi văn bản `< 3:1`; icon chữ `G` của nút Google ở Dark Mode vẫn nằm trên ô vuông trắng nhỏ của asset gốc. | **Chỉ ghi nhận** |
| **P2-04** | **P2** | **Hạng mục P2 tồn đọng từ `AUDIT.md`** | `DiscoverViewController.swift`, `CardViewController.swift`, `LessonListViewController.swift`, `LessonReaderViewController.swift`, `TodayLifeHubView.swift` | Hai khối hero nền chàm đậm vẫn xếp liền kề trên `Discover` (và chuỗi tiếng Anh `"1 days"` sai số nhiều khi chạy locale `en`); `CardViewController` giữ 4 nút bar button riêng lẻ bên phải; `LessonList`/`LessonReader` và phần `Earlier` của `Magazine` chưa thêm viền surface mảnh / phân cấp chữ Nhật–Việt rõ hơn; `LifeTopicCardView` dùng `bottomSpacer` căn đáy trong dải ngang có chiều cao bằng nhau thay vì giảm chiều cao thẻ ngắn. | **Chỉ ghi nhận** |
| **P2-05** | **P2** | **Lỗi test cũ từ `main`** | `FlashcardAppTests/DeckPublishTests.swift:256` | Trong một test cũ từ `main`, `presenter.view = SpyCardView()` gán đối tượng tạm vào biến `weak var view` khiến spy bị giải phóng ngay lập tức. | **Chỉ ghi nhận** |
| **P3-01** | **P3** | **Cảnh báo biên dịch ở test target** | `FlashcardAppTests/*` | Cảnh báo deprecated `UIWindow(frame:)` trên iOS 26 SDK trong test và các cảnh báo biến/kết quả không dùng có sẵn từ `main` (`App target` chính không có lỗi mới). | **Chỉ ghi nhận** |
| **P3-02** | **P3** | **Chi tiết thị giác nhỏ** | `PitchAccentView`, `StudyCardView` | Chữ mora dưới đường cong trọng âm từ (`PitchAccentView`) giữ cỡ nhỏ cố định ở AX để không vỡ đồ thị; ảnh mẫu vuông `犬` trong `StudyCardView` hiển thị hai dải đệm xám hai bên khung chữ nhật bo góc. | **Chỉ ghi nhận** |

---

## 2. Kiểm toán theo 6 nhóm bắt buộc & Chuẩn kiến trúc (`AGENTS.md`)

| Nhóm kiểm toán | Kết quả kiểm chứng thực tế |
|---|---|
| **Chuẩn i18n / Text cứng mới** | **ĐẠT** — Duyệt toàn bộ diff `5.686` dòng code: **0 chuỗi hiển thị người dùng bị hard-code mới**. Toàn bộ chuỗi dùng `NSLocalizedString` khớp 3 ngôn ngữ `vi`/`en`/`ja` trong `Localizable.xcstrings` (`LocalizationTests`: **10/10 pass**). (Chuỗi `"単"` và `"Flashcard"` ở `MailLogin` là biểu trưng thương hiệu trang trí `isAccessibilityElement = false`). |
| **(a) Hồi quy chức năng / điều hướng** | Giữ nguyên cấu trúc 5 tab, toàn bộ wireframe, hành vi học thẻ/ôn tập/lưu từ và các `accessibilityIdentifier` phục vụ UI test (`level_lessons`, `often_missed_button`, `create_deck_button`, `saved_kinds`, `study_primary`, ...). Đã phát hiện và **sửa dứt điểm `P1-01`** (kẹt bộ lọc trên `Magazine` khi rỗng/lỗi). |
| **(b) Rò rỉ nghiệp vụ / API / Realm** | **ĐẠT TUYỆT ĐỐI** — `0` file thay đổi trong `Networks/`, `Services/`, `Interactors/`, `DataManager/`, `Entities/`, `Package.resolved`. Schema Realm giữ nguyên ở mức `7`. Thay đổi duy nhất ngoài tầng View là 1 dòng đổi token màu tại `MailLoginPresenter.swift:51` (`AppColors.placeholderText` → `Design.Color.placeholder`). Không chèn quảng cáo vào màn học/ôn thẻ. |
| **(c) Dynamic Type AX / Dark Mode / VoiceOver** | Đã đối chiếu 100% ảnh `before/` (49 ảnh) và `after/` (55 ảnh sau bổ sung). Các lỗi Dark Mode nghiêm trọng ở `LifeSceneView` và chip `Discover`, cùng cắt chữ ở `Home` (`Bài học`), `Discover` (`Phát hiện hôm nay`), `Loto` (lưới đếm ngược 2×2) đã được giải quyết thật. Các lỗi AX còn lọt trên `69616f3` (`P1-02`, `P1-03`, `P1-04`, dấu `"単"`) đã được **reviewer sửa và kiểm chứng lại bằng ảnh chụp thực tế + XCTest**. VoiceOver giữ/bổ sung đầy đủ `accessibilityLabel`, `.header` trait và thông báo `.layoutChanged` trong `StateView`. |
| **(d) Retain cycle / Main-thread UI** | **ĐẠT** — Kiểm tra toàn bộ closure `UIAction`, `registerForTraitChanges`, `observeAdaptiveBorder`, `DispatchQueue.main.async` và Rx `subscribe`: tất cả đều dùng `[weak self]` hoặc tham số view truyền vào của `UITraitChangeRegistration` (không giữ vòng tham chiếu mạnh). Đã gia cố thêm `objc_setAssociatedObject` + `unregisterForTraitChanges` trong `DesignSystem.swift` để tránh tích luỹ observer khi cell tái sử dụng. Mọi cập nhật UI đều chạy trên main thread. |
| **(e) Target membership (`project.pbxproj`)** | **ĐẠT** — `0` thay đổi trong `FlashcardApp.xcodeproj/project.pbxproj`, không có file `.swift` mồ côi nào bị bỏ sót khỏi target `FlashcardApp` hoặc `FlashcardAppTests`. |
| **(f) File rác trong commit** | Diff `main...uiux-overhaul-2026-11-25` **không commit thêm file rác mới** (`0` file `.DS_Store`, `.pyc` hay thư mục tooling mới); `14` file `.DS_Store`/`.pyc` tồn tại sẵn từ `main` được ghi nhận tại `P2-01`. |

---

## 3. Bằng chứng Tự Chạy Kiểm chứng (Lệnh & Kết quả Số Thật)

### 3.1. Kiểm tra cấu hình môi trường (`environment-validation.sh`)
```bash
sh scripts/tests/environment-validation.sh
```
- **Kết quả:** `Environment validation: 26 cases passed.`

### 3.2. Build `FlashcardApp-Local` & `FlashcardApp-Production` trên Simulator
```bash
xcodebuildmcp simulator build \
  --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
  --scheme FlashcardApp-Local \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO"

xcodebuildmcp simulator build \
  --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
  --scheme FlashcardApp-Production \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO"
```
- **Kết quả trước sửa (`69616f3`):** `✅ Build succeeded. (⏱️ 25.9s)` (`FlashcardApp-Local`)
- **Kết quả sau sửa P1:**
  - `FlashcardApp-Local`: `✅ Build succeeded. (⏱️ 106.2s)`
  - `FlashcardApp-Production`: `✅ Build succeeded. (⏱️ 159.7s)`

### 3.3. Chạy riêng `LocalizationTests`
```bash
xcodebuildmcp simulator test \
  --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
  --scheme FlashcardApp-Local \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO" "-parallel-testing-enabled" "NO" \
  "-only-testing:FlashcardAppTests/LocalizationTests"
```
- **Kết quả trước sửa (`69616f3`):** `✅ 10 tests passed, 0 failed, 0 skipped (⏱️ 39.8s)`
- **Kết quả sau sửa P1:** `✅ 10 tests passed, 0 failed, 0 skipped (⏱️ 30.6s)`

### 3.4. Chạy FULL `FlashcardAppTests`
```bash
xcodebuildmcp simulator test \
  --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
  --scheme FlashcardApp-Local \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO" "-parallel-testing-enabled" "NO" \
  "-only-testing:FlashcardAppTests"
```
- **Kết quả trước sửa (`69616f3`):** `Discovered 1546 test(s)` → **`1533 passed, 0 failed, 13 skipped` (`⏱️ 72.2s`)**
- **Kết quả sau khi thêm 5 regression tests cho P1:** `Discovered 1551 test(s)` → **`1538 passed, 0 failed, 13 skipped` (`⏱️ 71.4s`)**
  - Cả 5 regression tests mới viết đều **PASS**:
    1. `MagazinePresenterTests.test_emptyAndFailedStatesKeepPinnedFilterBarTappableWhileRetryButtonWorks`
    2. `MagazinePresenterTests.test_leadCellSizesEyebrowAndWordChipsWithoutCompressionAtAccessibilitySize`
    3. `DictionarySavedPresenterTests.testSavedViewControllerFooterPreservesSpinnerAndRetryButtonTypes`
    4. `DictionaryViewControllerTests.testStateViewInTableBackgroundRespectsTopAndBottomAdjustedContentInsetsAtAccessibilitySize`
    5. `CardStudyPresenterTests.test_flipCardWithPictureFitsInsideScrollViewportWithoutBottomClippingAtAccessibilitySize`
  - `13` test `XCTSkip` (không phải lỗi): `5` test `KeychainAuthTokenManagerTests` do `CODE_SIGNING_ALLOWED=NO` (`-34018`), `7` test `LiveProductionContractTests` opt-in bảo vệ production, `1` test `LocalBackendReviewSyncTests` opt-in khi không bật local server `:18081`.

---

## 4. Phần Chưa Kiểm chứng Được (`NOT VERIFIED`)

1. **`FlashcardAppUITests` cần backend Go cục bộ (`http://localhost:18081/api`):** Đã kiểm tra thực tế endpoint local trả mã `000` (máy chủ local đang tắt), nên không chạy suite UI test phụ thuộc backend local.
2. **5 bài kiểm thử Keychain thật (`KeychainAuthTokenManagerTests`):** Chưa chạy với chứng chỉ ký thật (`CODE_SIGNING_ALLOWED=YES`) do môi trường CI/Simulator không ký trả lỗi entitlement `-34018`.
3. **Các màn hình live yêu cầu tài khoản đăng nhập thật** (`CardReview` có thẻ đến hạn trên server, `DictionarySaved` có dữ liệu tài khoản thật, `ScenarioList` / `ScenarioPlay` live, `DataExport` có lịch sử xuất dữ liệu): Không dùng thông tin đăng nhập thật hoặc ghi dữ liệu lên server production theo quy tắc an toàn `AGENTS.md` #6 & #11; chỉ kiểm chứng qua mã nguồn và unit tests của presenter/view.
4. **Phần cứng vật lý (`DictionaryScan` camera trực tiếp, `DictionaryVoice` micro/nhận diện giọng nói thật, thiết bị iPhone/iPad thật & trải nghiệm nghe VoiceOver thực tế):** Simulator không có camera phần cứng và chưa kiểm chứng âm thanh VoiceOver trực tiếp trên thiết bị vật lý.
5. **Bước `git commit` & `git push` cuối cùng trên worktree song song:** Ngay sau khi hoàn tất chụp ảnh cuối lúc `17:19`, sandbox phiên làm việc chặn quyền truy cập `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul` (`Operation not permitted`) vì nằm ngoài Active Workspace `/Users/thanhnguyen/Documents/Develop/FlashcardApp`. Mọi bản sửa code, test và ảnh đã nằm sẵn trên đĩa tại `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul`.
