# FlashcardApp — Báo cáo ổn định & Baseline (2026-11-25)

## 1. Trạng thái trước và sau

### Trước khi thực hiện
- **Nhánh**: `main` đang ahead `origin/main` **122 commit** (HEAD cũ: `bc73b0a`, `origin/main`: `10b762b`).
- **Working tree**: bẩn với 34 tệp tracked modified/deleted và nhiều tệp untracked thuộc đợt tích hợp AdMob + dọn cảnh báo iOS 26 làm dở, xen lẫn các tệp rác hệ thống/tooling.
- **Đánh giá nhanh phạm vi dở dang**:
  - `AdsService.swift` và `AdsServiceTests.swift` đã được tham chiếu đúng target membership trong `FlashcardApp.xcodeproj/project.pbxproj` (`FlashcardApp` và `FlashcardAppTests`), cùng 2 SPM package `GoogleMobileAds` (`13.12.0`) và `GoogleUserMessagingPlatform` (`3.1.0`) trong `Package.resolved`.
  - `FlashcardApp/Info.plist` đã có `GADApplicationIdentifier` (`$(ADMOB_APP_ID)`), `AdMobBannerUnitID` (`$(ADMOB_BANNER_UNIT_ID)`) và 50 `SKAdNetworkItems` hợp lệ của Google AdMob.
  - `DevelopmentConfig.xcconfig` sử dụng **Google official sample test IDs** (`ca-app-pub-3940256099942544~1458002511` và `ca-app-pub-3940256099942544/2435281174`); giữ nguyên cho build Local/Debug.
  - `ReleaseConfig.xcconfig` đang chứa cặp AdMob ID cũ (`ca-app-pub-3369705605881794~7848404031` và `ca-app-pub-3369705605881794/9212235403`) kèm ghi chú cần xác minh lại quyền sở hữu và trạng thái trên AdMob trước khi phát hành.
  - **ATT (`NSUserTrackingUsageDescription`)**: hiện app **chưa** gọi `ATTrackingManager.requestTrackingAuthorization` và chưa bật ATT; chỉ sử dụng Google UMP consent flow (`AdsService`). Do đó chưa thêm `NSUserTrackingUsageDescription` vào `Info.plist` (phù hợp với bản nháp `docs/privacy/admob-release-draft.md` — cần quyết định rõ trước khi phát hành).
  - 5 colorset (`DarkGray`, `LightGray`, `PlaceholderText`, `Primary`, `Secondary`) đã đổi tên sang tiền tố `App*` để tránh đụng tên sinh tự động; `AppColor.swift` đã cập nhật khớp 100%, không còn tham chiếu tên cũ trong `FlashcardApp/`.

### Rác đã khôi phục / không commit
- **Đã khôi phục bằng `git checkout --`**:
  - `.DS_Store`
  - `FlashcardApp/.DS_Store`
  - `.claude/skills/ui-ux-pro-max/scripts/__pycache__/core.cpython-314.pyc`
  - `.claude/skills/ui-ux-pro-max/scripts/__pycache__/design_system.cpython-314.pyc`
- **Giữ nguyên ngoài commit (tooling ngoài repo, tuyệt đối không commit)**:
  - `.agents/skills/design-taste-frontend/`
  - `.claude/skills/design-taste-frontend`
  - `.continue/`
  - `.hermes/`
  - `skills/`
  - `skills-lock.json` (chỉ chứa entry `design-taste-frontend` đi kèm thư mục skill ngoài repo; không stage/commit, không ghi đè work-in-progress tooling).

### Sau khi hoàn tất Pha 1
- Tạo 4 commit theo nhóm logic, kiểm tra `git show --stat HEAD` sau mỗi commit và đẩy toàn bộ `main` lên `origin/main`.
- `git status -sb` xác nhận `## main...origin/main` (khớp hoàn toàn `40df1b3838d150b9c5318961153eaa0b33d8c3ca` trước commit báo cáo này).

---

## 2. Các commit đã tạo trong Pha 1

