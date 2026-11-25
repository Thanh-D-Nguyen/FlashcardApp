# Báo cáo Review Độc lập (Adversarial) — `uiux-overhaul-2026-11-25`

- **Ngày kiểm toán**: 2026-11-25 (JST)
- **Nhánh được review**: `uiux-overhaul-2026-11-25` (so với `main`)
- **Commit gốc khi bắt đầu review**: `bc73b0a59efb94525cd3f316a9c32526eb8c87d5` (cả `main` và `uiux-overhaul-2026-11-25` cùng trỏ một commit)
- **Worktree của nhánh**: `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul`
- **Verdict**: **CHƯA ĐẠT**
- **Tổng hợp lỗi**: `P0 = 1`, `P1 = 1`, `P2 = 2`, `P3 = 1` — **Đã tự sửa (`FIXED`) = `0`**

---

## 1. Kết luận tổng quan (`CHƯA ĐẠT`)

Nhánh `uiux-overhaul-2026-11-25` **CHƯA ĐẠT** điều kiện nghiệm thu vì **toàn bộ sản phẩm bàn giao của đợt UI/UX overhaul chưa tồn tại trên nhánh**:

1. Diff `main...uiux-overhaul-2026-11-25` hoàn toàn rỗng (`0` commit mới, `0` file thay đổi, `0` byte diff); nhánh `origin/uiux-overhaul-2026-11-25` chưa từng được đẩy lên remote trước thời điểm review.
2. Báo cáo `docs/ui-redesign/overhaul-2026-11-25/OVERHAUL_REPORT.md` không tồn tại.
3. Hai thư mục `docs/ui-redesign/overhaul-2026-11-25/before/` và `docs/ui-redesign/overhaul-2026-11-25/after/` trong worktree `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul` (tạo lúc `2026-11-25 13:03 +0900`) hoàn toàn trống (`0` file ảnh).

Theo đúng vai trò Reviewer độc lập (*"Bạn KHÔNG phải người viết code này — nhiệm vụ của bạn là tìm lỗi thật"*) và quy chuẩn tại `docs/ENGINEERING_GUARDRAILS.md` §5 (*"Screenshots are evidence only if captured from the rendered app, not mockups... Do not report PASS if a required gate remains unverified"*), Reviewer **không được tự ý bịa đặc tả để thiết kế lại UI thay cho tác giả**, cũng **không được ngụy tạo `OVERHAUL_REPORT.md` hay ảnh chụp màn hình giả**. Do đó cả `P0-01` và `P1-01` đều giữ trạng thái `UNFIXED` (`FIXED = 0`) và nhánh bị đánh trượt (`CHƯA ĐẠT`).

> Lưu ý bảo vệ cây làm việc chung (`AGENTS.md` Rule 1 & `docs/ENGINEERING_GUARDRAILS.md` §2): thư mục gốc `/Users/thanhnguyen/Documents/Develop/FlashcardApp` đang ở nhánh `main` và có ~30 file dở dang chưa commit từ ngày `2026-11-12` của một luồng công việc khác (`AdsService.swift`, `AppColor.swift`, v.v.). Reviewer giữ nguyên tuyệt đối trạng thái của `main` và chỉ thao tác trên worktree riêng của nhánh `uiux-overhaul-2026-11-25`.

---

## 2. Bảng Findings chi tiết

