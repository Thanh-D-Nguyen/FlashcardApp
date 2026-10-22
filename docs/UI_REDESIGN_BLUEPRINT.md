# UI redesign — Home / Cấp độ (P2: "Biên tập Nhật × Apple native")

Phạm vi: nền tảng thiết kế, shell iOS 26, **màn Cấp độ** và **Nội dung cấp độ** (`HomeViewController`), cùng style dùng chung cho
các tab còn lại. Từ điển, học thẻ, quản lý bộ thẻ, đăng nhập, chi tiết Cài đặt **chưa** thiết kế lại (xem §8).

Nhãn nguồn: **[Apple]** hướng dẫn nền tảng · **[Nguyên lý]** nguyên lý UX/nhận thức đã được nghiên cứu · **[Giả thuyết]**
quyết định chưa kiểm chứng với người dùng · **[Gu]** ưu tiên thẩm mỹ. Dự án chưa đo usability; không có số liệu tiến độ, streak
hay SRS nào bị bịa.

## 1. Vì sao P1 chưa đủ

P1 (`docs/ui-redesign/p1/`) đúng kỹ thuật nhưng là *danh sách cấu trúc lại*: sáu hàng gần như giống nhau, không có điểm bắt đầu,
muốn vào Kanji/Ngữ pháp của một cấp độ phải qua hai bước, số liệu chỉ là chữ. Không có thứ bậc: J5 và J1+ (trống) ngang hàng.

## 2. Nghiên cứu (đã đọc trong phiên này)

| Phát hiện | Loại | Áp dụng |
| --- | --- | --- |
| Liquid Glass là lớp *chức năng* (điều hướng, điều khiển) nổi trên nội dung; không đặt glass trong lớp nội dung, không glass trên glass; màu thương hiệu thuộc lớp nội dung (WWDC25 219, 356) | Apple | Tab bar/nav bar hoàn toàn hệ thống; khối hero là bề mặt nội dung đặc, không blur tự dựng |
| Bar trong suốt mặc định; `UIBarAppearance`/`backgroundColor` tuỳ biến phá hiệu ứng; scroll-edge effect tự giữ độ đọc (WWDC25 284) | Apple | Không đặt nền cho bar; bảng chạy sát mép dưới bar |
| `UINavigationItem.subtitle` (iOS 26) hiển thị dưới large title (WWDC25 284/243) | Apple | Dùng cho dòng hướng dẫn, tắt ở cỡ chữ accessibility vì hệ thống cắt chữ |
| `preferredTransition = .zoom` cho push (iOS 18+) tạo liên tục không gian | Apple | Số kanji của cấp độ "phóng" vào màn nội dung |
| Dynamic Type, vùng chạm ≥ 44 pt, tương phản ≥ 4,5:1 | Apple/WCAG | Mọi vai trò chữ theo text style; ≥ 44 pt cho nút; bố cục đổi trục ở cỡ accessibility |
| Giảm tải nhận thức, Hick–Hyman, Fitts, nhận biết hơn nhớ lại, hiển thị dần | Nguyên lý | Một hành động chính rõ ràng; các cấp độ khác là lựa chọn phụ; mỗi nhóm nội dung vào thẳng 1 chạm |
| Ứng dụng học (Duolingo, WaniKani, Bunpro, Anki): điểm bắt đầu duy nhất, tiến độ hiển thị rõ | Nguyên lý, đã biết trước | Lấy *điểm bắt đầu duy nhất*; **không** lấy streak/tiến độ/huy hiệu vì không có dữ liệu thật |
| Một màu nhấn duy nhất, chữ Nhật cần nền yên tĩnh | Giả thuyết/Gu | Giấy washi + chàm 藍, số kanji bằng Mincho |

Công cụ: `ui-ux-pro-max` (`--design-system` trả về Claymorphism/trẻ em — **lệch hướng, bị loại**; các tra cứu `--domain web|ux`
xác nhận Dynamic Type, safe area, reduced motion, phản hồi khi chạm), `liquid-glass` (tài liệu SwiftUI; chỉ lấy nguyên tắc vì app
là UIKit), `apple-skills:design`. Tra cứu web: WWDC25 284, 219, 356, 243 (developer.apple.com).

## 3. Ba hướng và lựa chọn

