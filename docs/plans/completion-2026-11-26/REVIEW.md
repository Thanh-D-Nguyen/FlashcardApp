# Báo cáo Review Độc lập & Đối kháng — `fix-completion-2026-11-26`

- **Ngày kiểm chứng:** 2026-11-27
- **Phạm vi diff kiểm toán:** `main (2c1b2b0)...fix-completion-2026-11-26 (a36fc90)` → sau sửa của reviewer: `cb52c46`
- **Worktree kiểm chứng:** `/Users/thanhnguyen/Documents/Develop/FlashcardApp-fix-completion`
- **Simulator thực thi:** iPhone 17 (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS 27.2)
- **Kết luận trên `a36fc90` (trước khi reviewer sửa):** **CHƯA ĐẠT** (`0 P0`, `2 P1`, `2 P2`, `2 P3`)
- **Kết luận sau khi sửa trực tiếp 2 lỗi `P1` + thêm 2 regression tests + chụp lại ảnh ngữ pháp + chạy lại toàn bộ suite:** **ĐẠT** (`0 P0`, `0 P1` tồn đọng; `2/2 P1` đã sửa tại commit `cb52c46`; `1550/1563` unit tests pass, `0` fail, `13` skip baseline; `LocalizationTests` `10/10` pass; cả 3 scheme build `SUCCEEDED`)

---

## 1. Bảng tổng hợp Findings phát hiện bởi Adversarial Review

