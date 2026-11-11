# Kiokoto iOS — Product Vision & Execution Plan (revised 2026-11-11)

**Trạng thái:** `PLANNED` — chưa triển khai story nào theo roadmap này tại thời điểm lập kế hoạch.

**Điểm vào triển khai:** K-01, sau đó theo thứ tự dependency và quality gates bên dưới. Khi người dùng chạy [Orca execution playbook](kiokoto-ios-orca-execution.md), yêu cầu ngày 2026-11-11 **cho phép thực hiện liên tục mọi story khả thi K-01…K-18 trong phạm vi local**, không phải hỏi lại sau từng story; story thiếu contract/bản quyền/thiết bị/ủy quyền external action phải ghi `BLOCKED` hoặc `NOT VERIFIED` và tiếp tục phần độc lập. **Không** tự push, phát hành, cập nhật production hoặc sửa backend ngoài phạm vi.

**Nguồn:** bản *Product Vision & Execution Plan* của Fable ngày 2026-11-11; đối chiếu cấu trúc iOS tại `main` `8d2273c`. Các lần gọi production/runtime, kiểm tra backend `nihongo-bjt` `2ed75948`, số lượng 420 bài và 1.277 tests PASS là **bằng chứng do Fable báo cáo**, chưa được kiểm chứng lại trong lần biên tập này.

## 1. Mục tiêu sản phẩm

**Định vị:** Tiếng Nhật dùng trong cuộc sống và công việc tại Nhật, giải thích phù hợp với người Việt, học ngắn mỗi ngày và ghi nhớ bằng ôn tập.

**Khoảng trống cần giải quyết:** iOS đã hỗ trợ tra cứu, quét chữ/giọng nói/chữ viết tay, tạo bộ thẻ, học thẻ local và ôn thẻ tài khoản. Người học vẫn thiếu đường dẫn rõ ràng từ **học một bài có cấu trúc → luyện tập → lưu từ → ôn lại → bài tiếp theo**.

**Đích đầu tiên:** hoàn thiện một vertical slice từ J5 có thể dùng trên iPhone: `Today → Chọn trình độ → Danh sách bài → Đọc bài → Trả lời hoạt động → Lưu từ vào bộ thẻ local → Quay lại Today`. Guest học được phần công khai và lưu tiến độ trên máy; đăng nhập mới được phép ghi tiến độ về tài khoản khi contract hỗ trợ.

**Không thuộc MVP:** viết lại bằng SwiftUI, thay bộ điều hướng/tab, đồng bộ hai scheduler, AI tutor, tạo nội dung ngữ pháp bằng AI ở client, gamification phức tạp, nhúng AdMob vào lúc học/ôn.

## 2. Baseline và mức độ bằng chứng

| Hạng mục | Trạng thái tại lúc lập plan | Bằng chứng / giới hạn |
| --- | --- | --- |
| Điều hướng | **SOURCE**: 5 tab `today, dictionary, cards, discover, settings` | `FlashcardApp/Modules/Main/MainPresenter.swift`; `-InitialTab` nhận **integer** 0…4, không nhận `learn` |
| Đi từ Today tới cấp độ | **SOURCE**: `TodayWireframe.showLevels()` push `HomeWireframe()` | `FlashcardApp/Modules/Today/TodayWireframe.swift`; không cần tab Học mới |
| API cấp độ hiện tại | **SOURCE**: `BJTLevelAPI` có `/levels`, từ vựng, kanji, ngữ pháp; chưa có lesson | `FlashcardApp/Networks/BJTClient/BJTLevelAPI.swift` |
| Realm | **SOURCE**: `schemaVersion = 6` | `FlashcardApp/Services/RealmService.swift`; `AGENTS.md` vẫn ghi schema 3, cần sửa trong đợt ổn định |
| Ôn tập | **SOURCE**: local study có quiz/FSRS; thẻ tài khoản do `CardReviewPresenter` flip + gửi rating server | `CardReviewPresenter.swift`, `BJTFlashcardLibraryAPI.swift`, `docs/plans/personalized-learning.md` |
| Lưu từ vào bộ thẻ | **SOURCE**: `DictionaryDeckWriter` ghi vào Realm local, chống thêm trùng | `FlashcardApp/Interactors/DictionaryDeckWriter.swift`; cần kiểm tra cách map vocab trong lesson |
| Scenario | **SOURCE**: đã có Scenario list/play, tránh viết lại | `FlashcardApp/Modules/Scenario/` |
| 420 lesson, J5 84 lesson, cấu trúc `lessonContent` | **FABLE-RUNTIME / UNVERIFIED HERE** | K-01 phải kiểm contract + lấy fixture đã loại thông tin nhạy cảm; đừng coi `contents[]` rỗng là nội dung bài |
| `GET /flashcards/reviews/{id}/distractors` | **SOURCE-VERIFIED** (handler + test backend; `{"items":[string]}`, 401/404); chưa gọi server thật | K-07 dùng; cần tài khoản để kiểm runtime |
| Dòng tin Daily Radar, gamification, analytics | **FABLE-SOURCE/RUNTIME / UNVERIFIED HERE** | Xác minh kích thước, auth và hành vi trong story tương ứng |
| 1.277 tests PASS | **DOC/FABLE**, không phải kết quả chạy hôm nay | Mỗi story phải có log test/build của chính nó |