| Tiêu chí | A. Biên tập Nhật | B. Apple native học tập | C. Studio học tập |
| --- | --- | --- | --- |
| Bố cục | Số kanji làm trục chữ, đường kẻ mảnh, một khối chàm duy nhất | `List` hệ thống, large title, không khối màu | Lưới thẻ màu, thanh tiến độ, huy hiệu |
| Đọc chữ Nhật | rất tốt (Mincho cho ký hiệu, gothic cho nội dung) | tốt | trung bình |
| Đúng nền tảng | cao nếu giữ bar gốc | cao nhất | thấp |
| Nhận diện riêng | **cao** | thấp | trung bình |
| Truy cập | tốt | tốt | rủi ro (nhiều màu) |
| Phụ thuộc dữ liệu chưa có | không | không | **có** (tiến độ, streak) |
| Phức tạp | trung bình | thấp | cao |

**Chọn A + B**, mượn một ý của C: *điểm bắt đầu rõ ràng*. Giữ giả thuyết ban đầu; bằng chứng không đảo ngược nó. C bị loại phần
lớn vì cần dữ liệu tiến độ không tồn tại. Khác P1 ở bố cục và thứ bậc, không phải ở màu/cỡ chữ.

## 4. Thiết kế màn Cấp độ

```
Cấp độ                       ← large title + subtitle (hệ thống)
┌───────────────────────────┐
│ Bắt đầu từ đây            │  khối chàm (duy nhất)
│ 五   J5                   │  số kanji Mincho 96 pt
│      Sơ cấp               │
│ Giao tiếp cơ bản: …       │
│ 574 từ vựng · 79 kanji …  │
│ [ Bắt đầu học từ vựng → ] │  nút chính (capsule)
└───────────────────────────┘
Các cấp độ tiếp theo
四  Sơ trung cấp          ›     số kanji Mincho 44 pt, treo bên trái
    Hội thoại đơn giản, …
 523      │ 167    │ 433        ba cột = ba lối vào trực tiếp
 từ vựng  │ kanji  │ ngữ pháp
─────────────────────────────
三  Trung cấp …
```

- **Điểm bắt đầu** = cấp độ đầu tiên *có nội dung* theo backend (`featuredIndex`); không phải gợi ý cá nhân hoá. Nút mở từ vựng của
  cấp độ đó. Cả khối cũng chạm được (mở từ vựng).
- **Lối vào trực tiếp**: mỗi cột số liệu là nút (`home_kind_<code>_<vocabulary|kanji|grammar>`) mở thẳng mục đó; cột 0 bị vô
  hiệu. Trước đây phải mở cấp độ rồi đổi segmented.
- **Số kanji cấp độ**: J5–J1 → 五四三二一, J1+ → 一 kèm "+" nhỏ (`HomePresenter.numerals`); mã lạ → quay về mã J. Có nghĩa
  (N5 = 五), không phải trang trí.
- Cấp độ không có nội dung (J1+): "Chưa có nội dung", không dải số liệu; vẫn mở được như trước.
- **Nội dung cấp độ**: kanji hiển thị như ký hiệu lớn bên trái (Mincho 44 pt), nghĩa tiếng Việt rồi âm đọc; từ vựng/ngữ pháp giữ
  từ → cách đọc → nghĩa. Ở cỡ accessibility mọi thứ xếp dọc.
- **Chuyển cảnh**: zoom từ số kanji sang màn nội dung (`preferredTransition = .zoom`); hệ thống tự giảm khi Reduce Motion. Khối
  hero lún nhẹ khi nhấn, bỏ hẳn khi Reduce Motion bật. Không có animation nào khác.
- **Accessibility**: ô cấp độ là *container*: phần tiêu đề là một nút VoiceOver ("J4, Sơ trung cấp, mô tả — Mở cấp độ"), mỗi cột
  số liệu là nút riêng ("167 kanji"); số kanji ẩn khỏi VoiceOver (mã J đã được đọc). Ở cỡ chữ accessibility: hero xếp dọc, dải số
  liệu thành các hàng, nút chính đổi capsule → rounded rect (capsule thành hình tròn khi chữ xuống dòng — lỗi bắt được trên ảnh
  thật), bỏ subtitle (hệ thống sẽ cắt).

## 5. Design system (`Commons/Utils/DesignSystem.swift`)

- Màu: thêm `hero` (chàm đậm `#23406B` / dark `#24406E`), `onHero` (giấy `#F6F3ED`), `onHeroSecondary` (78%), `heroDeep`
  (chữ trên nút giấy). Nền washi, nhấn chàm, trạng thái giữ nguyên P1. `whiteSmokeColor`/`royalBlueColor` (storyboard Thẻ,
  trước đó nhúng giá trị xanh-trắng/tím cố định) nay có colorset theo light/dark = nền washi/chàm, nên màn Thẻ đồng bộ palette và
  theo Dark Mode mà không sửa storyboard.
