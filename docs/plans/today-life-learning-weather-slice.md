# Today — Học từ cuộc sống: lát cắt đầu tiên «今日の天気» (audit, thiết kế, triển khai, kiểm chứng)

**Ngày:** 2026-10-24
**Trạng thái:** `IMPLEMENTED_LOCAL / PASS_WITH_EXTERNAL_GATE` — hành trình học đã chạy thật trên Simulator với dữ liệu thật; **chưa phát hành được** vì giấy phép nguồn dữ liệu (xem §9).
**Liên quan:** [today-life-learning-hub.md](today-life-learning-hub.md) (đề xuất sản phẩm P0, giữ nguyên), [personalized-learning.md](personalized-learning.md), [ENGINEERING_GUARDRAILS.md](../ENGINEERING_GUARDRAILS.md), wireframe: [assets/today-life-weather-wireframes.html](assets/today-life-weather-wireframes.html), ảnh chụp thật: [assets/life-weather/](assets/life-weather/).

Tài liệu này ghi **những gì đã xảy ra**, không phải kế hoạch. Mọi khẳng định “đã chạy” có bằng chứng ở §7.

## 1. Audit — backend đã có gì (chạy thật ngày 2026-10-24 trên API local)

| Khả năng | Bằng chứng runtime | Kết luận |
| --- | --- | --- |
| Daily Radar `GET /api/daily-radar/home`, `/modules`, `/cards/{slug}` | 200; 15 module, 55 thẻ, có module `weather_japanese` (3 thẻ) | **Có và chạy**, nhưng là *kho thẻ biên tập tĩnh* (`metadata.seed = true`): không có thành phố, không có dữ kiện + thời điểm + nguồn, không có bài tập có đáp án. Không dùng được làm nguồn “thời tiết hôm nay” |
| Daily Home `GET /api/daily/home` | 200, nhưng `items: []`, `widgets: []` | Chỉ có lời chào và `dueReviews` |
| NHK `GET /api/nhk-news` | 200, có bài thật (`sourceType: easy`) | Có dữ liệu; **quyền sử dụng nội dung chưa xác nhận** → không dùng ở lát cắt này |
| Magazine / Loto | 200 nhưng rỗng (`[]`, `total: 0`, `nextDraw: null`) | Hạ tầng có, chưa có dữ liệu |
| Study plan, Scenarios | 401 khi không đăng nhập (đúng thiết kế); L06a đã audit riêng | Không liên quan lát cắt này |
| **Thời tiết thật / theo thành phố** | Không có route, không có provider, không có code nào nhắc `weather`/`open-meteo` | **Thiếu** — là phần phải làm |

iOS tái sử dụng được: `Design` tokens và `TodayRowView`/`StateView`, `BJTLearnerAPI.result(of:)`/`LearnerAPIError`, `DeskManagement`/`RCard`, `CardStudyWireframe(deckId:cardIDs:)`, `TodayDeckChoice`, `AppLanguage`, xcstrings + `LocalizationTests`.

## 2. Ma trận khả năng API

| Khả năng | Trạng thái | Ghi chú |
| --- | --- | --- |
| Daily Radar (kho thẻ biên tập) | `EXISTING_AND_VERIFIED` (đọc được) · nội dung = seed | Không thay thế được dữ kiện sống; giữ làm kênh biên tập sau này |
| Daily Home | `EXISTING_AND_VERIFIED` (route) · `MISSING` (nội dung) | `items/widgets` rỗng |
| NHK News | `EXISTS_BUT_UNVERIFIED` | Có dữ liệu; quyền tái sử dụng/dịch/audio chưa xác nhận → blocker phát hành riêng |
| Magazine / Loto | `EXISTS_BUT_UNVERIFIED` | Rỗng; chỉ được dùng cho giáo dục, không dự đoán/cá cược |
| Study plan / Scenarios | `EXISTS_BUT_UNVERIFIED` cho iOS | Theo [l06a audit](personalized-learning-l06a-audit.md) |
| **Thời tiết theo thành phố → bài học** | **Đã thêm trong lát cắt này** (`GET /api/life/lessons/weather`) | `EXISTING_AND_VERIFIED` ở môi trường local/dev; **`LICENSE_BLOCKED` cho sản phẩm thương mại** nếu không có khóa Open-Meteo trả phí |
| Chứng khoán, Loto, giao thông, lịch sử/địa danh, ngày lễ | `MISSING` / `DEFERRED` | Xem §8 |