**Bất định sản phẩm:** Nhu cầu học tiếng Nhật công sở có hướng dẫn bằng tiếng Việt là giả thuyết hợp lý, **chưa phải product-market fit**; số điểm ưu tiên của Fable và benchmark retention là đánh giá/nguồn thứ cấp, không dùng như dữ liệu đo thực của Kiokoto.

## 3. Quyết định kiến trúc và UI/UX đã chốt cho bản kế hoạch

1. **Giữ nguyên 5 tab và vị trí Settings.** Lối vào chính của chương trình Học nằm ở Today. Từ `HomeWireframe`/màn cấp độ hiện có, thêm danh sách **Bài học** trong cấp độ; giữ nguyên đường xem **Từ vựng / Kanji / Ngữ pháp**. Chỉ đánh giá lại dedicated Learn tab khi có dữ liệu sử dụng và lý do điều hướng cụ thể.
2. **Giữ UIKit + VIPER-style + RxSwift/Alamofire + Realm** và component hiện có. View chỉ render/nhận sự kiện; Presenter điều phối; Interactor xử lý use case; API/Realm nằm ở lớp lưu trữ; Wireframe điều hướng. Không thêm framework, container DI, SwiftUI rewrite hoặc mạng/persistence thứ hai.
3. **Hai lịch ôn là hai nguồn độc lập.** `Today` hiện thể hiện kế hoạch từ thẻ local; `CardReview` lấy thẻ tài khoản từ backend. Không cộng tổng thẻ đến hạn, không tuyên bố cùng một lịch FSRS và không đồng bộ ngầm khi chưa có contract/reconciliation (K-18).
4. **Hoàn thành một luồng học trước khi thêm nhiều màn.** Trước K-06 không làm dashboard mới hoặc dashboard streak. Hero review của Today vẫn hoạt động như trước; thêm một mục bài tiếp theo độc lập, có trạng thái thật và không thay thế CTA ôn tập.
5. **Lesson lấy nguyên văn nội dung server đã được xác minh.** Không tự suy luận furigana, cách đọc, nghĩa, đáp án, rationale hoặc lỗi người Việt thường mắc. Các trường thiếu hiển thị trung thực/ẩn section; nếu thiếu dữ liệu bắt buộc để làm activity, báo không khả dụng.
6. **Local guest là một khả năng thực tế**, không phải lời hứa đồng bộ. Tiến độ guest được lưu local khi K-04 hoàn thành. Nếu signed-in, chỉ gửi cập nhật server đúng contract và trạng thái tài khoản; **không tự import/sync lịch sử guest vào server** trong MVP.
7. **Trắc nghiệm ≠ đánh giá nhớ.** Với server review, chọn đúng trong 4 đáp án chỉ là tín hiệu *recognition*; không tự chấm `Good` và không dùng kết quả đó để giả định tự nhớ. Sau khi hiện đáp án, người học **chủ động đánh giá** bằng luồng rating có sẵn; chỉ kết quả POST được server xác nhận mới tính hoàn thành. Với thẻ local, tái sử dụng quiz hiện có, không tạo song song một choice engine mới.
8. **Không tự retry mutation** khi có thể backend đã xử lý (review, complete, progress, tạo deck...). Trường hợp mất kết nối sau khi gửi phải hiện trạng thái chưa xác định; kiểm trạng thái server trước khi cho gửi lại nếu có API. Thực tế `PUT …/progress` có idempotent hay không phải xác minh trước K-04.
9. **Privacy theo thiết kế.** Không bật analytics trước khi có consent tự nguyện, privacy policy/App Privacy tương ứng và kiểm tra payload. Các chuỗi UI phải vào `Localizable.xcstrings` đủ vi/en/ja; Japanese content là chính, giải thích ngôn ngữ phù hợp theo API thực tế.

