# Magazine và tab Khám phá (Discover)

**Trạng thái:** `VERIFIED` cục bộ (build, 1058 unit test, chạy thật trên Simulator với dữ liệu thật). Chưa commit.
**Ngày:** 2026-10-29. **Liên quan:** [ENGINEERING_GUARDRAILS.md](../../ENGINEERING_GUARDRAILS.md), [UI_REDESIGN_BLUEPRINT.md](../../UI_REDESIGN_BLUEPRINT.md), [today-life-learning-hub.md](../../plans/today-life-learning-hub.md).

Website có nhiều tính năng hơn app. Mục tiêu: đưa dần từng tính năng sang mobile mà không phải làm lại khung điều hướng. Tính năng đầu tiên là **Magazine** (bài đọc ngắn mỗi ngày: từ vựng, thời tiết, tử vi, tiếng Nhật công sở, kèm quiz).

## 1. Quyết định

| Quyết định | Lý do |
| --- | --- |
| Thêm tab thứ 5 **Khám phá** (Today · Dictionary · Cards · **Khám phá** · Settings) | Một điểm vào cố định cho mọi tính năng web sẽ lần lượt được thêm. Bốn tab cũ giữ nguyên đường đi và `accessibilityIdentifier`; Settings vẫn ở cuối. Nếu muốn quay lại 4 tab: bỏ một dòng trong `MainPresenter.createTabbar` và chuyển hub thành hàng trong Today. |
| Hub là **danh sách thẻ theo registry** (`DiscoverFeature`) | Thêm tính năng = thêm 1 case + 1 dòng trong `DiscoverWireframe.show(_:)` + chuỗi. Tính năng chưa làm **không hiện** (không có "sắp ra mắt" giả). |
| Loto (`magazine_loto6/7`) **không** nằm trong danh sách Magazine | Có màn riêng `Modules/Loto`, mở từ thẻ nổi bật đầu tab Khám phá (quyết định của chủ sản phẩm 2026-10-31, thay cho quyết định ẩn Loto trước đó). Magazine vẫn loại `magazine_loto*` ở `MagazineInteractor.summary(from:)`. |
| Chỉ có tiếng Việt làm bản dịch | Server không có text tiếng Anh cho Magazine. Người dùng giao diện Anh/Nhật thấy tiếng Nhật + bản dịch tiếng Việt. Muốn có tiếng Anh phải do backend bổ sung. |
| Không ghi tiến độ lên server (`POST /api/magazine/{slug}/read`) | Chưa có đồng bộ tiến độ trên iOS (AGENTS.md); không idempotent. Quiz chỉ tính trong phiên. |
| Ngày của bài lấy từ `publishDate` của danh sách | `publishedAt` của bài chỉ là lúc đăng (Loto đăng ngày 29 cho kỳ 30). "Hôm nay" tính theo lịch **Nhật Bản** vì bài được phát hành lúc 06:00 JST. |

## 2. UX (skill `ui-ux-pro-max` + design system của app)

Kết quả tìm kiếm: phong cách **E-Ink / Paper** (đọc, tĩnh, một màu nhấn) khớp với design system sẵn có (giấy ấm, chàm 藍, Mincho), nên giữ token hiện tại thay vì kiểu "landing vibrant" mà `--design-system` gợi ý. Áp dụng các quy tắc: không emoji làm icon (SF Symbols), mục tiêu chạm ≥ 44 pt, lỗi có hướng xử lý (Thử lại), trạng thái rỗng có lời giải thích, tải lười theo trang, trạng thái không chỉ dựa vào màu.

- **Danh sách**: tiêu đề lớn, chip lọc ghim (Tất cả / Từ vựng / Thời tiết / Tử vi / Tiếng Nhật công sở), bài mới nhất là thẻ lớn (tiêu đề Mincho, tên tiếng Việt, tóm tắt, vài từ), phần còn lại là danh sách yên tĩnh. Kéo để làm mới, tải trang tiếp khi gần cuối, lỗi trang tiếp có hàng "Thử lại" mà không mất danh sách.
- **Bài đọc**: tiêu đề kiểu in, tóm tắt có vạch dọc như standfirst; thân bài theo loại (cụm từ + hội thoại + ghi chú + tình huống; thẻ thời tiết; tử vi; đoạn văn). Mỗi dòng tiếng Nhật có bản dịch ngay dưới. Mỗi kind có một màu nhấn riêng (chỉ cho icon/nhãn), luôn đi kèm biểu tượng và chữ.
- **Từ vựng**: chọn/bỏ từng từ, chọn bộ thẻ (mặc định tạo bộ "Tạp chí"), lưu **idempotent** (id thẻ cố định + bỏ qua từ đã có), chỉ báo "đã lưu" sau khi ghi xong, rồi nút chuyển thành "Học các thẻ này".
- **Quiz**: từng câu, phản hồi ngay (✓ / ✗ có biểu tượng + chữ), giải thích, kết quả cuối, làm lại. Server luôn đặt đáp án đúng đầu tiên nên thứ tự được xáo bằng hash FNV-1a ổn định (cùng bài, cùng thứ tự mọi lần).
- **Trung thực**: bài thời tiết/tử vi có ghi chú "không phải dự báo/lời khuyên chính thức".
- **Truy cập**: Dynamic Type (font theo text style, nhãn không cắt), VoiceOver (nhóm thành một phần tử, trait/giá trị đã chọn, `accessibilityLanguage = ja` cho tiếng Nhật, thông báo kết quả quiz/lưu), Reduce Motion (không animation tự thêm).

