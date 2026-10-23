# Phát triển FlashcardApp

## Phạm vi hiện tại

App dùng UIKit/storyboard, Swift 5 và iOS 26+. Giữ View → Presenter → Interactor →
API/local manager; điều hướng trong wireframe. Các màn danh sách mới dùng UIKit
trực tiếp, các màn thẻ/cài đặt vẫn dùng XIB/storyboard hiện có.

Bốn tab hoạt động:

- Cấp độ: GET `/api/levels`; chọn J5–J1+ để đọc từ vựng, kanji, ngữ pháp,
  phân trang 30 mục và xem nghĩa.
- Từ điển: GET `/api/search`, scope `lexeme`, `kanji`, `grammar`, `example`.
  Đổi từ khóa hủy request cũ; có trạng thái tải, trống, lỗi và tải lại.
- Thẻ: thư viện bộ thẻ Realm cục bộ (tìm, sắp xếp, sửa, xoá), trình soạn bộ thẻ (cách đọc, ghi chú, ảnh từ Ảnh hoặc `https`, nhập hàng loạt, bản nháp) và màn học (lật, xáo trộn, trắc nghiệm, đọc to). Ảnh của thẻ nằm cục bộ vì backend Go chưa lưu ảnh cho thẻ; chi tiết, ma trận tương đương web và bằng chứng ở `docs/ui-redesign/cards/README.md`.
- Cài đặt: giao diện, âm thanh, thông báo và tài khoản của website.

Giao diện có ba ngôn ngữ: Tiếng Việt, English, 日本語 (`Localizable.xcstrings`; chọn ngôn ngữ ở
Cài đặt iOS ▸ FlashcardApp ▸ Ngôn ngữ). Tên và mô tả cấp độ theo ngôn ngữ; nghĩa từ vựng/kanji/ngữ pháp
từ API hiện chỉ có tiếng Việt. UI test ghim `-AppleLanguages (vi)`.

App mở thẳng vào nội dung, không yêu cầu đăng nhập để học bộ thẻ của mình hoặc đọc API
công khai. App tạm thời không đóng gói từ điển: từ điển, ví dụ, kanji, ngữ pháp và gợi ý lấy từ API
(cần server chạy; mất mạng thì chỉ còn bộ thẻ đã lưu và gõ thẻ bằng tay). Realm vẫn là nơi lưu dữ liệu
cục bộ và cache; cơ chế tải từ điển về Realm sẽ làm sau. Đăng nhập từ mục tài khoản trong Cài đặt bằng tài khoản website đã có.

## Khởi động

Launch screen hệ thống chỉ là một màn trống màu `LaunchBackground` (giấy washi / gần đen), trùng
`Design.Color.background`; không logo, chữ hay animation. `StartUp` không phải màn splash: nó chỉ
mở Realm cục bộ (chỉ bộ thẻ của người học) qua `StartUpInteractor` rồi chuyển thẳng vào `Main`. Chỉ khi việc
chuẩn bị kéo dài quá 0,4 giây (nâng cấp schema) mới hiện trạng thái tải; lỗi mở dữ liệu hiện
màn lỗi có nút Thử lại. Không có độ trễ giả. Chi tiết và ảnh chụp: `docs/ui-redesign/splash/`.

## API và tài khoản

Scheme `FlashcardApp-Local` (hoặc `FlashcardApp`) dùng
`http://localhost:18081/api`. `/vi` là trang web, không phải API base path.
Backend đang chạy đã chuyển sang phiên đăng nhập Go, nên tài liệu Keycloak cũ
không còn mô tả đúng luồng đăng nhập này:

1. POST `/api/auth/login` với JSON `email`, `password`, nhận `ok`, `token`.
2. GET `/api/auth/me` với Bearer để lấy hồ sơ trực tiếp với `id`, `displayName`, `email`.
3. Lưu token và UUID người dùng vào Keychain sau khi cả hai bước thành công.
4. POST `/api/auth/logout` thu hồi phiên; xóa phiên local kể cả khi mạng lỗi. Server trả 401 nghĩa là
   phiên đã hết/bị thu hồi (coi như xong); lỗi mạng hay 5xx vẫn đăng xuất local nhưng app báo rõ máy chủ chưa
   xác nhận kết thúc phiên. Token và UUID nằm chung một mục Keychain (ghi nguyên tử); build không ký
   (`CODE_SIGNING_ALLOWED=NO`) không có Keychain nên đăng nhập báo lỗi lưu phiên, test Keychain bị skip.

Login/logout gửi `Origin` (scheme/host/port của API) theo CSRF allowlist của server.
Không lưu cookie website/token vào UserDefaults hoặc log. Hủy request khi màn
đăng nhập đóng; kết quả đến muộn không được khôi phục phiên đã đăng xuất. Lỗi 401
khi tải hồ sơ xóa phiên local; lỗi mạng không xóa token đang có. Server quyết định
hạn phiên; người dùng đăng nhập lại khi phiên hết hạn.

DTO đọc đúng trường backend thực tế: search dùng `id/kind/title/description`, từ
vựng cấp độ dùng `headword/shortMeaningVi`, cấp độ dùng `nameVi/descriptionVi/vocabCount`.
Không chuyển UUID server thành `hashValue` hoặc ghi dữ liệu API vào Realm bằng
mapping suy đoán. Bộ thẻ hiện vẫn local; chưa có đồng bộ tiến độ/bộ thẻ lên server.