### Journey MVP

`Hôm nay → Học bài` (hoặc `Học theo cấp độ` hiện có) → `J5` → `Danh sách bài theo tuần` → `Chi tiết bài` (bối cảnh, từ, ngữ pháp, ví dụ) → `Luyện tập` (hoạt động từ backend + giải thích) → `Hoàn thành trên máy` → `Lưu từ được chọn vào bộ thẻ` → `Hôm nay` thấy bài tiếp theo.

**Khi lỗi:** Không có mạng → dùng bài đã cache hợp lệ nếu có, nếu không hiện retry; chưa đăng nhập → vẫn học/lưu local; lỗi lưu Realm → không báo thành công; lỗi ghi tiến độ tài khoản → tiến độ local vẫn tồn tại, thông báo phần tài khoản chưa được xác nhận; không phát minh tiến độ hoặc lượt ôn.

## 4. Kiểm soát release: 1.0 và 1.1 là hai track độc lập

**Track 1.0 — Stability/Store readiness (chủ release riêng):** kiểm thực tế account deletion và thu hồi quyền Apple nếu áp dụng; notification permission/hành vi; moderation/privacy/terms; nâng cấp Realm từ fixture thật mà không mất deck/card; accessibility thiết yếu; App Privacy labels, metadata và kiểm thử trên thiết bị cho camera/mic/Pencil. Sửa ghi chú schema 3 → 6 trong `AGENTS.md` **khi** kiểm tra bản code lúc sửa. Không triển khai feature backlog này như một phần vá release. Chưa đánh dấu `RELEASE READY` khi các gate chưa chạy.

**Track 1.1 — Learning vertical slice:** K-01 → K-02 → K-03 → K-04 → K-05 → K-06. Có thể phát triển local độc lập trong lúc track 1.0 xử lý blocker nhưng không gộp vào binary 1.0. K-07/K-08 chỉ bắt đầu khi MVP hoạt động và có test/đánh giá việc trắc nghiệm ảnh hưởng rating.

**Track 1.2+ — Mở rộng sau baseline:** Radar, streak, analytics, typed mode, NHK, shadowing, chia sẻ bộ thẻ, privacy export, kỳ thi BJT, scheduler reconciliation. Không dùng các story này để trì hoãn kiểm chứng MVP.

## 5. Backlog và dependency đã sửa