- Chữ: `numeral`/`numeralDisplay` (Hiragino Mincho `HiraMinProN-W6`, co giãn theo `UIFontMetrics`, có trần kích thước), `eyebrow`
  (caption1 đậm). Font serif hệ thống (New York) không có glyph CJK nên không dùng cho kanji; có fallback nếu thiếu font.
- Hình: `Radius.panel = 28` cho đúng một khối nổi mỗi màn. Không thêm bóng, gradient, blur tự dựng.
- Điều khiển: `Design.Button.hero(title:)`; bar giữ hệ thống (Liquid Glass).
- Không test cho giá trị màu/khoảng cách.

## 6. Ràng buộc kiến trúc (giữ nguyên)

View vẽ và chuyển sự kiện; `HomePresenter` giữ trạng thái (`featuredIndex`, `selectRow(at:kind:)`, kind khởi tạo); `HomeInteractor`
ánh xạ DTO (`isGlyph` cho kanji); `HomeWireframe` điều hướng và gắn chuyển cảnh zoom, lấy view nguồn từ `HomeViewController.
transitionSourceView(forLevelCode:)`. Không đụng API, DTO, Realm, Keychain, `AuthSession`. Không file Swift mới (không đổi
`project.pbxproj`); thêm hai colorset vào `Assets.xcassets`. Identifier cũ (`home_levels`, `home_row_<code>`, `level_content`,
`level_content_kind`, `tab_*`) giữ nguyên; thêm `home_start`, `home_kind_*`.

Sửa ngoài Home (style chung): Thẻ (colorset ở trên), Cài đặt (`Design.Color.background`), Từ điển (chỉ một mục thanh phải tại một
thời điểm — trước đây spinner rỗng tạo một viên glass trống cạnh nút làm mới).

## 7. Bằng chứng kiểm chứng

Xem phần "Kết quả" cuối tài liệu này (cập nhật sau khi chạy). Ảnh thật từ app đang chạy trong `docs/ui-redesign/` (thiết bị, iOS,
giao diện, cỡ chữ ghi trong tên/bảng bên dưới); ảnh P0/P1 để so sánh ở `docs/ui-p0/` và `docs/ui-redesign/p1/`.

## 8. Việc còn lại

1. **Thẻ**: tiêu đề nhỏ, ô chọn bộ thẻ trống không nhãn, viền ô `AppColors`; học thẻ/tạo bộ thẻ chưa thiết kế.
2. ~~**Cài đặt**~~ — đã làm lại, xem §10.
3. **Từ điển**: hàng kết quả vẫn dùng kiểu mặc định; `StateView` thay `message`.
4. Kanji: chưa có trang chi tiết (chạm vẫn mở hộp thoại nghĩa); furigana chưa có trong dữ liệu API.
5. Fixture backend local (`audit141 lexeme …`) hiển thị ở từ vựng J5; là dữ liệu, không phải lỗi UI.
6. `UIScreen.main` deprecated ở `ListFlowLayout`/`GridFlowLayout`/`FadingEdgeCollectionView` (ngoài phạm vi).
7. Chưa kiểm chứng: VoiceOver thật, Increase Contrast, Reduce Motion/Transparency bật, iPad, thiết bị thật, màn hình nhỏ hơn 17e.

## 9. Kết quả (chạy thật, 2026-10-22)

Môi trường: Xcode 27.2, scheme `FlashcardApp-Local`, backend local `/api/levels` 200. Simulator riêng cho phiên này (simulator mặc định
của dự án bị thao tác từ bên ngoài giữa chừng nên ảnh đầu bị loại): **iPhone 17 — iOS 27.0** và **iPhone 17e — iOS 26.5**.