| Mã | Mức độ | Hạng mục liên quan | Vị trí (File / Ảnh) | Mô tả lỗi thực tế tìm thấy trên `a36fc90` | Trạng thái |
|---|---|---|---|---|---|
| **P1-01** | **P1** | **`F01` — Điều hướng tra từ điển liên tab (`LevelEntryDetail` → `DictionaryEntry` → `Dictionary`)** | `LevelEntryDetailWireframe.swift:48-60`; `DictionaryViewController.swift:35,122`; `DictionaryPresenter.swift:63` | `COMPLETION_AUDIT.md` khẳng định đã bổ sung *"safe cross-tab `DictionaryEntryWireframe.showSearch(for:)`"*, nhưng `routeToDictionarySearch(_:)` chỉ gán `tabs.selectedIndex = MainTab.dictionary.rawValue` rồi gọi ngay `dictionary.presenter.beginSearch(text)` mà **không gọi `dictionary.loadViewIfNeeded()`** (khác với `MainViewController.swift:47` có gọi `cards.loadViewIfNeeded()`) và không đóng modal đang mở trên tab `Dictionary`. Khi người học mở `Levels` từ `Today` hoặc `Discover` ngay sau khi mở app mà chưa từng bấm qua tab `Dictionary` (`dictionary.isViewLoaded == false`), `requestedQuery` (`PublishRelay<String>`, không có buffer) phát sự kiện trước khi `DictionaryViewController.viewDidLoad()` đăng ký `subscribe()`, làm **mất hoàn toàn từ khoá tra cứu** và mở ra màn `Dictionary` trống. | **ĐÃ SỬA (`cb52c46`)** — Gọi `nav?.dismiss(animated: false)` nếu có modal và `dictionary.loadViewIfNeeded()` trước `beginSearch(text)`; chứng minh RED → GREEN bằng test `testCrossTabLookUpLoadsColdDictionaryTabBeforeEmittingQuery`. |
| **P1-02** | **P1** | **`F01` — Phát âm TTS sai lệch trên `LevelEntryDetail` (Ngữ pháp & Từ vựng đồng hình)** | `LevelEntryDetailPresenter.swift:74-83`; `shots/after_level_entry_grammar_light.png` | 1) Với `.grammar`, `LevelEntry.spokenText` trả `Self.clean(title)` khiến màn chi tiết ngữ pháp hiện nút `"Nghe"` ngay dưới các công thức chứa ký hiệu giả định như `"… いぜん"` (thể hiện rõ trên `shots/after_level_entry_grammar_light.png`), `"〜にすぎない"`, `"N + について"`, làm `AVSpeechSynthesizer` đọc thành tiếng các dấu ba chấm/ký hiệu ngữ pháp — trái ngược hoàn toàn với chuẩn của `DictionaryEntryViewController+Grammar.swift:16` (`actionRow(speak: nil, ...)`).<br>2) Với `.vocabulary`, `spokenText` truyền thẳng `title` (kanji `headword`) thay vì token kana đầu tiên của `reading` như `DictionaryEntryViewController+Vocabulary.swift:17`, khiến từ đồng hình khác cách đọc (ví dụ `一日`: `ついたち` vs `いちにち`) có thể bị TTS đọc sai cách đọc của cấp độ đang học. | **ĐÃ SỬA (`cb52c46`)** — Đổi `.grammar` trả `nil` (`canSpeak == false`), `.vocabulary` ưu tiên `firstSpokenToken(reading)` trước khi fallback về `title`; chứng minh RED → GREEN bằng test `testVocabularySpeaksFirstReadingTokenAndGrammarDisablesListenForMetaPatterns`; **chụp lại thực tế `shots/after_level_entry_grammar_light.png`** trên Simulator. |
| **P2-01** | **P2** | **`F02` — Nhãn VoiceOver khi dùng launch argument debug** | `DiscoverHeroViews.swift:103-106, 252-259`; `DiscoverViewController.swift:80` | Trong luồng người dùng bình thường, `findCard.isHidden = true` cho tới khi `show(find:)` gọi `configure(word:article:)` nên nhãn VoiceOver luôn đúng. Tuy nhiên nếu cờ `#if DEBUG` `-DiscoverRevealFind` chạy `reveal()` ở mốc `+1.5s` trước khi mạng kịp trả `show(find:)`, `configure(word:article:)` đến sau không gán lại `accessibilityLabel`/`accessibilityValue`. | **Chỉ ghi nhận** (chỉ xảy ra với cờ debug khi mạng chậm >1.5s) |
| **P2-02** | **P2** | **File rác kế thừa từ `main`** | `.DS_Store` (11 file), `.pyc` (3 file) | Nhánh `fix-completion-2026-11-26` không commit thêm bất kỳ file rác mới nào (`0` file rác mới), nhưng vẫn kế thừa 14 file `.DS_Store`/`.pyc` đã track sẵn trên `main`. | **Chỉ ghi nhận** |
| **P3-01** | **P3** | **`F03` — Gợi ý VoiceOver trên `OftenMissed` & giao thức cũ** | `OftenMissedViewController.swift:83`; `DeckGeneratorPresenter.swift:63` | `accessibilityHint` của dòng `OftenMissed` vẫn ghi *"Opens the deck “%@” to study"* dù nay mở phiên học lọc riêng các thẻ hay sai của bộ đó; `DeckGeneratorWireframeInterface` còn khai báo `showAlert(with:message:)` từ `main` chưa có caller (đã thoả mãn qua `BaseWireframe`). | **Chỉ ghi nhận** |
| **P3-02** | **P3** | **Định dạng chuỗi dữ liệu gốc từ API ngữ pháp** | `shots/after_level_entry_grammar_light.png` | Chuỗi `explanationVi` của mục `… いぜん` từ backend `/api/levels/J4/grammar` nối hai ý bằng `".- Thường được dùng..."` không xuống dòng; app giữ nguyên văn dữ liệu API đúng quy tắc `AGENTS.md` (*"Đừng thêm dữ liệu từ điển, tách từ hay furigana tự bịa"*). | **Chỉ ghi nhận** (thuộc dữ liệu nội dung server) |

---

## 2. Kiểm chứng Lỗi Báo cáo Gốc (`showMeaning` / Alert-as-Content) & Bộ Ảnh Chụp