| ID | Story / phạm vi tối thiểu | Phụ thuộc | Đợt | Trạng thái |
| --- | --- | --- | --- | --- |
| **K-01** | Client + DTO/fixture/test cho lesson public và contract progress; không thay UI | — | 1.1/P0 | **VERIFIED** (GET + DTO; PUT theo source, chưa gọi thật) — [contract](../ui-redesign/learn/README.md), [status](kiokoto-ios-orca-status.md) |
| K-02 | Từ màn cấp độ **đang có**, danh sách lesson J5→J1, nhóm theo tuần, loading/retry | K-01 | 1.1/P1 | **VERIFIED** (local commit; chưa có review độc lập riêng cho K-02) — xem [status](kiokoto-ios-orca-status.md) |
| K-03 | Lesson reader (scenario, vocab, grammar, examples, pitfalls), cache bài đã mở để đọc offline | K-02 | 1.1/P2 | **VERIFIED** (local commit) — [status](kiokoto-ios-orca-status.md) |
| K-04 | 5 hoạt động hoặc số lượng thật từ API, đáp án/rationale, lưu hoàn thành local, ghi progress server khi hợp lệ | K-03 + contract xác minh | 1.1/P3 | **VERIFIED** (local commit; PUT thật NOT VERIFIED) — [status](kiokoto-ios-orca-status.md) |
| K-05 | Chọn/lưu từ trong lesson vào bộ thẻ local bằng writer hiện có, chống trùng | K-03; nên sau K-04 để hoàn thiện journey | 1.1/P4 | **VERIFIED** (local commit) — [status](kiokoto-ios-orca-status.md) |
| K-06 | Today: bài kế tiếp/tiếp tục học; giữ nguyên hero review, tách nguồn local/server | K-04/K-05 | 1.1/P5 | **VERIFIED** (local commit) — [status](kiokoto-ios-orca-status.md) |
| K-07 | Choice mode cho **server account review**; xác minh distractors; người học tự xác nhận rating | K-01..06 không phải phụ thuộc code, nhưng đợi cổng MVP | 1.1 sau MVP | VERIFIED local (server thật NOT VERIFIED) |
| K-08 | Danh sách thẻ thường sai theo dữ liệu lịch sử thật; không suy đoán lapse trên server | K-07 hoặc dữ liệu local đã có | Sau K-07 | VERIFIED local (nguồn: lịch ôn local, toàn thời gian) |
| K-09 | Gõ đáp án kana có xử lý biến thể và accessibility | K-07 | 1.2 | DEFERRED |
| K-10 | Study-plan/streak signed-in; fallback local phải có định nghĩa rõ | K-04 + contract | 1.2 | DEFERRED |
| K-11 | Analytics opt-in + privacy contract + MetricKit, baseline trước mục tiêu | Consent/legal + event schema | 1.2 | DEFERRED |
| K-12 | 1 thẻ Daily Radar trong Today, dùng endpoint cards và cache có giới hạn | K-06 | 1.2 | DEFERRED |
| K-13 | NHK Reading Lab | Xác minh quyền dùng nội dung bằng văn bản | 1.2+ | BLOCKED |
| K-14 | Shadowing thử nghiệm một bài, test trên máy thật | Quyết định thử nghiệm riêng | 1.2+ | DEFERRED |
| K-15 | Luyện viết Kanji | Đánh giá nhu cầu/hardware Pencil | 1.2+ | DEFERRED |
| K-16 | Chia sẻ/clone deck qua link | Deep-link/token contract và bảo mật | 1.2+ | DEFERRED |
| K-17 | Privacy export request | API delivery/privacy UX xác minh | 1.2+ | DEFERRED |
| K-18 | Reconcile local FSRS với lịch server | Backend identity + idempotency + chính sách conflict | Later/backend | BLOCKED |

### Cổng chất lượng sản phẩm trước K-02 (content gate)

- K-01 chứng minh ít nhất **1 lesson thực tế J5** giải mã đúng, bài có đủ dữ liệu để hiển thị (không chỉ `contents[]` rỗng), và activities có đáp án/rationale đúng schema; thu thập fixture **public, redacted**.
- Đánh giá thủ công một mẫu bài ở J5/J4/J3/J2/J1: độ chính xác ngữ pháp, mức tự nhiên trong công sở, cách diễn đạt tiếng Việt, đáp án và rationale. Mở rộng lấy mẫu (mục tiêu ban đầu khoảng 20 bài/mức) trước khi quảng bá toàn bộ 420 bài; không xem count là chứng nhận chất lượng.
- Nếu nội dung thực tế không đủ chất lượng, dừng mở rộng bài học, ghi rõ lỗi/slug và sửa nguồn nội dung trong một task backend riêng; không chữa bằng cách tự bịa dữ liệu iOS.

## 6. Story briefs đủ để giao agent

### K-01 — Lesson API contract (bắt đầu tại đây)

**Outcome:** Swift client đọc danh sách/chủ đề/bài học bằng API thật; mô hình giữ nguyên nghĩa dữ liệu backend; chưa có UI/Realm migration.

**Đường dẫn dự kiến:** `FlashcardApp/Networks/BJTClient/BJTLessonAPI.swift`, `.../Models/BJTLessonDTO.swift`, `FlashcardAppTests/BJTLessonAPITests.swift`, một fixture JSON redacted trong bộ test, phần contract ngắn tại `docs/ui-redesign/learn/README.md`. Tích hợp `project.pbxproj` theo membership thật. Dùng `BJTLevelAPI`, `LevelAPITests`, `BJTLearnerAPI` và `BJTFlashcardLibraryAPITests` làm pattern; không tạo bản thứ hai của token/session store.