## 3. Đánh giá nguồn dữ liệu bên ngoài

Đọc từ trang chính thức bằng công cụ tải trang (không phải trí nhớ); mục “không xác nhận được” ghi rõ.

| Nguồn | Xác thực / giới hạn | Quyền thương mại & phân phối lại | Độ mới, phủ Nhật | Độ khó · giá trị học | Quyết định |
| --- | --- | --- | --- | --- | --- |
| **Open-Meteo** (`api.open-meteo.com`) | Không cần khóa ở gói miễn phí; <10.000 gọi/ngày, 5.000/giờ, 600/phút (theo IP và ứng dụng); khóa `apikey` + host `customer-api.open-meteo.com` cho gói trả phí (Standard 1 triệu/tháng; **giá không xác nhận được**) | Gói miễn phí: «You may only use the free API services for non-commercial purposes»; app có quảng cáo/đăng ký = thương mại → cần gói trả phí. Dữ liệu CC BY 4.0, bắt buộc ghi «Weather data by Open-Meteo.com» kèm liên kết. **Quy tắc cache/lưu trữ phía máy chủ không được nêu** | Mô hình theo giờ, toàn cầu; kiểm thật: Tokyo, Sapporo… trả `current` mỗi 15 phút, `daily` 1 ngày; lỗi 400 `{"error":true,"reason":…}`; **HTTP 429 không được tài liệu hóa** | Thấp · cao (mã WMO → từ vựng thời tiết, nhiệt độ, xác suất mưa) | **Được chọn** cho lát cắt. Chạy dev bằng gói miễn phí với cờ rõ ràng; thương mại bắt buộc có khóa trả phí |
| **JMA** (气象庁, `jma.go.jp/bosai/forecast`) | Không khóa | Nội dung theo «公共データ利用規約 1.0», cần ghi «出典：気象庁ホームページ» và nêu rõ khi gia công; **không xác nhận được điều khoản thương mại (chưa đọc văn bản quy tắc)**, **không xác nhận được ràng buộc 気象業務法 §17 với ứng dụng** | JSON `forecast/130000.json` **không được tài liệu hóa là API chính thức**, có thể đổi URL không báo trước; bảng mã thời tiết JMA không lấy được | Trung bình · cao, nguồn chính thống cho Nhật | `DEFERRED` — ứng viên thay Open-Meteo nếu cần nguồn thương mại không tốn phí; cần đọc 2 văn bản pháp lý trước |
| Wikidata / Wikipedia | Không khóa; User-Agent bắt buộc; dừng khi 429 | Wikidata CC0; văn bản Wikipedia CC BY-SA 4.0 | Sống; phủ rộng | Trung bình · cao cho địa danh/lịch sử | `DEFERRED` (lát cắt “nơi chốn”) |
| Ngày lễ — Cabinet Office `syukujitsu.csv` | Không khóa; CSV theo năm (đến 2027) | Quy định sử dụng chưa đọc → chưa xác nhận | Cập nhật khi luật đổi; ngày xuân phân/thu phân công bố tháng 2 | Thấp · trung bình | `DEFERRED` — **gợi ý lát cắt tiếp theo** |
| ODPT (giao thông) | Trang là JS, **không đọc được**: khóa, điều khoản, bộ dữ liệu mở/hạn chế đều chưa xác nhận | chưa xác nhận | chưa xác nhận | Cao | `DEFERRED`; điều khoản chưa rõ = blocker, không phải cho phép ngầm |
| e-Stat | Cần appId (đăng ký miễn phí, không chuyển nhượng); ghi nguồn bắt buộc theo văn bản; **giới hạn tốc độ không nêu** | Quy tắc nội dung riêng, chưa đọc | Phụ thuộc bảng | Trung bình · thấp-trung bình | `DEFERRED` |
| J-Quants | Trang không đọc được (HTTP 202 rỗng) | **chưa xác nhận** (đặc biệt: có được hiển thị lại cho người dùng cuối?) | chưa xác nhận | Trung bình | `LICENSE_BLOCKED` cho tới khi đọc điều khoản; không làm khuyến nghị đầu tư |