1. **Grep toàn bộ codebase chứng minh xoá sổ hoàn toàn `showMeaning` và không còn alert-as-content ở bất kỳ module nào:**
   - Chạy `grep -rn "showMeaning" FlashcardApp FlashcardAppTests FlashcardAppUITests` → **`0` kết quả**.
   - Kiểm tra toàn bộ `60` điểm xuất hiện của `showAlert` / `UIAlertController` trên tất cả 30 thư mục module trong `FlashcardApp/`:
     - Xác nhận **100%** các hộp thoại còn lại chỉ thuộc đúng 5 nhóm hợp lệ chuẩn iOS HIG:
       1. Xác nhận hành động huỷ/xoá/lưu trữ/chặn/đăng xuất (`CreateDesk`, `Card`, `CardStudy`, `ExampleEditor`, `RemoteDeck`, `Setting`).
       2. Thông báo lỗi hoặc cảnh báo mất kết nối/đổi phiên tài khoản (`CreateDesk`, `Card`, `CardStudy`, `PictureSearch`, `LessonReader`, `Setting`).
       3. Hộp nhập dữ liệu ngắn (`CreateDesk` URL ảnh `https://`, `Card` dán link bộ thẻ chia sẻ, `RemoteDeck` lý do báo cáo).
       4. `UIAlertController(.actionSheet)` chọn bộ thẻ lưu từ / chọn thời lượng học / chọn thành phố thời tiết (`Today`, `DictionaryEntry`, `LessonReader`, `LifeLesson`, `MagazineArticle`).
       5. Nhắc mở Cài đặt hệ thống khi thiếu giọng đọc tiếng Nhật hoặc quyền thông báo (`DictionaryEntry`, `LevelEntryDetail`, `Setting`) và hộp phiên bản `About Flashcard` (`Setting`, đã bỏ chevron `disclosure: false` ở `F10`).
     - **Không còn bất kỳ dòng danh sách hay mục nội dung học tập nào dùng `UIAlertController` để hiển thị nội dung.**
2. **Kiểm chứng màn `LevelEntryDetail` & toàn bộ 7 ảnh trong `docs/plans/completion-2026-11-26/shots/`:**
   - Đã đọc và kiểm tra trực quan từng file ảnh:
     - `before_level_entry_light.png`, `before_level_entry_dark.png`: Ghi nhận trung thực lỗi gốc trên `main` (chạm dòng từ vựng `あっ` ở `J4` bật alert `OK` che danh sách).
     - `after_level_entry_light.png`, `after_level_entry_dark.png`: Màn `LevelEntryDetail` được push thật trên `UINavigationController`, hiển thị đầy đủ eyebrow (`J4 · Từ vựng`), headword (`あっ`), cách đọc (`アッ あっ あ`), nghĩa ngắn (`a!; ôi; này`), nút `"Nghe"`, thẻ `"Nghĩa chi tiết"` đánh số (`1. A!, Ôi!`, `2. Này!`), nút chính `"Mở mục từ điển đầy đủ"`, nút phụ `"Bài học cho J4"`, menu `•••` (`Sao chép` / `Chia sẻ`), độ tương phản chuẩn ở cả Light và Dark Mode.
     - `after_level_entry_ax.png`: Cỡ chữ trợ năng lớn (`AX-XXL`), `UIScrollView` cuộn dọc mượt, không cắt chữ, nút `"Nghe"` và nút hành động tự chuyển bo góc chữ nhật lớn (`enableAdaptiveCornerStyle`).
     - `after_level_entry_kanji_light.png`: Chữ Hán `会` căn giữa bằng `kanjiGlyph` Mincho cỡ lớn, nghĩa Hán-Việt `HỘI, CỐI`, thẻ `"Cách đọc"` tách riêng `Âm On (âm Hán): カイ エ` và `Âm Kun (âm Nhật): あ.う あ.わせる あつ.まる`.
     - `after_level_entry_grammar_light.png`: Phát hiện ảnh cũ còn hiển thị nút `"Nghe"` trên mẫu `"… いぜん"` (`P1-02`); đã sửa code và **chụp lại thực tế từ Simulator** (`274.808` bytes), hiển thị sạch eyebrow `J4 · Ngữ pháp`, tiêu đề `… いぜん`, nghĩa ngắn, thẻ `Giải thích` đầy đủ và 2 nút điều hướng mà không còn nút `"Nghe"` sai ngữ nghĩa.

---

## 3. Kiểm chứng Chi tiết Từng Hạng mục trong `COMPLETION_AUDIT.md` (`FIX` / `REMOVE` / `KEEP`) & Quét Toàn App

### 3.1. Nhóm `FIX` (`F01` – `F10`)