| Mã | Mức độ | Nhóm | Mô tả lỗi & Bằng chứng thực tế | Xử lý của Reviewer |
| --- | --- | --- | --- | --- |
| **P0-01** | **P0** | Deliverable / Diff nhánh | `git rev-list --left-right --count main...uiux-overhaul-2026-11-25` trả về `0	0`; cả `main` và `uiux-overhaul-2026-11-25` cùng trỏ `bc73b0a59efb94525cd3f316a9c32526eb8c87d5`. Không có bất kỳ thay đổi mã nguồn UI/UX overhaul nào được commit hoặc lưu trong working tree của nhánh. | **CHƯA SỬA (`UNFIXED`)** — Tác vụ overhaul chưa được thực thi; Reviewer không viết code tính năng/UI thay tác giả khi không có đặc tả phạm vi. |
| **P1-01** | **P1** | Bằng chứng báo cáo & ảnh `before/after` | Không tồn tại `docs/ui-redesign/overhaul-2026-11-25/OVERHAUL_REPORT.md`. Hai thư mục `docs/ui-redesign/overhaul-2026-11-25/before/` và `after/` hoàn toàn rỗng (`0` file ảnh). Không thể đối chiếu từng màn hình giữa báo cáo, ảnh chụp và mã nguồn. | **CHƯA SỬA (`UNFIXED`)** — Không được phép tạo báo cáo giả hoặc ảnh chụp giả cho các thay đổi chưa diễn ra. |
| **P2-01** | **P2** | (f) Rác trong Git / Worktree | Dù diff `main...uiux-overhaul-2026-11-25` rỗng, cây Git của nhánh tại `bc73b0a` đang track sẵn **14 file rác** từ các commit cũ: **11** file `.DS_Store` (`.DS_Store`, `FlashcardApp/.DS_Store`, `FlashcardApp/Assets.xcassets/.DS_Store`, `.../Colors/.DS_Store`, `.../Images/.DS_Store`, `.../Images/Flags/.DS_Store`, `.../Images/Welcome/.DS_Store`, `FlashcardApp/Commons/.DS_Store`, `FlashcardApp/Modules/.DS_Store`, `FlashcardApp/Networks/.DS_Store`, `FlashcardApp/Vendors/.DS_Store`) và **3** file bytecode Python `.claude/skills/ui-ux-pro-max/scripts/__pycache__/{core,design_system,search}.cpython-314.pyc`. Ngoài ra worktree `FlashcardApp-uiux-overhaul` bỏ dở 2 thư mục rỗng untracked `before/` và `after/`. | Chỉ ghi nhận (quy tắc P2/P3 không tự sửa). |
| **P2-02** | **P2** | Chất lượng Unit Test hiện hữu | Tại `FlashcardAppTests/DeckPublishTests.swift:256` trên nhánh `uiux-overhaul-2026-11-25` (`bc73b0a`), lệnh `presenter.view = SpyCardView()` gán trực tiếp thực thể tạm vào thuộc tính `weak var view`, làm trình biên dịch cảnh báo `instance will be immediately deallocated because property 'view' is 'weak'` và khiến `presenter.view` trở thành `nil` ngay sau `setUp()`. | Chỉ ghi nhận (lỗi tồn tại sẵn từ `main`, quy tắc P2/P3 không tự sửa). |
| **P3-01** | **P3** | Cảnh báo trình biên dịch Test | Quá trình biên dịch test trên `FlashcardApp-Local` phát sinh thêm **18** cảnh báo trình biên dịch khác ở target test: `16` cảnh báo unused result (`#NoUsage`) tại `TodayLessonSlotTests.swift`, `LessonWordSaverTests.swift`, `LessonProgressStoreTests.swift`, `LessonReaderPresenterTests.swift`; `1` biến `field` không dùng tại `DictionaryUITests.swift:263`; `1` biến `weak releasedPresenter` không bị thay đổi tại `MailLoginPresenterTests.swift:329`. | Chỉ ghi nhận (quy tắc P2/P3 không tự sửa). |

---

## 3. Rà soát theo 6 nhóm săn lỗi bắt buộc

| Nhóm kiểm tra | Kết quả trên `main...uiux-overhaul-2026-11-25` |
| --- | --- |
| **(a) Hồi quy chức năng / điều hướng đổi ngoài ý muốn** | `0` file mã nguồn thay đổi so với `main`. Baseline hiện tại vượt qua `1527/1540` bài unit test (`0` failed, `13` skipped hợp lệ); chưa có code overhaul mới để phát sinh hồi quy điều hướng. |
| **(b) Rò rỉ thay đổi nghiệp vụ / API / Realm** | `0` thay đổi tại `Networks/`, `Services/`, `Interactors/`, `DataManager/`, `Entities/`, `RealmService.swift` trên diff `main...uiux-overhaul-2026-11-25`. |
| **(c) Dynamic Type AX lớn, tương phản Dark Mode, nhãn VoiceOver** | **CHƯA ĐẠT / NOT VERIFIED cho đợt overhaul** do chưa có bất kỳ thay đổi UI hay ảnh chụp `before/after` nào trên nhánh (`P0-01`, `P1-01`). |
| **(d) Retain cycle / cập nhật UI ngoài main thread trong code mới sửa** | `0` dòng code mới sửa trong diff `main...uiux-overhaul-2026-11-25`. |
| **(e) Thiếu target membership (`project.pbxproj`)** | Đã đối chiếu toàn bộ `427` file `.swift` trong cây Git `uiux-overhaul-2026-11-25` với `FlashcardApp.xcodeproj/project.pbxproj`: **427/427 có mặt (`0` thiếu)**; build `FlashcardApp-Local` thành công. |
| **(f) Commit lẫn rác (`.DS_Store`, `.pyc`, thư mục tooling)** | `0` file rác mới trong diff `main...uiux-overhaul-2026-11-25`, nhưng phát hiện **14 file rác đang được track sẵn** trên nhánh từ `main` (`11` `.DS_Store` + `3` `.pyc`) — đã ghi nhận tại **P2-01**. |
| **Chuỗi cứng hiển thị cho người dùng (i18n)** | `0` chuỗi cứng mới được thêm (diff `0` byte). `Localizable.xcstrings` hiện có `1.151` khoá; `LocalizationTests` chạy riêng đạt `10/10`. |

---

## 4. Những gì đã tự chạy để kiểm chứng (lệnh & kết quả số thật)

Môi trường chạy thực tế: macOS, Simulator **iPhone 17e — iOS 26.5** (`UDID: 4D3A7DC6-7A3C-4BBB-98D6-A962E27CFA82`), project `/Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj`, scheme `FlashcardApp-Local`.