## 4. Thiết kế (trước khi code)

Đã đọc nội dung các skill (`ui-ux-pro-max`, `ios/accessibility-audit`, `design/liquid-glass`) và dùng như tham khảo có phê phán:

- `ui-ux-pro-max --design-system` đề xuất “App Store landing / Vibrant & Block / Baloo 2 + xanh lá CTA” — **bị loại**: là trang marketing, font trẻ em, màu CTA xanh lá lệch design system chàm/washi; chỉ giữ các luật chung (độ tương phản, vùng chạm ≥ 44 pt, empty state có hành động, không dùng màu làm tín hiệu duy nhất).
- Liquid Glass chỉ cho lớp điều hướng (thanh tab/nav hệ thống); thẻ bài học và chữ Nhật dùng bề mặt đặc.
- Accessibility audit: mọi phần tử tương tác có nhãn, thứ tự đọc, thông báo kết quả bằng `UIAccessibility.post(.announcement)`.

**Hai hướng bố cục** ([wireframe](assets/today-life-weather-wireframes.html), bảng tiêu chí trong đó): **A. thẻ ngữ cảnh nhỏ dưới tiến độ (chọn)** — hero ôn tập giữ nguyên vai trò hành động chính, một đề xuất, một CTA, một hàng phụ; **B. thẻ ảnh lớn/carousel trên đầu (loại)** — giành vùng nhìn với hero, nguy cơ thành feed, chữ Nhật trên nền gradient.

**Hành trình:** Today → Câu chuyện (dữ kiện nguồn tách khỏi câu học do mẫu tạo; dòng gợi ý gắn nhãn «Gợi ý») → Bài tập 1 *nhớ lại* (gõ đáp án, không có đáp án trên màn) → Bài tập 2 *nhận biết* (chọn cách đọc “16度”, ghi đúng nhãn kỹ năng) → Lưu từ (chọn từ và bộ thẻ) → Hoàn tất (tách “làm xong bài” khỏi “đã lưu thẻ”) → Today/ôn tập. Một màn hình điều khiển bốn giai đoạn; nút quay lại hệ thống rời bài ở mọi bước.

**Quyết định có chủ đích:**
- Hàng phụ “Khám phá chủ đề” hiện mở **chọn thành phố** (10 thành phố cố định, không dùng vị trí). Khi chưa có chủ đề thứ hai, một danh sách chủ đề chỉ có một mục là giả tạo; hàng này sẽ trở thành danh sách chủ đề khi có chủ đề thứ hai.
- Trong giao diện tiếng Nhật, phần dịch hiển thị **tiếng Anh** (backend chỉ có vi/en).
- Lỗi/không có mạng chỉ ảnh hưởng thẻ này; số thẻ cần ôn **không** bị thay.

## 5. Hợp đồng và kiến trúc