| Thứ tự | Hash | Thông điệp | Phạm vi |
| --- | --- | --- | --- |
| 1 | `017657a` | `refactor(assets): rename colliding color assets to App* names` | Đổi tên 5 colorset sang `App*` + cập nhật `AppColor.swift` (6 tệp) |
| 2 | `cdcc113` | `fix: resolve iOS 26 deprecations, launch notification XPC block, and Swift warnings` | `SettingInteractor`, `MailLoginViewController`, `RemoteImageLoader`, `LifePlaceProvider`, `RealmService`, 6 unit test + `DictionaryUITests` (12 tệp) |
| 3 | `e2eddac` | `feat(ads): integrate Google Mobile Ads banners and UMP consent flow` | `project.pbxproj`, `Package.resolved`, `DevelopmentConfig.xcconfig`, `ReleaseConfig.xcconfig`, `Info.plist`, `AdsService.swift`, `HomeViewController`, `TodayViewController`, `SettingPresenter`, `SettingViewController`, `Localizable.xcstrings`, `AdsServiceTests.swift`, `SettingPresenterTests.swift` (13 tệp) |
| 4 | `40df1b3` | `docs(privacy): add AdMob iOS release privacy draft` | `docs/privacy/admob-release-draft.md` (1 tệp) |

- **Kết quả push Pha 1**: `git push origin main` thành công (`10b762b..40df1b3  main -> main`), đồng bộ tổng cộng 126 commit lên `origin/main`.

---

## 3. Kết quả kiểm thử (Simulator)

Thiết bị Simulator dùng xuyên suốt (one-Simulator fast loop):
- **Simulator**: `iPhone 17` (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS `27.2`, Booted)
- **Scheme**: `FlashcardApp-Local`, `CODE_SIGNING_ALLOWED=NO`, `-parallel-testing-enabled NO`

### 3.1. Script kiểm tra môi trường
- Lệnh: `sh scripts/tests/environment-validation.sh`
- Kết quả: **26/26 cases passed**.

### 3.2. Targeted tests (Pha 1, trước khi commit)
- Các suite đã chạy: `AdsServiceTests`, `SettingPresenterTests`, `LocalizationTests`, `CardPresenterUploadTests`, `LessonProgressStoreTests`, `LessonReaderPresenterTests`, `LessonWordSaverTests`, `MailLoginPresenterTests`, `TodayLessonSlotTests`.
- Kết quả: **137 passed / 0 failed / 0 skipped** (`0.690s`, build sạch không có warning trong `FlashcardApp/`).

### 3.3. Full unit test baseline `FlashcardAppTests` (Pha 2, trên HEAD sạch `40df1b3`)
- Lệnh:
  ```sh
  xcodebuild test \
    -project "$PWD/FlashcardApp.xcodeproj" \
    -scheme FlashcardApp-Local \
    -destination "platform=iOS Simulator,id=AAEE78CE-966D-4502-B637-C4A5C83CDC36" \
    CODE_SIGNING_ALLOWED=NO \
    -enableCodeCoverage YES \
    -only-testing:FlashcardAppTests \
    -parallel-testing-enabled NO
  ```
- Kết quả thật từ log (`** TEST SUCCEEDED **`):
  - **Tổng số test thực thi**: **1545**
  - **Pass**: **1532**
  - **Fail**: **0** (không có pre-existing failure nào trong unit test)
  - **Skip**: **13** (có chủ đích theo môi trường test):
    - `KeychainAuthTokenManagerTests` (**5 tests**): skip do build không ký (`CODE_SIGNING_ALLOWED=NO`, Keychain status `-34018`) — đúng hành vi ghi nhận trong `docs/DEVELOPMENT.md`.
    - `LiveProductionContractTests` (**7 tests**): skip do là test contract với server production thật.
    - `LocalBackendReviewSyncTests` (**1 test**): skip do yêu cầu backend local đang chạy.
- Thời gian chạy suite: `54.033s` (`54.660s` wall clock).

---

## 4. Kết quả build máy thật (`FlashcardApp-Local`)