| Kiểm tra | Kết quả |
| --- | --- |
| Build (deployment target 26.0) | SUCCEEDED, không cảnh báo mới từ file đã sửa |
| Unit `FlashcardAppTests` (chạy riêng) | 88/88 (6 test Home mới: numeral, featured, chọn kind, kind khởi tạo, ánh xạ section ×2) |
| UI `FlashcardAppUITests` (backend local thật; chạy riêng) | 8/8 (2 test mới: nút bắt đầu → từ vựng; cột số liệu → Ngữ pháp J4) |
| Chạy gộp unit+UI sau các sửa theo review | 98/98 |
| Chạy gộp lần đầu | 90/96: 6 test `MailLoginPresenterTests` lỗi (loading ≠ idle). Không đụng module đó; chạy riêng 15/15, chạy gộp lại 98/98 — **chập chờn, chưa rõ nguyên nhân**, cần theo dõi |
| Coverage dòng (unit+UI) các file đổi | Presenter 99,3% · Interactor 99,1% · ViewController 90,1% · Cells 91,3% · Wireframe 80,7% · DesignSystem 79,8%. Toàn app 52,9% — không suy ra coverage toàn app |
| Ảnh thật | iPhone 17/iOS 27.0: Cấp độ Light, Dark, AX-XXXL (đầu + cuộn), Nội dung (từ vựng, kanji vào thẳng), 3 tab còn lại. iPhone 17e/iOS 26.5: Light, Dark, AX-XXXL, kanji. Kiểm lại sau sửa review bằng đổi cỡ chữ lúc app đang chạy (AX-M, XXL) |

Lỗi chỉ lộ ra nhờ ảnh thật và đã sửa: nút chính thành hình tròn ở cỡ chữ AX; "+" của J1+ làm lệch cột tên; chữ phụ đề bị cắt ở AX; viên glass rỗng
cạnh nút làm mới của Từ điển; nền Thẻ xanh-trắng/tím lệch bảng màu.

Review độc lập (agent `flashcard-reviewer`, chỉ đọc mã): không crash/rò rỉ/lỗi luồng; 6 điểm nhỏ đã sửa (font nút hero theo Dynamic Type khi chạy,
đường kẻ cột ở bố cục dọc, nhãn VoiceOver cho spinner, nguồn zoom bị ẩn, `updateLayout` thừa việc, thiếu test ánh xạ section). Điểm "UI test có thể
không tìm thấy cell container" không xảy ra (8/8).

Đánh giá phản biện (không chấm điểm): (1) *Thiết kế*: thứ bậc rõ, nhưng khối chàm chiếm gần nửa màn đầu — chấp nhận vì đó chính là hành động chính;
J5 xuất hiện chỉ ở hero nên mất lối vào Kanji/Ngữ pháp trực tiếp (vẫn một chạm sau khi mở). (2) *Học tập*: không có tiến độ nên "bắt đầu từ đây" chỉ
là cấp độ đầu tiên có nội dung, không phải gợi ý; cần dữ liệu thật mới làm "tiếp tục học". (3) *Accessibility*: cấu trúc VoiceOver đúng theo mã, chưa nghe
bằng VoiceOver thật. (4) *UIKit*: không file mới, không đổi kiến trúc; `ActionableView` là điểm duy nhất cần theo dõi khi thêm hành động.

## 10. Màn Cài đặt (milestone tiếp theo)

Cùng hệ thống với Home: nền washi, chàm 藍, đường kẻ mảnh, tiêu đề lớn native; không thẻ nổi, không khối màu thứ hai.

**Vấn đề đã sửa** (ảnh trước: `docs/ui-redesign/settings/before_p1_settings_light.png`):

| Vấn đề | Cách xử lý |
| --- | --- |
| Toàn bộ chuỗi tiếng Anh (`NSLocalizedString` với khoá tiếng Anh, không có bản dịch); "Ngôn ngữ: English (Japan)" sai sự thật | Chuỗi tiếng Việt viết thẳng như các màn khác; "Ngôn ngữ: Tiếng Việt", chạm hiện giải thích (app chỉ có một ngôn ngữ). Chưa dùng String Catalog vì chưa có ngôn ngữ thứ hai |
| Tab Cài đặt không nằm trong `UINavigationController` (`navigationController` thực ra là nav gốc của app) nên không có tiêu đề | Bọc trong `BaseNavigationController` như 3 tab kia; đăng xuất/đăng nhập vẫn thay root của nav gốc (`navigationController?.navigationController`) |
| Công tắc Thông báo bị khoá khi quyền ở `notDetermined`, mà đây là nơi duy nhất xin quyền → không bao giờ bật được | Công tắc dùng được; bật sẽ hiện hộp xin quyền, kết quả được cache lại (nếu không công tắc nhảy về Tắt); bị từ chối → giải thích + hàng "Mở Cài đặt hệ thống" |
| Lựa chọn Giao diện **không được áp dụng khi mở app** (chỉ áp dụng lúc đang chạy) | `SceneDelegate` áp dụng giá trị đã lưu ngay từ khung hình đầu; giá trị lạ → theo hệ thống |
| Giao diện là action sheet giữa màn hình | Menu pop-up trên chính hàng (một chạm, có dấu chọn); ở cỡ chữ accessibility giá trị chuyển xuống dưới tiêu đề |
| Hint VoiceOver "xem chi tiết tài khoản" không dẫn đi đâu | Bỏ hint; hàng tài khoản đã đăng nhập chỉ đọc "tên, email" |
| Nút chính ở Dark Mode: chữ trắng trên xanh nhạt (~2:1) | Token `onAccent` (trắng ở Light, gần đen ở Dark) trong `Design.Button.primary`; dùng chung cả nút Thử lại |
| Icon `.label`/`systemBlue`, đỏ hệ thống | Icon đơn sắc chàm, nguy hiểm dùng `Design.Color.error` |