| Mã | Kết quả kiểm chứng độc lập |
|---|---|
| **`F01`** | **ĐẠT (sau khi sửa `P1-01` & `P1-02` tại `cb52c46`)** — Module VIPER `Modules/LevelEntryDetail` tách đúng View / Presenter / Wireframe, đăng ký đầy đủ vào `project.pbxproj`, dùng `StateView` khi thiếu nghĩa, dịch đủ `vi`/`en`/`ja` cho 3 khóa mới (`Meanings`, `Open full dictionary entry`, `Lessons for %@`), không hard-code text, có `8/8` XCTest và XCUITest kiểm chứng push thật không bật alert. |
| **`F02`** | **ĐẠT** — `DiscoverFind` giữ `slug` & `day`; chạm lần 1 lật thẻ, chạm lần 2 gọi `DiscoverPresenter.openFind()` → `DiscoverWireframe.showMagazineArticle(slug:day:)`; mặt mở hiển thị `"Read article"` + chevron, giữ `accessibilityTraits = .button` và khóa dịch `Tap to open the article` đủ `vi`/`en`/`ja`; có unit test `test_openingRevealedFindRoutesToItsMagazineArticle`. |
| **`F03`** | **ĐẠT** — `OftenMissedPresenter.selectRow(at:)` truyền danh sách `cardIDs` hay sai của đúng bộ thẻ với thẻ vừa chạm đứng đầu sang `CardStudyWireframe(deckId:cardIDs:)`. Đã đối chiếu thêm `CardStudyPresenter.swift:245-246`: khi `cardIDs != nil`, phiên học tắt xáo trộn (`shuffled: false`) để giữ đúng thứ tự thẻ vừa chạm và lấy `quizPool` từ `wholeDeck` nên chế độ trắc nghiệm không bị hỏng kể cả khi chỉ có 1 thẻ hay sai. |
| **`F04`** | **ĐẠT** — `KanjiWritingQuestions.make` quét `card.front` trước và fallback sang `card.back` khi bộ thẻ đảo chiều Việt → Nhật; màn `.finished` hiển thị `StateView.call` với nút `"Practise again"` gọi `presenter.restart()` xoá canvas và đặt lại câu đầu; cả hai đều có regression test trong `KanjiWritingTests`. |
| **`F05`** | **ĐẠT** — `TodayScenarioBannerView` tắt tương tác trên `header`, `detail`, `cta`, định tuyến `hitTest` vùng `chipScroll` về `chipScroll` để cuộn ngang mượt 10 chip danh mục, đồng thời gắn `UITapGestureRecognizer` chuyển thao tác chạm về `sendActions(for: .touchUpInside)` để không làm gãy thao tác mở danh sách tình huống. |
| **`F06`** | **ĐẠT** — `CardLibraryServerInteractor.saveToDevice(_:)` kiểm tra `links.deviceDeckId(forAccount:)` trong `repository` trước khi import, đồng bộ hoàn toàn với `hasDeviceCopy(deckId:)` và chặn tạo bản sao cục bộ trùng lặp khi bấm `"Study"` trên bộ thẻ đã tải lên; có regression test trong `CardLibraryServerInteractorTests`. |
| **`F07`** | **ĐẠT** — `StudySummaryView` gộp `card.result == .incorrect || card.result == .typedIncorrect` để gắn nhãn `"Incorrect"` màu cảnh báo thay vì gắn nhầm `"Self-rating"`. |
| **`F08`** | **ĐẠT** — `ExampleEditorViewController` gọi `problemLabel.show(state.problem)` (hiển thị đúng biểu tượng cảnh báo đi kèm chữ) và gán `navigationController?.presentationController?.delegate = self` trong `viewDidAppear` (sau khi sheet đã có `presentationController`) để bảo vệ thao tác vuốt đóng khi đang sửa dở. |
| **`F09`** | **ĐẠT** — `DictionarySavedViewController` xoá `tableView.tableFooterView = nil` ở mọi trạng thái ngoài `.loaded`; `DictionarySavedPresenter` lưu `signedInWhenLoaded` để tự làm mới khi người dùng đăng xuất/đăng nhập ở tab khác rồi quay lại; có regression test `testSigningOutOffScreenClearsStaleListOnReturn`. |
| **`F10`** | **ĐẠT** — `CardViewController` bật thanh tìm kiếm khi chỉ có bộ thẻ `"On your account"` (`hasAccountRows`); `RemoteDeckViewController` đổi icon `"Stop sharing"` từ `"link.badge.plus"` sang `"xmark.circle"`; `LessonPracticeViewController` gán `title = presenter.title`; `SettingPresenter` đặt `disclosure: false` cho dòng `"About Flashcard"`. |