Các endpoint tìm kiếm và nội dung được đối chiếu với response local và source của
backend đang chạy. OpenAPI cũ chưa đủ để khẳng định mọi endpoint đã tích hợp.

## Dependency còn giữ

| Package trực tiếp | Lý do |
| --- | --- |
| RxSwift, bao gồm RxCocoa/RxRelay | Binding và vòng đời request hiện dùng xuyên app |
| Alamofire | Request API, validation và cancellation |
| realm-swift | Bộ thẻ của người học và schema đang dùng |
| Kingfisher | Tải/cache ảnh của thẻ đã lưu và avatar |

`Package.resolved` gồm các package trên và `realm-core` là dependency bắc cầu.
Đã bỏ Firebase, Facebook SDK, GoogleSignIn, swift-log, Typist và các product test
RxBlocking/RxTest không dùng. OSLog, UIRefreshControl, UIKeyboardLayoutGuide thay
cho các wrapper tương ứng. Màn Thẻ viết lại không còn dùng MMTextView, SwipeCellKit hay CollectionViewPagingLayout nên đã gỡ cả ba.

Đã bỏ các thư viện vendored Disk, VImage, PullToRefresh, RESegmentedControl;
giao diện snack/carousel mẫu, Quiz rỗng, Vocabulary/DictionaryWelcome mẫu; client
Swagger phục vụ tìm ảnh và các BJT client/DTO không có caller hoặc sai contract.
Tìm ảnh Flickr/Pixabay và khóa nhúng trong source đã được gỡ. URL ảnh đã lưu được giữ.
CSDL từ điển đóng gói `Storage/Data/flash_card.realm` (~120 MB) đã bị gỡ khỏi app theo yêu cầu (tạm thời): bản cài cũ
được nâng lên schema 2, bỏ các bảng từ điển và giữ nguyên bộ thẻ; có thể khôi phục file từ Git (commit trước `feat(data)`). Xóa khóa khỏi source không thu hồi khóa
ở nhà cung cấp hoặc trong lịch sử Git; chủ tài khoản cần thu hồi khóa cũ.

## Môi trường

| Scheme | Configuration | Bundle ID |
| --- | --- | --- |
| FlashcardApp-Local / FlashcardApp | Debug | com.ds.FlashcardApp.dev |
| FlashcardApp-Production | Release | com.ds.FlashcardApp |

Hai bundle ID tạo sandbox riêng. Không xóa database để sửa lỗi build/migration.
Bootstrap chép bundle sang file tạm rồi đổi tên khi hoàn tất. Nếu lần chạy trước bị
dừng, chỉ file ngắn hơn và khớp từng byte với phần đầu bundle mới được chép lại;
store có bất kỳ thay đổi nào được giữ nguyên. Điều hướng chờ Realm mở thành công.
Production không có URL mặc định; phase `Validate Environment` chặn build nếu
chưa cấp API HTTPS hợp lệ. Test action của scheme Production dùng Debug để chạy
suite local, không xác nhận binary Release đã sẵn sàng phát hành.

Đổi URL local bằng `FlashcardApp/Environments/local.local.xcconfig` (đã ignore):

```xcconfig
PRODUCT_BASE_URL = http:/$()/localhost:18081/api
```

Production dùng file `production.local.xcconfig` với URL HTTPS được cấp thực tế.
Cú pháp `$()` tránh để `//` bị xcconfig hiểu là comment. ATS chỉ cho HTTP loopback;
không bật `NSAllowsArbitraryLoads`. `localhost` chỉ dùng với Simulator trên máy
chạy backend; trên iPhone thật, nó trỏ về chính điện thoại.

## Kiểm chứng

Dùng Xcode hoặc XcodeBuildMCP đã cài. **Mặc định phát triển nhanh:** chọn **một**
iPhone Simulator đang boot (nếu không có, chọn một iPhone khả dụng) và dùng nguyên
simulator ID đó cho cả task. Build + chạy đúng luồng vừa sửa + xem một screenshot
ở cỡ chữ mặc định. Chỉ chạy XCTest/XCUITest liên quan khi đổi logic/điều hướng.
Không chạy ma trận thiết bị, cỡ chữ lớn, ngôn ngữ, Light/Dark hay VoiceOver mỗi
lần sửa. Vẫn giữ hỗ trợ accessibility/localization trong code. Khi sửa chính
các phần này, gặp regression hoặc chuẩn bị release thì kiểm chứng thêm theo rủi ro.

Thay simulator ID bằng thiết bị đã chọn:

```sh
rtk proxy sh scripts/tests/environment-validation.sh
rtk proxy xcodebuildmcp simulator test --project-path "$PWD/FlashcardApp.xcodeproj" \
  --scheme FlashcardApp-Local --simulator-id <SIMULATOR_ID> \
  --extra-args CODE_SIGNING_ALLOWED=NO -enableCodeCoverage YES \
  -only-testing:FlashcardAppTests -parallel-testing-enabled NO
```

`FlashcardAppTests` kiểm tra auth bằng URLProtocol/mocks, contract DTO, input,
HTTP failure, cancellation, đăng xuất khi request đang chạy, tìm kiếm và phân trang.
`FlashcardAppUITests` kiểm tra cấp độ/nội dung và tra cứu với backend local đang bật,
cùng đường vào thẻ offline/cài đặt. Không chạy suite UI khi server local tắt.

Đăng nhập thành công với tài khoản thật, iPhone/iPad thật, migration store cũ và
phát hành Release cần kiểm tra riêng. Không upload build/push/đổi credential nếu
chưa được yêu cầu.