**Backend (`nihongo-bjt`, nhánh `feat/life-weather-lesson`)** — package mới `internal/lifelesson`:
- `GET /api/life/lessons/weather?city=<id>`: công khai, giới hạn tốc độ (`PublicReadRateLimiter`), 10 thành phố cố định (id không thuộc danh sách → 400 trước khi gọi nhà cung cấp). Chỉ được đăng ký khi có giấy phép cấu hình: `OPEN_METEO_API_KEY` (host `customer-api`, `licenseStatus: commercial`) hoặc `LIFE_WEATHER_ALLOW_NONCOMMERCIAL=true` (gói miễn phí, `licenseStatus: non_commercial_dev_only`); không có cả hai → route không tồn tại (404).
- Phản hồi tách **`facts`** (giá trị đã kiểm của nhà cung cấp) khỏi **`lesson`** (`generatedBy: deterministic_template`, mẫu cố định, câu `basis: fact|advice`), cộng `source` (nhà cung cấp, giấy phép, thời điểm quan sát/tải/hết hạn, `freshness: live|stale`). Schema `LifeWeatherLesson` trong `docs/openapi.json`, kiểm bằng test đối chiếu phản hồi thật với schema.
- Kiểm dữ liệu nhà cung cấp: múi giờ phải là JST, quan sát không cũ quá 3 giờ/không ở tương lai, ngày `daily` phải khớp ngày quan sát, nhiệt độ/xác suất/lượng mưa trong biên, `tmin ≤ tmax`, thân phản hồi ≤ 64 KB. Mã thời tiết lạ → từ chối thay vì đoán.
- Cache trong bộ nhớ theo thành phố: tươi 30 phút, dùng chung một lần gọi cho các yêu cầu đồng thời (huỷ client không huỷ lần gọi chung), nhà cung cấp lỗi → phục vụ bản **cùng ngày** trong ≤ 6 giờ với `freshness: stale`, nếu không → 503 + `Retry-After`. **Không bao giờ** phục vụ bài của ngày trước như hôm nay. Sau lỗi, một thành phố không bị hỏi lại trong 30 giây; panic của nhà cung cấp bị bắt thành lỗi. Lỗi không chứa khóa API.
- Phần dữ liệu cho học tập là xác định (mẫu): cách đọc số/phần trăm đúng quy tắc (じゅうろくど, はちじゅっパーセント, マイナスさんど), từ vựng có id ổn định (`weather:rain`…), bài tập recall có danh sách đáp án chấp nhận, bài tập nhận biết có lựa chọn xác định.

**iOS (`FlashcardApp`)** — giữ VIPER, không thêm framework: `Networks/BJTClient/BJTLifeLessonAPI` (+DTO), `Entities/LifeLesson`, `Interactors/LifeLessonInteractor` (ánh xạ có kiểm hợp đồng + lưu thẻ), `Services/LifeLessonPreferences` (thành phố theo người học), `Modules/LifeLesson/{Presenter,ViewController,Wireframe}`, `Modules/Today/TodayLifeCard` (loader riêng, độc lập với kế hoạch ôn), `CardManagement.add(_:toDesk:)` một giao dịch Realm. **Không đổi schema Realm** (thẻ là `RCard` hiện có).

**Lưu từ — idempotent:** id thẻ cố định `life:<deck>:<word>`; từ đã có (cùng id hoặc cùng `frontText`) không ghi lần hai; mọi thẻ mới của một lần lưu ghi trong **một giao dịch** hoặc không ghi gì; chỉ báo “đã lưu” sau khi Realm thành công; bấm lặp chỉ chuyển bước.

**Hiệu năng/bảo mật:** Today chỉ hỏi server khi chưa có bài, bài hết hạn, đổi thành phố hoặc sang ngày mới (giờ Nhật); 404 → ẩn thẻ và không hỏi lại trong 1 giờ; sau lỗi (429/503/mất mạng) không hỏi lại trong 60 giây (nút “Thử lại” của người học không bị chặn); request huỷ khi đổi thành phố/thử lại/giải phóng loader (Today là gốc của tab nên request ngắn vẫn chạy khi rời màn — chấp nhận, kết quả chỉ cập nhật bộ nhớ); bài của ngày khác (giờ Nhật) không bao giờ hiện như hôm nay; không gửi token/cookie; không có khóa nhà cung cấp trong app; không dùng vị trí; nhiệt độ ngoài biên bị từ chối thay vì làm app crash.

## 6. Ranh giới còn lại / việc cố ý không làm

- Không đọc vị trí, không theo dõi nền, không lưu vị trí chính xác.
- Chưa có analytics, streak, điểm; kết quả bài tập không ghi `RReviewAttempt` (không bịa lượt ôn); lịch ôn bắt đầu khi người học học các thẻ đã lưu.
- Không hạ tầng “nạp mọi nguồn”; Daily Radar không được sửa (xem §1).

## 7. Bằng chứng kiểm chứng

Mọi lệnh dưới đây đã chạy thật trong phiên này (2026-10-24, macOS, một Simulator iPhone 17, iOS 26, giao diện sáng, cỡ chữ mặc định, ngôn ngữ en khi kiểm tay và vi trong UI test).