### 3.2. Nhóm `REMOVE` (`R01` – `R05`) & Toàn vẹn Điều hướng

- Đã chạy script kiểm tra chéo toàn bộ file `.swift`/`.storyboard`/`.xib` trên đĩa với `FlashcardApp.xcodeproj/project.pbxproj` và grep toàn bộ symbol đã xoá:
  - **`R01` (`SettingsPrototypes.swift`), `R02` (`VersionFooterView.swift/.xib`, `CardInteractor.swift`), `R05` (`PlaceholderView`, `RoundCornerButton`, `RoundCornerView`, `RoundedImageView`, `AppColor`, `Extensions/Color`):** Đã gỡ sạch khỏi đĩa và khỏi `PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXResourcesBuildPhase` (`0` file mồ côi trên đĩa, `0` tham chiếu treo trong `project.pbxproj`, `0` tham chiếu còn sót trong source/test).
  - **`R03` (`RemoteDeckViewController` menu `"Save to this device"`):** Đã gỡ mục menu trùng với nút `saveButton` cố định ở đáy và tự ẩn `rightBarButtonItem` khi `menu.children.isEmpty`, không ảnh hưởng tới các hành động `Send ratings`, `Share link`, `Stop sharing`, `Archive`, `Report deck`, `Block author`.
  - **`R04` (`NewDeckFlow` dùng chung cho `TodayWireframe` và `CardWireframe`):** Giữ nguyên hành vi đóng sheet trước khi mở màn tiếp theo (`dismiss(animated: true) { onChoose(method) }`), giữ nguyên CTA tạo bộ thẻ trên cả tab `Today` và tab `Card`.
  - **Kiểm tra 5 tab, Universal Links / URL redirect & thông báo nhắc học:** `SceneDelegate` (`GIDSignIn` URL handler + `DailyStudyReminder`), `MainPresenter` (5 tab `Today`, `Dictionary`, `Card`, `Discover`, `Setting`) và mọi `accessibilityIdentifier` dùng cho UI test đều nguyên vẹn.

### 3.3. Nhóm `KEEP` (`K01` – `K08`) & Săn Lỗi Mới Trên Toàn Bộ 30 Module

- Đã đọc trực tiếp mã nguồn ViewController/Presenter/Wireframe của tất cả **30 thư mục module** (35 bề mặt màn hình: `StartUp`, `Main`, `Today` + `DailyRadar`, `Home`, `LevelEntryDetail`, `LessonList`, `LessonReader` + `Shadowing`, `LessonPractice`, `LifeLesson`, `ScenarioList` + `ScenarioPlay`, `Dictionary`, `DictionaryEntry`, `DictionaryHandwriting`, `DictionarySaved`, `DictionaryScan`, `DictionaryVoice`, `Card` + `NewDeckOptions`, `CardReview`, `CardStudy` + `KanjiWriting`, `CardStyle`, `CreateDesk` + `BulkImport` + `PictureSearch`, `DeckGenerator`, `ExampleEditor`, `OftenMissed`, `RemoteDeck` + `SharedDeck`, `Discover`, `Magazine` + `MagazineArticle`, `Loto`, `Setting` + `DataExport`, `MailLogin`).
- **Tất cả 8 lập luận `KEEP` (`K01` – `K08`) đều vững chắc:** hai lối vào `HomeWireframe` từ `Today` và `Discover` dùng chung một module duy nhất (`K01`); 3 bước tạo bộ thẻ và 3 bước chia sẻ/tải bộ thẻ phục vụ các luồng khác nhau (`K02`, `K03`); `CardReview` (SRS server) và `CardStudy` (FSRS Realm offline) tách biệt nguồn dữ liệu theo ràng buộc không đụng API/Realm (`K04`); các nguồn bài học `LifeLesson` / `Scenario` / `LessonReader` / `Magazine` / `Loto` và 3 ô tìm kiếm phục vụ miền dữ liệu riêng (`K05`, `K06`); `"Report an ad"` và các đường dẫn phụ thuộc tính năng backend như `PictureSearch` 503 fallback hay `ReviewSync` (`K07`, `K08`) đều suy giảm an toàn, không có nút chết (`0` `UIAction` rỗng, `0` màn placeholder `"Coming soon"`).