**Bố cục**: header tài khoản (avatar vòng chàm với chữ cái đầu bằng Mincho hoặc ảnh; đăng nhập rồi thì chỉ tên + email, chưa đăng nhập
thì thêm nút "Đăng nhập" — hành động chính duy nhất của màn) → Tuỳ chọn → Chung → Giới thiệu → (đã đăng nhập) Đăng xuất. Hàng dựng bằng
`UIListContentConfiguration` (Dynamic Type, lề, VoiceOver như danh sách hệ thống); công tắc và nút menu là accessory view.

**Kiến trúc**: `SettingItem.choice` mới (presenter: `selectChoice`, wireframe bỏ `showAppearancePicker`); xin quyền thông báo đi qua
`SettingInteractor.requestNotificationPermission` nên kiểm thử được. Xoá `ToggleCell`, `CommonCell`(→ `SettingsRowCell`), `AccountCell.xib`,
`CommonCell.xib` (đã sửa `project.pbxproj`). `Prototypes/SettingsPrototypes.swift` (SwiftUI preview 3 hướng từ trước) giữ nguyên, không
dùng.

**Kết quả** (iPhone 17e, iOS 26.5; backend local bật): build SUCCEEDED; chạy gộp unit+UI **110/110** (100 unit, trong đó 12 test Cài đặt mới/sửa; 10 UI,
trong đó 2 mới: menu Giao diện, nút Đăng nhập mở màn đăng nhập). Coverage dòng (unit+UI): SettingPresenter 89,7% · SettingViewController 91,6% ·
SettingsRowCell 92,4% · AccountCell 78,0% · SettingInteractor 57,4% · **SettingWireframe 20,4%** (alert/Safari không có test) · SceneDelegate 55,9%.
Ảnh thật trong `docs/ui-redesign/settings/`: Light, menu Giao diện, Dark (áp dụng từ lựa chọn đã lưu khi thiết bị đang Light), AX-XXXL (đầu + cuộn).
Review độc lập (agent `flashcard-reviewer`, chỉ đọc mã): không lỗi crash/điều hướng/pbxproj; 6 điểm nhỏ đã sửa (VoiceOver sau khi tái sử dụng
cell, đăng ký theo dõi cỡ chữ trong `init`, viền avatar theo Light/Dark, `provisional/ephemeral`, test UI trả lại giao diện, gọi
`viewWillDisappear`). Ảnh được chụp trước các sửa nhỏ đó (không đổi bố cục nhìn thấy); chưa chụp lại.

**Chưa làm / cần quyết định sản phẩm**:
1. **Công tắc Thông báo và "Âm thanh và rung" chỉ lưu `UserDefaults`; không có mã nào đọc chúng** (không có nhắc học, không có âm/rung). UI vẫn như cũ để
   giữ hành vi; cần quyết định xoá hai hàng hay làm tính năng thật. Chữ trong hộp thoại "nhận nhắc nhở học tập" cũng đang hứa điều chưa có.
2. Hàng tài khoản đã đăng nhập chưa kiểm tra bằng ảnh (cần tài khoản thật); đăng nhập thành công với tài khoản thật vẫn chưa kiểm chứng.
3. Chính sách quyền riêng tư mở `<baseURL>/vi/privacy` trong Safari; production chưa có URL nên chỉ chạy được với backend local.
4. Refresh hồ sơ có thể chạy hai lần mỗi lần hiện màn (có sẵn từ trước: `viewWillAppear` + callback quyền thông báo).
5. VoiceOver thật, Increase Contrast, iPad, thiết bị thật chưa kiểm chứng.