**Backend (`nihongo-bjt`, harness `LIFE-1`)**
- RED: tính năng mới nên khai `red_exception: new_component`; thay RED bằng *sensitivity* (đột biến mã production → test thất bại đúng assertion): bỏ kiểm tra “ngày của dự báo = hôm nay” ở đường tải → `TestAForecastForAnotherDayIsNeverServedAsToday` thất bại với «want ErrUnavailable wrapping ErrInvalidData».
- Các test thêm sau review độc lập được viết trước phần sửa. RED quan sát được cho: `percentReading(0)`, đọc số ngoài biên (panic), `x-verification` thiếu trong OpenAPI. Với kiểm tra ngày lúc tải, backoff và panic của nhà cung cấp, panic của test đọc số làm dừng cả gói nên **không quan sát riêng RED**; độ nhạy của kiểm tra ngày được chứng minh bằng sensitivity ở trên.
- Test: `internal/lifelesson` (đọc số, mẫu bài, client Open-Meteo với server giả: thành công, 400/429/500, timeout, thân quá lớn, dữ liệu sai/đổi ngày/ngoài biên, khóa không lộ trong lỗi; cache: tươi, dùng chung một lần gọi, huỷ caller, lỗi → stale cùng ngày, không bao giờ ngày trước, backoff, panic), `handler_life_lesson_test.go` (200/400/503/429/404, schema OpenAPI so với phản hồi thật, enum thành phố so với danh sách), `config` (cờ giấy phép), `app` (cổng giấy phép). Coverage đo được: `lifelesson` 97,3%, `config` 90,5%, handler 90%; hàm nối dây `newLifeLessons` được test riêng (4 trường hợp).
- `pnpm quality verify` (gofmt, vet, toàn bộ Go test với PostgreSQL thật, race, build ARM64): **PASS 1545/1545, 0 bỏ qua** ở lần cuối (một lần chạy trước đó thất bại ở test không liên quan, xem §9.6, chạy lại đạt). Task `LIFE-1` đóng `VERIFIED`.
- Chạy thật: `GET /api/life/lessons/weather?city=tokyo` → 200 trong 1,6 s lần đầu (Open-Meteo thật), 0,5 ms lần sau (cache); `city=paris|""|không có` → 400; tải mẫu đã lưu ở `FlashcardAppTests/LifeLessonFixtures.swift` là phản hồi thật.

**iOS (`FlashcardApp`)**
- RED: bốn hành vi (so khớp đáp án, lưu thẻ, làm mới bài trên Today, chấm bài) bị vô hiệu hóa tạm → **80/94** test mới thất bại đúng assertion (ví dụ «caught error: databaseWriteFailed("not implemented")», «XCTUnwrap failed: expected non-nil value of type LifeFeedback»); khôi phục → xanh.
- Toàn bộ `FlashcardAppTests`: **706/706** đạt, 0 bỏ qua (trước các sửa sau review); sau sửa, nhóm liên quan 107/107 (gồm `LocalizationTests`). Các test thêm sau review iOS được viết trước phần sửa nhưng **không chạy riêng ở trạng thái đỏ**.
- Coverage đo bằng `xcresult` trên phần logic mới: `LifeLessonInteractor` 96,1%, `LifeLessonPresenter` 94,1%, `TodayLifeCard` 97,7%, `TodayPresenter` 98,8%, `BJTLifeLessonAPI` 92,7%, `LifeLessonPreferences` 100%, `LifeLesson` 77,3%. **View/Wireframe 0% bằng unit test** (được kiểm bằng UI test và quan sát thật). Không khẳng định coverage cả ứng dụng (43% cho target app).
- UI test thật `testLifeLessonCanBeCompletedSavedAndFoundAgainWithoutDuplicates` (backend local + Open-Meteo thật): mở bài từ Today, gõ sai → thấy đáp án đúng, làm bài chọn, lưu → “đã lưu”, tìm thấy bộ thẻ trong thư viện, làm lại bằng đáp án đọc từ phản hồi → “Chính xác”, lưu lại → “Đã có trong …” (không trùng). PASS 1/1. Hồi quy Today với backend cũ (route vắng → thẻ ẩn): 2/2 PASS.
- Quan sát thật trên Simulator (ảnh trong [assets/life-weather/](assets/life-weather/)): Today có thẻ; câu chuyện (Tokyo, mưa 80%; Sapporo, sương mù); bài nhớ lại; phản hồi sai/đúng; bài chọn cách đọc với màu đúng/sai; lưu 5 từ vào “Learn from Life” rồi **“Study these cards” mở đúng thẻ 雨 trong luồng học hiện có**; chọn bộ “Learn from Life” ở Today → hero «5 cards to practise»; đổi thành phố → thẻ đổi sang Sapporo; lưu lại cùng từ → «Saved 1 new word … 3 were already there».
- Chưa kiểm: VoiceOver thật, Dynamic Type lớn, Reduce Motion, chế độ tối, iPad, thiết bị thật, tiếng Nhật/Việt trên Simulator (chỉ vi trong UI test), nhập tiếng Nhật bằng bàn phím thật. Đường *lưu lỗi* chỉ kiểm bằng unit test (không dựng được lỗi Realm ở Simulator).