---

## 4. Kiểm chứng Các Ràng buộc Cứng (`AGENTS.md` & `ENGINEERING_GUARDRAILS.md`)

| Ràng buộc | Bằng chứng kiểm chứng thực tế | Kết quả |
|---|---|---|
| **Không đổi Realm schema / model lưu trữ** | `git diff 2c1b2b0..HEAD -- FlashcardApp/Services FlashcardApp/DataManager FlashcardApp/Entities` → **rỗng (`0` thay đổi)**; `RealmService.schemaVersion == 7` giữ nguyên. | **ĐẠT** |
| **Không đổi API client / DTO / xác thực Keychain** | `git diff 2c1b2b0..HEAD -- FlashcardApp/Networks` → **rỗng (`0` thay đổi)**; giữ nguyên UUID backend trên `LevelEntry.dictionaryItem`. | **ĐẠT** |
| **Không thêm dependency mới** | `git diff 2c1b2b0..HEAD -- FlashcardApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` → **rỗng (`0` thay đổi)**. | **ĐẠT** |
| **Không có quảng cáo trong màn học / ôn tập** | `grep -rn "AdsBannerView\|BannerView\|GoogleMobileAds" FlashcardApp/` → chỉ xuất hiện tại `Services/AdsService.swift`, `TodayViewController.swift` và `HomeViewController.swift` (`!presenter.isContent`, tức chỉ ở danh sách cấp độ, tắt cả ở danh sách từ/kanji/ngữ pháp). **0 quảng cáo** trong `CardStudy`, `CardReview`, `KanjiWriting`, `LessonReader`, `LessonPractice`, `LifeLesson`, `ScenarioPlay`, `LevelEntryDetail`. | **ĐẠT** |
| **Giữ nguyên UIKit + VIPER & đa ngôn ngữ `vi`/`en`/`ja`** | Toàn bộ module mới/sửa tuân thủ UIKit + VIPER (`ViewController` / `Presenter` / `Wireframe`), cập nhật UI trên main thread, dùng `[weak self]` tránh retain cycle; `4/4` khóa mới trong `Localizable.xcstrings` có đủ bản dịch `vi`/`en`/`ja` (`LocalizationTests`: **10/10 pass**). | **ĐẠT** |

---

## 5. Bằng chứng Tự Chạy Lại Toàn Bộ Build & Test

### 5.1. Kiểm tra môi trường (`environment-validation.sh`)
```bash
sh scripts/tests/environment-validation.sh
```
- **Kết quả:** `Environment validation: 26 cases passed.` (`26/26`)

### 5.2. Build cả 3 scheme trên iOS Simulator (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`)
```bash
xcodebuildmcp simulator build --project-path "$PWD/FlashcardApp.xcodeproj" --scheme FlashcardApp --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 --extra-args "CODE_SIGNING_ALLOWED=NO"
xcodebuildmcp simulator build --project-path "$PWD/FlashcardApp.xcodeproj" --scheme FlashcardApp-Local --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 --extra-args "CODE_SIGNING_ALLOWED=NO"
xcodebuildmcp simulator build --project-path "$PWD/FlashcardApp.xcodeproj" --scheme FlashcardApp-Production --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 --extra-args "CODE_SIGNING_ALLOWED=NO"
```
- **Trước sửa (`a36fc90`):**
  - `FlashcardApp`: `✅ Build succeeded. (⏱️ 147.3s)`
  - `FlashcardApp-Local`: `✅ Build succeeded. (⏱️ 7.9s)`
  - `FlashcardApp-Production`: `✅ Build succeeded. (⏱️ 118.1s)`