**Nguồn API Fable báo cáo; cần xác minh trước khi code**:

| Operation | Auth | Điều phải xác minh |
| --- | --- | --- |
| `GET /levels/{code}/lessons` | public | accepted level code, kiểu list, ordering, pagination/nullability, error |
| `GET /levels/lessons/{slug}` | public | kiểu và nơi chứa `lessonContent`, field bắt buộc, ngôn ngữ, activity options/answer/rationale |
| `PUT /levels/lessons/{slug}/progress` với `{"completed": true}` | signed-in | path/body thực, Bearer + `Origin`, response, idempotency, trạng thái khi đã hoàn thành |

**Given/When/Then / test:**

1. Given fixture **lấy từ response thực** (Fable gợi ý `j5-01-greetings-intro`), when decode, then nhận đúng slug, tiêu đề theo language hiện có, vocabulary/grammar/examples/workplaceScenario/activities/rationaleVi; **không** dùng `contents[]` trống thay `lessonContent`.
2. Given unknown JSON keys hoặc optional field vắng, when decode, then bỏ unknown keys, optional section hiển thị trống đúng nghĩa; thiếu field bắt buộc/malformed answer trả lỗi, **không** âm thầm coi bài hỏng thành bài rỗng.
3. Given invalid level/slug (empty, slash, traversal, control chars), when call, then từ chối **trước** khi tạo URL. Bảo toàn UUID, enum/answer IDs do backend cấp.
4. Given 401/403/404/429/5xx, offline, malformed JSON, when request completes, then trả lỗi phân biệt phù hợp với luồng hiện tại. GET public không đính Bearer; authenticated PUT lấy token lúc subscribe, gửi `Origin`, không reuse token sau logout.
5. Given subscription disposed, when response đến muộn, then Alamofire cancel và không đưa stale state về UI; server PUT **không tự retry**. Không gọi PUT production để test; fixture/URLProtocol đủ cho K-01, thử PUT thật chỉ khi có tài khoản test + môi trường local được phép.

**DoD:** có bảng mapping request/response (đánh dấu verified vs unknown), fixture xuất phát từ runtime/source đã kiểm, URLProtocol tests (success/failure/cancel/auth), build scheme local, không sửa backend và không tạo màn hình mới. Nếu không xác minh được contract thì `BLOCKED`, không gán `VERIFIED` cho DTO đoán.

### K-02 — Danh sách bài học trong luồng cấp độ hiện có

**Outcome:** từ Today mở `HomeWireframe`, chọn J5…J1, thấy mục Bài học theo `weekNumber`, thời lượng và số hoạt động **nếu API có**. Các mục từ/kanji/grammar hiện có vẫn truy cập được; không thay Tab Bar/`MainTabbarName`.

**Tests:** loading/empty/error/retry, hủy request khi back, nhóm tuần ổn định, tên theo `AppLanguage.current`, màn có AX identifiers. Navigation XCUITest dùng `-InitialTab 0` (hoặc đường Today thực), **không** `-InitialTab learn`. Dùng một Simulator.

### K-03 — Lesson reader và đọc offline bài đã mở

**Outcome:** bối cảnh → từ vựng → ngữ pháp → ví dụ → lỗi hay mắc/điểm cần nhớ → CTA luyện tập (chỉ enable khi K-04 có). Từ có ID nội dung hợp lệ sẽ đi tới DictionaryEntry qua Wireframe hiện có; không tự ghép ID từ text.

**Cache:** kiểm header và `URLCache` trước; nếu response không cache được, lưu **tối thiểu** các bài đã mở dưới dạng JSON có phiên bản và atomic write, không tự động tải cả 420 bài, không cache Bearer. Offline chỉ hứa đọc bài đã cache thành công. Test đọc lại sau restart, JSON lỗi và cập nhật cache; khi không có dữ liệu thì báo rõ.

### K-04 — Activities và completion

**Outcome:** render các kiểu activity thật sự có trong fixture, chọn đáp án một lần, xem đúng/sai + `rationaleVi`, hoàn thành local và lần mở lại thấy tiến độ. **Không hiển thị số hoạt động giả định là 5 nếu API không trả 5.**