1. **Kiểm tra trạng thái nhánh, remote và diff `main...uiux-overhaul-2026-11-25`**:
   ```sh
   git fetch origin
   git rev-parse main uiux-overhaul-2026-11-25
   git rev-list --left-right --count main...uiux-overhaul-2026-11-25
   git diff --stat main...uiux-overhaul-2026-11-25
   git -C /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul status --short --branch
   ```
   - Kết quả thật:
     - `main` = `bc73b0a59efb94525cd3f316a9c32526eb8c87d5`
     - `uiux-overhaul-2026-11-25` = `bc73b0a59efb94525cd3f316a9c32526eb8c87d5`
     - `rev-list --left-right --count` = `0	0`
     - `diff --stat` = rỗng (`0` byte)
     - `origin/uiux-overhaul-2026-11-25` chưa tồn tại trước khi push bản review này.

2. **Kiểm tra quy tắc cấu hình môi trường (`Validate Environment`)**:
   ```sh
   /bin/sh scripts/tests/environment-validation.sh
   ```
   - Kết quả thật: `Environment validation: 26 cases passed.`

3. **Kiểm tra target membership (`project.pbxproj`) & file rác được track**:
   ```sh
   git ls-tree -r --name-only uiux-overhaul-2026-11-25
   ```
   - Kết quả thật: `427` file `.swift` trong cây nguồn, `0` file thiếu trong `project.pbxproj`; `14` file rác (`.DS_Store` / `.pyc`) được track sẵn từ lịch sử `main`.

4. **Build scheme `FlashcardApp-Local`**:
   ```sh
   xcodebuildmcp simulator build \
     --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
     --scheme FlashcardApp-Local \
     --simulator-id 4D3A7DC6-7A3C-4BBB-98D6-A962E27CFA82 \
     --extra-args CODE_SIGNING_ALLOWED=NO
   ```
   - Kết quả thật: **Build succeeded** (`15.4s`, `0` lỗi biên dịch).

5. **Chạy riêng `LocalizationTests`**:
   ```sh
   xcodebuildmcp simulator test \
     --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
     --scheme FlashcardApp-Local \
     --simulator-id 4D3A7DC6-7A3C-4BBB-98D6-A962E27CFA82 \
     --extra-args CODE_SIGNING_ALLOWED=NO -only-testing:FlashcardAppTests/LocalizationTests -parallel-testing-enabled NO
   ```
   - Kết quả thật: **10 tests passed, 0 failed, 0 skipped** (`125.6s`); `Localizable.xcstrings` có `1.151` khoá hợp lệ cho `vi` / `en` / `ja`.

6. **Chạy FULL `FlashcardAppTests`**:
   ```sh
   xcodebuildmcp simulator test \
     --project-path /Users/thanhnguyen/Documents/Develop/FlashcardApp-uiux-overhaul/FlashcardApp.xcodeproj \
     --scheme FlashcardApp-Local \
     --simulator-id 4D3A7DC6-7A3C-4BBB-98D6-A962E27CFA82 \
     --extra-args CODE_SIGNING_ALLOWED=NO -only-testing:FlashcardAppTests -parallel-testing-enabled NO
   ```
   - Kết quả thật: **Discovered 1540 test(s) — 1527 passed, 0 failed, 13 skipped** (`103.2s`, `19` compiler warnings ở target test).
   - Lý do 13 bài skip: các điều kiện `XCTSkip` chủ đích khi build không ký (`CODE_SIGNING_ALLOWED=NO` không cấp Keychain cho các bài Keychain trong `AuthSessionTests`, đúng như ghi chú tại `docs/DEVELOPMENT.md`) và các bài kiểm thử hợp đồng opt-in cần token/server riêng (`LiveProductionContractTests`, `ReviewSyncTests`).

---

## 5. Phần chưa kiểm chứng được (`NOT VERIFIED`)

1. **Đối chiếu trực quan từng màn hình `before/after` và nội dung `OVERHAUL_REPORT.md`**: **NOT VERIFIED** — file báo cáo không tồn tại và hai thư mục `before/`, `after/` trống (`0` ảnh).
2. **Kiểm chứng giao diện sau overhaul ở cỡ chữ lớn Dynamic Type (AX), Dark Mode, và nhãn VoiceOver**: **NOT VERIFIED** — chưa có bất kỳ commit thay đổi giao diện nào trên nhánh `uiux-overhaul-2026-11-25` để kiểm tra.
3. **Suite `FlashcardAppUITests` cần backend local đang chạy (`http://localhost:18081/api`), Keychain trên bản build có ký (`CODE_SIGNING_ALLOWED=YES`), và thiết bị iPhone/iPad vật lý**: **NOT VERIFIED** trong lượt review này (không thay đổi kết luận `CHƯA ĐẠT` do nhánh chưa có thay đổi overhaul).