Ảnh chụp thật từ Simulator (iPhone 17 Pro, chữ mặc định, sáng, dữ liệu API local): [discover](discover.jpg), [list](list.jpg), [article-phrase](article-phrase.jpg), [article-vocabulary](article-vocabulary.jpg), [article-quiz](article-quiz.jpg).

## 3. Hợp đồng API (đã kiểm trên API chạy thật)

Công khai, không cần token (client dùng session `ephemeral`, không cookie, không Authorization).

- `GET /api/magazine?kind=&page=&limit=` → `{data:[{id,slug,widgetKind,titleJp,titleVi,summaryVi?,jlptLevel?,publishDate,publishedAt,vocabWords[]}],limit,page,total}`. `kind` ∈ `vocab|weather|horoscope|bjt_phrase|loto`; **không** nhận nhiều kind, kind lạ trả rỗng (không lỗi). `page` vượt cuối bị **kẹp về trang cuối** (app coi là hết). "Tất cả" = bỏ `kind`, lọc Loto phía client.
- `GET /api/magazine/{slug}` → thêm `summaryJp`, `contentJson` (tùy kind), `vocabItems[]`, `quizzes[]`; 404 `{error}`.
- `contentJson` do bộ sinh nội dung viết và **lệch với trình đọc của web** (`text` vs `textJp`, `fortune` vs `fortuneJp`), nên DTO nhận cả hai và bỏ từng trường/phần tử hỏng thay vì hỏng cả bài (`LossyArray`).

## 4. Mã

`Networks/BJTClient/BJTMagazineAPI.swift` + `Models/BJTMagazineDTO.swift` → `Interactors/MagazineInteractor.swift` (ánh xạ, lưu từ) → `Modules/Magazine/*` (presenter, VC, wireframe) và `Modules/Discover/*`. Entity: `Entities/Magazine.swift`. Presenter nhận `scheduler` để test đồng bộ.

### Thêm tính năng tiếp theo vào Khám phá
1. Thêm case vào `DiscoverFeature` (`title`, `subtitle`, `symbol`, `tags`, `accessibilityIdentifier`, `isAvailable`).
2. Thêm nhánh trong `DiscoverWireframe.show(_:)`.
3. Làm module theo VIPER hiện có; thêm chuỗi vi/en/ja vào `Localizable.xcstrings`; thêm file vào target (`project.pbxproj`).
4. Xác minh payload thật qua `flashcard-api-contract` trước khi viết DTO.

Ứng viên theo tài liệu web/parity: tin NHK, tình huống (Scenarios), ngữ pháp, kanji. Mỗi cái cần kiểm quyền dùng nội dung và payload riêng; **không** nằm trong lát cắt này.

## 5. Kiểm chứng

| Việc | Kết quả |
| --- | --- |
| Build `FlashcardApp-Local`, iPhone 17 Pro | PASS |
| `FlashcardAppTests` toàn bộ | PASS 1058/1058 (gồm 77 test Magazine mới + 4 Discover, `LocalizationTests` 10/10) |
| Chạy thật trên Simulator (danh sách, lọc, mở bài cụm từ, từ vựng, quiz) | PASS, ảnh ở trên. Dữ liệu từ API local (`localhost:18081`) |
| Dữ liệu API production (`kiokoto.com`) | Đã đối chiếu payload bằng `curl` (cả 4 kind), **chưa** chạy app với scheme Production |
| Thao tác chạm thật (lưu từ, trả lời quiz) trên Simulator | **NOT VERIFIED**: công cụ môi trường không có tap/swipe. Logic đã được test ở presenter + Realm thật trong bộ nhớ. Nên thử tay một lần |
| Dark mode, chữ lớn, iPad, VoiceOver, ja/vi trên màn hình | **NOT VERIFIED** (fast loop một Simulator theo guardrails) |
| UI test cho luồng Khám phá → Magazine | Chưa viết (launch arg DEBUG `-InitialTab 3 -DiscoverOpenMagazine -MagazineFilter <kind> -MagazineOpenFirst -ArticleScrollTo <vocabulary|quiz>` sẵn để dùng) |