- **Trạng thái**: **NOT VERIFIED (BLOCKED)**
- **Kiểm tra kết nối thiết bị**:
  - `xcrun devicectl list devices` và `xcrun xctrace list devices` cho thấy thiết bị `iPhone70 (2)` (`iPhone 14 Plus`, model `iPhone14,8`, iOS `27.0.1`, UDID `00008110-000678E22186401E`) đang ở trạng thái **`unavailable` / Offline** (không kết nối).
- **Kiểm tra biên dịch `iphoneos` (`xcodebuild build -scheme FlashcardApp-Local -destination "generic/platform=iOS"`)**:
  - Dừng ngay ở bước ký / provisioning profile (không tự đổi team, signing hay capability):
    - `error: Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the Sign In with Apple capability. (in target 'FlashcardApp' from project 'FlashcardApp')`
    - `error: Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the com.apple.developer.applesignin entitlement. (in target 'FlashcardApp' from project 'FlashcardApp')`
- **Thao tác tay chủ máy cần thực hiện để mở khóa build máy thật**:
  1. Kết nối `iPhone 14 Plus` (`iPhone70 (2)`) qua cáp USB (hoặc bật mạng cục bộ đã pair), mở khóa máy, chọn **Trust This Computer**, và đảm bảo **Settings → Privacy & Security → Developer Mode** đang bật.
  2. Mở `FlashcardApp.xcodeproj` trong Xcode với tài khoản Apple Developer Program có quyền cấp phát capability **Sign In with Apple** cho App ID `com.ds.FlashcardApp.dev` (App ID rõ ràng thay cho wildcard `iOS Team Provisioning Profile: *`), rồi bật/làm mới **Automatically manage signing** hoặc tải lại provisioning profile cho `com.ds.FlashcardApp.dev` có bật `Sign In with Apple` (`com.apple.developer.applesignin`).
  3. Chạy lại `xcodebuild build -scheme FlashcardApp-Local -destination "id=00008110-000678E22186401E"` (hoặc Run trực tiếp từ Xcode).

---

## 5. Blocker & việc cần làm trước khi phát hành (Release)

1. **AdMob IDs & kiểm chứng tài khoản**:
   - `DevelopmentConfig.xcconfig` đang dùng Google official test IDs (`ca-app-pub-3940256099942544~1458002511` / `/2435281174`) — phù hợp cho Local/Debug.
   - `ReleaseConfig.xcconfig` đang chứa AdMob ID lịch sử (`ca-app-pub-3369705605881794~7848404031` / `/9212235403`) — chủ sở hữu cần xác minh trực tiếp trên AdMob Console rằng các ID này còn hoạt động và thuộc đúng ứng dụng trước khi Archive Release.
2. **ATT (`NSUserTrackingUsageDescription`) & quyền riêng tư App Store**:
   - Hiện app chỉ chạy UMP consent và chưa gọi ATT (`ATTrackingManager`). Trước khi phát hành cần chốt phương án ATT (có bật IDFA/ATT hay không), cập nhật chính sách quyền riêng tư (`docs/privacy/admob-release-draft.md`), hoàn tất khai báo App Privacy & Age Rating trên App Store Connect.
3. **Provisioning máy thật (`FlashcardApp-Local`)**:
   - Đang bị chặn bởi wildcard provisioning profile thiếu capability `Sign In with Apple` và máy `iPhone 14 Plus` đang offline (xem Mục 4).
4. **Google Sign-In cho Local (`.dev`)**:
   - Theo `docs/DEVELOPMENT.md`, `GOOGLE_IOS_CLIENT_ID_PREFIX` trong `DevelopmentConfig.xcconfig` vẫn để trống nên nút Google ẩn trên bản Local; cần tạo iOS OAuth client cho `com.ds.FlashcardApp.dev` nếu muốn test đăng nhập Google trên Local.
5. **UI Tests (`FlashcardAppUITests`) & Keychain / Live Contract tests**:
   - Chưa chạy `FlashcardAppUITests` và 13 unit test bị skip (cần bản build có ký cho Keychain, backend local đang chạy cho `LocalBackendReviewSyncTests`/UI tests, và môi trường riêng cho `LiveProductionContractTests`).