**Đánh giá độc lập:** backend — `review run` (phiên Claude mới, harness) trải qua 4 vòng: vòng 1 yêu cầu sửa 2 lỗi chặn (bài của ngày trước phục vụ như `live` sau nửa đêm; thiếu test cổng giấy phép) và 6 mục nhỏ; vòng 2 chỉ ra thiếu test cho kiểm tra ngày ở đường cache tươi; vòng 3 chỉ ra `expiresAt` có thể vượt nửa đêm giờ Nhật; vòng 4: **APPROVE, 0 finding**. Mọi mục đã sửa kèm test; còn lại (không sửa có chủ đích): `CLAUDE.md` của backend vẫn ghi «627 operations» (sửa tệp chỉ dẫn agent kéo theo phân loại `CI_QUALITY_SYSTEM`; nay là 628), và mã thời tiết `daily` của Open-Meteo là “điều kiện nặng nhất trong ngày” (đã ghi vào OpenAPI). iOS — `flashcard-reviewer` không có lỗi chặn; 8 mục nên-sửa/nit đã xử lý (khôi phục focus VoiceOver, backoff sau lỗi, kiểm ngày khi nhận, chặn Int trap, thông báo lỗi lưu, số ít/số nhiều, font nút chọn, chỉnh văn bản kế hoạch); mục 9 (thẻ lưu câu ví dụ “今日の…”) chấp nhận: câu vẫn đúng ngữ pháp là ví dụ, không phải dữ kiện.

## 8. Mở rộng: chủ đề tiếp theo tái sử dụng gì

Hợp đồng `LifeWeatherLesson` đã gồm phần chung mà mọi chủ đề cần: `id/topic/level`, `source` (nhà cung cấp, giấy phép, quan sát/tải/hết hạn, `freshness`), `facts` (dữ kiện đã kiểm, **tách khỏi** `lesson`), `lesson.sentences[basis fact|advice]`, `vocabulary[id ổn định]`, `exercises[kind, skillType]`, `generatedBy`. iOS đã chung hóa: cách lưu từ idempotent, chuỗi story → practice → save → done, thẻ Today, cách xử lý stale/lỗi/ẩn khi server không cung cấp.

Chủ đề kế (ví dụ ngày lễ) cần thêm: (1) một `Provider` + bộ kiểm dữ liệu; (2) một builder mẫu cho `facts` mới; (3) một route (`/api/life/lessons/<topic>`) hoặc tham số `topic`, schema mới bên cạnh `LifeWeatherLesson`; (4) trong iOS: đổi `LifeLesson.facts` từ struct thời tiết thành dữ liệu theo chủ đề (hiện cố ý chỉ có các trường thời tiết), thêm hàng “Khám phá chủ đề” thật (danh sách chủ đề chỉ gồm chủ đề có bài hợp lệ). **Chưa làm** (và không nên làm trước khi có chủ đề thứ hai): nền tảng nạp dữ liệu chung, DB cho bài học, danh sách chủ đề, cá nhân hóa, thông báo.