- **Sau sửa `P1` (`cb52c46`):**
  - `FlashcardApp`: `✅ Build succeeded. (⏱️ 10.7s)`
  - `FlashcardApp-Local`: `✅ Build succeeded. (⏱️ 5.4s)`
  - `FlashcardApp-Production`: `✅ Build succeeded. (⏱️ 86.1s)`

### 5.3. Chạy `LocalizationTests` & FULL `FlashcardAppTests`
```bash
xcodebuildmcp simulator test \
  --project-path "$PWD/FlashcardApp.xcodeproj" \
  --scheme FlashcardApp-Local \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO" "-parallel-testing-enabled" "NO" "-only-testing:FlashcardAppTests/LocalizationTests"

xcodebuildmcp simulator test \
  --project-path "$PWD/FlashcardApp.xcodeproj" \
  --scheme FlashcardApp-Local \
  --simulator-id AAEE78CE-966D-4502-B637-C4A5C83CDC36 \
  --extra-args "CODE_SIGNING_ALLOWED=NO" "-parallel-testing-enabled" "NO" "-only-testing:FlashcardAppTests"
```
- **`LocalizationTests`:**
  - Trước sửa (`a36fc90`): **`10/10 passed, 0 failed, 0 skipped`** (`⏱️ 63.9s`)
  - Sau sửa (`cb52c46`): **`10/10 passed, 0 failed, 0 skipped`** (`⏱️ 44.0s`)
- **FULL `FlashcardAppTests`:**
  - Trước sửa (`a36fc90`): `1561` discovered → **`1548 passed, 0 failed, 13 skipped`** (`⏱️ 81.7s`)
  - Sau sửa (`cb52c46`, thêm `+2` regression tests trong `LevelEntryDetailPresenterTests` → `8/8` pass): `1563` discovered → **`1550 passed, 0 failed, 13 skipped`** (`⏱️ 78.2s`)
  - Giải thích `13` test `XCTSkip` (giống hệt baseline `main`): `5` test `KeychainAuthTokenManagerTests` do chạy không ký `CODE_SIGNING_ALLOWED=NO` (`-34018`), `7` test `LiveProductionContractTests` opt-in, và `1` test `LocalBackendReviewSyncTests` opt-in khi backend local `:18081` tắt.

### 5.4. Kiểm chứng UI thực tế trên Simulator (`FlashcardApp-Production` kết nối `https://kiokoto.com/api`)
- Build & khởi chạy `com.ds.FlashcardApp` (`FlashcardApp-Production`) ở Light Mode, ngôn ngữ Tiếng Việt (`-AppleLanguages (vi)`), điều hướng `Khám phá` → `Cấp độ` → `J4 — Sơ trung cấp` → `Ngữ pháp` → `… いぜん`, xác nhận bằng XCUITest `level_entry_detail` được push thật, `level_entry_listen.exists == false`, `level_entry_open_dictionary.exists == true`, không bật alert, và xuất ảnh mới `docs/plans/completion-2026-11-26/shots/after_level_entry_grammar_light.png`.

---

## 6. Các Hạng mục Chưa Kiểm chứng (`NOT VERIFIED`)

1. **Suite `FlashcardAppUITests` phụ thuộc backend Go cục bộ (`http://localhost:18081/api`):** Máy chủ local `:18081` hiện tắt (`HTTP 000`), nên không chạy toàn bộ UI test nhắm vào `localhost:18081` theo đúng hướng dẫn trong `docs/DEVELOPMENT.md`.
2. **5 test Keychain thật (`KeychainAuthTokenManagerTests`):** Chưa chạy với chứng chỉ ký thật (`CODE_SIGNING_ALLOWED=YES`) do môi trường Simulator không ký trả mã `-34018`.
3. **Các luồng ghi dữ liệu tài khoản thật & phần cứng vật lý:** Không đăng nhập tài khoản thật hay gửi mutation lên production (`CardReview` chấm thẻ, `BJTBookmarkAPI` toggle, `DataExport`), và chưa kiểm chứng camera/micro vật lý (`DictionaryScan`, `DictionaryVoice`, `Shadowing` thu âm thật) trên iPhone thật.