**Persistence:** nếu cần Realm `RLessonProgress`, nâng schema **6→7**, thêm `storedTypes`, test nâng cấp 3/5/6 và reopen, giữ nguyên deck/card/review. Chỉ ghi server `PUT` khi authenticated, user/session còn hợp lệ, contract đã xác minh; không tự retry kết quả không chắc chắn. Lưu tách `localCompleted` và trạng thái server xác nhận, tránh báo đồng bộ thành công khi chỉ mới lưu local; không tự đồng bộ guest backlog lúc đăng nhập.

### K-05 — Lưu từ trong lesson

**Outcome:** người học chọn từ và bộ thẻ; dùng `DictionaryDeckWriter` hoặc cùng repository hiện có, giữ nguyên chống trùng/ID; tuyệt đối không chèn thẻ không có hai mặt hoặc nghĩa không có trong API. Nếu lesson chỉ chứa text mà không có ID từ điển, phải kiểm field/lookup và làm mapping có test, không giả UUID. Không tạo deck/từ tự động nếu chưa có hành động người học.

**Tests:** lưu lần đầu, lưu trùng, từ thiếu dữ liệu, lỗi Realm, không ảnh hưởng dữ liệu của tài khoản khác, Today nhận số liệu mới sau quay lại (nếu đến hạn theo scheduler thật).

### K-06 — Today lesson slot (kết thúc MVP)

**Outcome:** phần bài tiếp theo/tiếp tục học ngắn gọn, chỉ từ progress thật; hoạt động của review hero hiện tại giữ nguyên. Khi chưa chọn trình độ, CTA chọn mức; khi đã hoàn thành, hiển thị bài tiếp theo. Không hiện số thẻ ngày mai tính bằng suy đoán.

**Tests:** guest, signed-in, offline, empty/error, switching account, reload sau khi quay lại; XCUITest luồng Today → lesson → activities → lưu từ → Today. Screenshot một Simulator ở cỡ chữ mặc định, mở rộng accessibility khi có lỗi hoặc đến gate release.

### K-07 / K-08 — Review thông minh sau MVP

**K-07:** xác minh endpoint distractors, chỉ bổ sung choice UI trong `CardReview` **thẻ tài khoản**. Đúng/sai chỉ quyết định phản hồi trắc nghiệm; sau đó người học phải **chọn rating hiện có** trước khi POST. Một hành động xác nhận → tối đa một POST tự động; kết quả không chắc chắn giữ trạng thái rõ, không tự gửi lại. Không dùng `Good`/`Again` tự động từ correct/wrong. Thiếu distractors → cho lật thẻ như hiện tại; bỏ qua câu hỏi không được tính đã ôn. Test VoiceOver thứ tự lựa chọn, fallback, chỉ một POST, kết quả server không xác nhận, Reduce Motion khi UI có animation. Quiz của CardStudy local giữ nguyên.

**K-08:** chỉ dùng `RReviewState.lapses`/lịch sử local hoặc dữ liệu leech/lapse được backend thực sự trả; ghi rõ hai nguồn và định nghĩa thời gian. Không suy đoán “sai hai lần tuần này” nếu store không lưu đủ bằng chứng. Không đổi tham số FSRS chỉ để làm queue.

## 7. Các story hoãn và điều kiện mở lại

- **K-10 (streak/plan):** mở sau khi định nghĩa được “ngày học” (múi giờ, guest và server, tránh record trùng), và có contract server thật. Không hiển thị streak tổng hợp giả.
- **K-11 (analytics):** separate privacy task + consent trong Settings (mặc định **off**), event schema tối thiểu không có nội dung từ tra cứu, token hay PII. Chỉ dùng POST `/analytics/events` sau khi xác minh; MetricKit cần kiểm cách đo đúng. Trước đó lấy kết quả học qua QA/usability, không dùng số giả làm baseline.
- **K-12 (Radar):** dùng `GET /daily-radar/cards`, lấy một item có nội dung thật; cache tối đa hợp lý, tránh tải payload `/home` khoảng 900 KB mà Fable đã cảnh báo. Không để lỗi Radar chặn Today/review.
- **K-13 (NHK):** chờ kết luận quyền sử dụng nội dung/âm thanh; có endpoint không đồng nghĩa có quyền tái xuất bản.
- **K-14…K-18:** trong phiên triển khai tổng thể theo Orca playbook, được lập brief nhỏ và làm phần **local khả thi** sau khi qua các gate; hoạt động cần quyền nội dung, thiết bị thật, backend mutation/idempotency hoặc thay đổi server/production phải chờ điều kiện riêng. Đặc biệt K-18 không được đánh dấu hoàn tất chỉ nhờ thuật toán reconcile phía iOS khi backend chưa có idempotency/identity contract.