## 6. Giới hạn đã biết
- Nội dung do bộ sinh viết; có bài lệch mùa (ví dụ "mùa mưa" đăng tháng 10) và bài `bjt_phrase` lặp cùng cụm từ nhiều ngày. Đó là chất lượng dữ liệu ở backend, không sửa ở app.
- Không có tìm kiếm trong Magazine, không đánh dấu "đã đọc", không chia sẻ (URL web cần locale và chưa xác minh).


## 7. Loto (màn riêng, 2026-10-31)

- Dữ liệu: `GET /api/magazine?kind=loto` (danh sách) + `GET /api/magazine/{slug}` (bộ số trong `contentJson.sets`: `mainNumbers`, `bonusNumbers`, `explanation.{shape,numbers[{count,gap,tags}],signals,historyDraws}`, `algorithmWeights`, `drawTime`, `drawNumber`, `riskDisclaimer{en,ja,vi}`, `source.officialVerificationUrl`). Kỳ quay tiếp theo của mỗi game = bài đầu tiên có `publishDate` chưa qua theo lịch Nhật (hôm nay vẫn tính); hết bài thì lấy bài mới nhất.
- Phương pháp của server là `historical_heuristic_equal_odds`: **mọi tổ hợp có xác suất như nhau**. Vì vậy màn hình luôn đặt thẻ cảnh báo và xác suất thật (1/6.096.454 cho Loto 6, 1/10.295.472 cho Loto 7) ngay dưới đếm ngược, trước các bộ số; không có link mua vé, chỉ có link đối chiếu kết quả chính thức (https, chỉ `mizuhobank.co.jp`). Một bộ số không đủ số (hoặc trùng/ngoài khoảng) không được hiển thị.
- Màn hình: đếm ngược 4 ô tới giờ quay (JST), bóng số có biểu tượng + chữ cho từng nhãn (không chỉ dựa vào màu), "Vì sao chọn các số này", sao chép bộ số, tín hiệu từ lịch sử, trọng số phương pháp, chú giải, kéo để làm mới. Reduce Motion tắt hiệu ứng bóng nảy.
- Rủi ro cần chủ sản phẩm biết: App Store Guideline 5.3 (gambling) và quyền dùng dữ liệu kết quả xổ số. Nội dung đã được đóng khung là học xác suất, nhưng việc duyệt do Apple quyết định.
- DEBUG: `-DiscoverOpenLoto -LotoFixture -LotoScroll <pt>` (fixture là 2 payload production đã ghi lại).

## 8. Kanji / Ngữ pháp / Từ điển trong Khám phá
Đã gỡ khỏi hub vì trùng tab Từ điển (chỉ chuyển tab). Nếu muốn khám phá riêng, cần màn duyệt theo cấp độ JLPT với endpoint danh sách đã được kiểm chứng.

## Loto: Phòng ngẫu nhiên (randomness lab)

`Modules/Loto/LotoLabView.swift` + `Entities/LotoRandomizer.swift`. Mirrors the website admin's "Randomness" slider
(`randomEntropy`): at 100% every number has the same weight (uniform over all combinations, system CSPRNG); lower values blend
the draw's hot/cold/overdue signals in (unmarked numbers keep ≥ 15% weight). Runs entirely on the device, no API call, no stored
state. The screen always states that no setting changes the chance (1 in `LotoGame.combinations`). DEBUG launch args:
`-LotoLabRandomness <0…1>`, `-LotoLabSpin <seconds>` (with `-LotoFixture -InitialTab 3 -DiscoverOpenLoto -LotoScroll <pt>`).

### Hiệu ứng cánh bướm (chaos mode)

`Entities/LotoChaos.swift`, `Modules/Loto/LotoChaosViews.swift`, `Interactors/LotoEnvironmentInteractor.swift`,
`Services/LotoMotionSampler.swift`. Each spin hashes (SHA-256) the factors that really exist then — exact time, the draw,
weather of the 10 `LifeCity` cities from the public `/life/feed` (card `weather`: `weatherCode`, `temperatureC`), accelerometer
digest, slider/touch trail, drum ball positions (not under Reduce Motion), slider value — into the start of a Lorenz system
(RK4, σ10 ρ28 β8/3). A copy started 1e-6 away is drawn beside it; the end states key a SHA-256 counter stream that feeds the
same `LotoRandomizer` (so the slider still means what it did; at 100% the numbers are uniform). Missing factors (simulator has
no motion, feed offline) are omitted, never faked. It is a model and an explanation: it cannot predict the real machine and the
screen says so. The study cards (`LotoChaosTerm`) are authored words/readings/examples, not dictionary data; readings are ours and
should be reviewed by a Japanese speaker before release. The weather endpoint `/life/lessons/weather` is 404 in production; only
the feed card is used. `-LotoFixture` uses no weather.