Tài chính/xổ số chỉ được dùng làm ngữ cảnh học từ và cách đọc số liệu đã công bố; không khuyến nghị mua/bán, không dự đoán số, không liên kết cá cược. Vị trí chỉ được hỏi khi người dùng chủ động bấm “tìm hiểu nơi ở gần mình” (P4).

## 9. Rủi ro và blocker phát hành (nêu rõ)

1. **Giấy phép Open-Meteo (blocker).** Gói miễn phí chỉ cho mục đích phi thương mại; ứng dụng có quảng cáo/đăng ký hoặc sản phẩm thương mại cần gói trả phí (khóa `OPEN_METEO_API_KEY`). Giá không xác nhận được; quy tắc cache/lưu trữ phía máy chủ không được nêu. Cho đến lúc đó route chỉ chạy khi `LIFE_WEATHER_ALLOW_NONCOMMERCIAL=true` và mọi bài hiển thị nhãn «Development source». Hành động cần làm: chủ sản phẩm quyết định mua gói trả phí **hoặc** đọc và chấp nhận điều khoản JMA (cần đọc văn bản «公共データ利用規約 1.0» và 気象業務法 §17) rồi viết provider JMA.
2. Nội dung tiếng Nhật do mẫu cố định tạo, đã tự kiểm cách đọc số/phần trăm, nhưng **chưa có người biên tập Nhật ngữ xác nhận** (chủ sở hữu nội dung chưa được chỉ định). Cấp độ «N4» là ước tính biên tập.
3. Cache trong bộ nhớ một tiến trình: nhiều bản API sẽ mỗi bản gọi nhà cung cấp riêng (10 thành phố × số bản; vẫn rất thấp so với giới hạn).
4. Chưa kiểm accessibility trên thiết bị/VoiceOver thật; chưa kiểm ngôn ngữ ja/vi bằng mắt.
5. Backend nằm trên nhánh riêng vì thư mục chính có thay đổi chưa commit của agent khác; khi merge cần xử lý xung đột tiềm năng ở `docs/openapi.json`, `docs/api-route-inventory.json`, `apps/api-go/cmd/route-contract/main.go`.
6. Test flaky không liên quan: `TestAudit153SocialAdminContractsPersistAcrossTemplateAndEventFlows` thất bại một lần trong một lần chạy toàn bộ (đạt 6/6 khi chạy riêng và đạt ở các lần chạy toàn bộ khác); không sửa/không nới lỏng.
7. Ổ đĩa máy dev đầy 100% do `test-products` của công cụ test (77 GB, đã xóa phần sinh lại được): lỗi hạ tầng, không phải lỗi mã.

## 10. Lát cắt đề xuất tiếp theo

**Ngày lễ và mùa (祝日・季節)**: nguồn tĩnh theo năm (CSV của Cabinet Office, có sẵn đến 2027), không có nhà cung cấp trực tuyến, không giới hạn tốc độ, giá trị học cao (ngày lễ, cách nói “明日は祝日です”), tái sử dụng toàn bộ luồng. Điều kiện trước khi code: đọc điều khoản sử dụng CSV và mã hóa của tệp (chưa xác nhận). Sau đó: chuyển nguồn thời tiết sang nguồn có quyền thương mại rõ ràng.

## 11. Commit cục bộ

- iOS (`FlashcardApp`, nhánh `main`): `6c9fd2f` — `feat(today): learn Japanese from today's weather`; tài liệu/wireframe/ảnh: commit ngay sau đó (`docs(plan): …`).
- Backend (`nihongo-bjt`, nhánh `feat/life-weather-lesson`, worktree `/Users/thanhnguyen/Documents/Projects/nihongo-bjt-life`): `429fc18a` — `feat(api): weather life lesson for the Today "Learn from Life" offer`. **Chưa merge vào `main`** (thư mục chính có thay đổi chưa commit của agent khác); không push, không deploy.

Không commit: `.DS_Store`, `docs/plans/personalized-learning.md` (đang được agent khác sửa), `docs/plans/personalized-learning-l06a-audit.md` (của L06a).