## 8. Kiểm chứng, giới hạn và bàn giao

**Mỗi story:** `PLANNED → IMPLEMENTING → VERIFIED → DONE` theo `flashcard-delivery`; `DONE` cần có thay đổi, test/build/UI tương ứng và bản bàn giao. Chỉ cập nhật trạng thái từ **lệnh chạy thật**, không lấy số PASS từ tài liệu cũ. `BLOCKED` nêu chính xác yêu cầu/phụ thuộc thiếu; một API speculative không đủ để tạo DTO production.

**Quy trình Sonnet 5.5 normal:**

1. Đọc `AGENTS.md`, `docs/ENGINEERING_GUARDRAILS.md`, `.claude/skills/flashcard-delivery/SKILL.md`, `.claude/skills/flashcard-api-contract/SKILL.md` và **chỉ story được giao** trong file này; xem `git status` và diff liên quan trước khi edit.
2. Kiểm source/backend contract + fixture phù hợp trước; lấy content public read-only, không gọi mutation production hoặc ghi token/PII vào fixture. Một agent chính sở hữu `project.pbxproj` và các file dùng chung nếu chia task.
3. TDD RED→GREEN với XCTest đúng lớp, xác minh cancellation/error/đăng xuất; giữ target membership, build `FlashcardApp-Local`, sử dụng **một** iPhone Simulator cho UI; review diff khi đổi behavior đáng kể.
4. Khi thay Realm, test upgrade fixture từ schema cũ và reopen file; khi thay navigation, chạy XCUITest luồng đó; vi/en/ja vào `Localizable.xcstrings`. Không chạy ma trận UI không liên quan chỉ để tăng số test.
5. Ghi lại file đã sửa, nguồn fixture, kết quả lệnh thực tế, giới hạn còn lại; commit **local** cho story khi đủ chuẩn nếu phiên triển khai đã giao commit. Không push/publish/merge/đụng secret hoặc sửa backend khác khi chưa được giao.

**Các thước đo sản phẩm sau khi có consent/baseline:** first lesson completion, time to first answer, lesson drop-off, added-to-deck rate, D1/D7, review completion, crash-free sessions và latency. Các ngưỡng Fable nêu (D1 ≥30%, D7 ≥15%, completion ≥40%, v.v.) chỉ là **giả thuyết mục tiêu**, không là acceptance gate cho K-01…K-06.

**Điều chưa xác minh:** số bài/mức và chất lượng thực tế; rate limit; `lessonContent`/progress payload và `isCompleted`; progress web/iOS có cùng bản ghi hay không; backend distractors; quyền nội dung NHK; tất cả chỉ được nâng lên VERIFIED sau khi có bằng chứng cụ thể.

## 9. Lệnh giao riêng K-01 (khi không chạy Orca playbook)

> Đọc `docs/plans/kiokoto-ios-product-roadmap-2026-11-11.md` và workflow `flashcard-delivery`. **Chỉ triển khai K-01**. Xác minh API lesson bằng source/backend và response public redacted trước khi tạo DTO; dùng network/auth pattern, URLProtocol tests và target membership có sẵn. Giữ nguyên 5 tab/Realm schema và toàn bộ thay đổi không liên quan trong working tree. Chạy test + build local có bằng chứng, review diff, cập nhật K-01 trong plan với kết quả thực. Nếu contract PUT không thể kiểm chứng an toàn, đánh dấu phần đó UNVERIFIED/BLOCKED, vẫn hoàn thành phần GET độc lập; tuyệt đối không gọi PUT production. Chỉ commit local khi hoàn thành và được giao; **không push**. Kết thúc báo cáo tiếng Việt về file đổi, test chạy thật, rủi ro và story kế tiếp đề xuất; không tự bắt đầu K-02. **Đối với yêu cầu chạy toàn roadmap, sử dụng playbook ở đầu tài liệu; giới hạn K-01 trong prompt riêng này không áp dụng.**
