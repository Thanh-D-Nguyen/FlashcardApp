# Phát triển FlashcardApp

## Claude Agent trong Xcode

Mở repo này bằng Xcode và bắt đầu phiên Claude Agent mới để nhận thư mục hướng dẫn
vừa thêm. `CLAUDE.md` nhập `AGENTS.md`; quy tắc chung chỉ có một nguồn để bảo trì.
Không cần thay cấu hình Claude toàn máy hay cài thêm plugin.

| Thành phần | Dùng khi |
| --- | --- |
| `flashcard-architect` | Thiết kế thay đổi qua nhiều lớp, migration Realm, auth |
| `flashcard-reviewer` | Review lỗi chức năng, bảo mật, API và nguy cơ mất dữ liệu |
| `flashcard-verifier` | Kiểm chứng build/test, phân biệt lỗi app với lỗi công cụ |
| `/flashcard-feature` | Phát triển/sửa một tính năng UIKit theo cấu trúc hiện có |
| `/flashcard-api-contract` | Kiểm tra endpoint, payload và mapping BJT |
| `/flashcard-release` | Kiểm tra môi trường và điều kiện phát hành |

Ví dụ prompt: “Dùng flashcard-reviewer review diff hiện tại, ưu tiên auth và Realm;
trả về lỗi có thể tái hiện.” Hoặc “/flashcard-feature sửa lỗi lưu deck; viết regression
test rồi build/test bằng công cụ Xcode.” Nếu phiên Xcode không hỗ trợ gọi subagent,
yêu cầu Claude đọc file agent tương ứng và thực hiện trong phiên chính.

Claude Agent dùng môi trường cấu hình riêng trong Xcode; không suy ra việc CLI
nhận được một skill đồng nghĩa phiên IDE cũng nhận được nó. Kiểm tra menu `/` và
yêu cầu agent nêu những file hướng dẫn đã đọc trong phiên mới. Bộ file đã được
kiểm tra cấu trúc; khả năng nạp trong phiên Claude hiện tại cần xác nhận ở IDE.
Tham khảo [Apple về tùy chỉnh agent](https://developer.apple.com/documentation/Xcode/extending-and-customizing-agents),
[Claude project agents](https://code.claude.com/docs/en/sub-agents) và
[Claude project skills](https://code.claude.com/docs/en/skills).

## Kiến trúc và ranh giới

Giữ cấu trúc hiện tại: ViewController render/gửi sự kiện → Presenter điều phối state
→ Interactor thực hiện use case → API hoặc local manager. Wireframe lắp module và
điều hướng. Entities/DTO là dữ liệu trao đổi; Realm Object chỉ dùng đúng thread và
transaction. Không cần thêm framework kiến trúc để đạt chất lượng production.

UIKit/storyboard và iOS 17 là nền hiện tại. Dependencies dùng SPM với
`FlashcardApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Giữ lockfile trong Git; nâng phiên bản từng nhóm với build và regression test.
Không regenerate Swagger đè thay đổi thủ công, không đổi Realm key mà bỏ migration.

Client BJT mới là phần đang chuyển đổi. Luồng chạy vẫn còn sử dụng client legacy.
Tích hợp từng use case: xác minh contract → fixture test → adapter/persistence →
interactor → kiểm tra UI. Rollback client/schema phải bảo toàn dữ liệu đã ghi;
không dùng xóa database như một cách xử lý migration lỗi.

## Local / staging / production

| Scheme | Configuration | Bundle ID | API |
| --- | --- | --- | --- |
| FlashcardApp-Local | Debug | com.ds.FlashcardApp.dev | localhost:4000/api |
| FlashcardApp-Staging | Staging | com.ds.FlashcardApp.staging | Chưa cấu hình |
| FlashcardApp-Production | Release | com.ds.FlashcardApp | Chưa cấu hình |

Scheme `FlashcardApp` cũ vẫn tương thích: Run Debug, Archive Release.
Staging có tối ưu tương tự Release và bật testability. Test action của scheme
Production dùng Staging; đó không phải là phép kiểm thử một binary Release.
Ba bundle ID tạo sandbox riêng cho database/cache/preferences. Đây là cấu hình
app; chưa tạo backend, database server, OAuth client hay hạ tầng triển khai.

Để đổi URL, copy file `<environment>.local.xcconfig.example` trong
`FlashcardApp/Environments` sang `<environment>.local.xcconfig`, rồi điền URL thật.
File override được ignore. Trong xcconfig, viết `http:/$()/localhost:4000/api`
để `//` không bị hiểu là comment. Không ghi token hay server secret vào app config.
CI có thể cấp `PRODUCT_BASE_URL` như một Xcode build setting.

Build phase `Validate Environment` chạy trước Sources, kiểm tra cặp configuration /
environment / bundle ID và URL. Local chỉ chấp nhận localhost/127.0.0.1; hai môi
trường còn lại yêu cầu HTTPS, từ chối URL trống, credential/query và host ví dụ.
ATS chỉ giữ ngoại lệ loopback, không mở HTTP toàn cục. Ngoại lệ không cấp quyền
truy cập backend từ xa. URL local này dành cho Simulator; localhost trên iPhone
thật là chính iPhone, cần thiết kế đường kết nối phát triển riêng nếu dùng máy thật.

**Chưa đủ để phát hành:** Firebase hiện có một plist cho bundle production và
Google/Facebook redirect scheme dùng chung. Phải tạo app/client tương ứng từng môi
trường, cấp plist/redirect đúng và kiểm tra đăng nhập trước khi phân phối. Không dùng
Firebase production làm môi trường thử nghiệm. Xem các blocker trong audit.

## Lệnh kiểm chứng

Trong Xcode ưu tiên công cụ build/test/diagnostics có sẵn. Với terminal từ repo root:

```sh
sh scripts/tests/environment-validation.sh
xcrun simctl list devices available
xcodebuild -project FlashcardApp.xcodeproj -scheme FlashcardApp-Local \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FlashcardApp.xcodeproj -scheme FlashcardApp-Local \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -disableAutomaticPackageResolution -enableCodeCoverage YES \
  -only-testing:FlashcardAppTests test
```

Thay destination bằng simulator thực tế nếu tên/runtime khác. Có thể dùng
`-resultBundlePath /tmp/FlashcardApp-tests.xcresult` với đường dẫn chưa tồn tại để
giữ evidence và đọc coverage bằng `xcrun xccov view --report <bundle>`.
Nếu môi trường máy yêu cầu RTK, thêm `rtk proxy` trước lệnh; RTK không phải dependency
của app hay CI. Lần checkout mới phải resolve đúng lockfile khi có mạng; lệnh
`-disableAutomaticPackageResolution` sẽ báo lỗi nếu cache/pin chưa sẵn sàng.

Trước phát hành: build Release có signing phù hợp; chạy unit/integration và UI
journey đăng nhập/logout, offline/error/retry, tạo/sửa/xóa deck/card, relaunch và
migration dữ liệu cũ. Ghi coverage thực đo (mục tiêu ≥80% logic mới), không suy rộng
từ test mẫu. Kiểm tra privacy manifests, dependency/security, quyền và accessibility.
Không upload TestFlight/App Store hoặc sửa backend chỉ vì bước kiểm tra đã đạt.
