# Kế hoạch học cá nhân hóa

Ngày: 2026-10-23. Trạng thái: **PLANNED — chưa triển khai tính năng**.
Checkpoint trước khi lập kế hoạch: `99e4c8b` (tiếp nối `3fa411a`).
Đặc tả bố cục, tương tác, trạng thái và motion đề xuất: [personalized-learning-ux.md](personalized-learning-ux.md)
(U00–U05; chưa có prototype được duyệt, không thay đổi trạng thái L01–L07).
U00: ba phương án Today/Study/Results và đề xuất đã có ở §14 của tài liệu UX — **chờ duyệt thị giác** trước khi code UI L03/L05.

## Mục tiêu và giới hạn

Người học mở app biết nên học gì, được ôn đúng phần còn yếu và thấy tiến bộ
qua nhiều ngày. Giả thuyết sản phẩm đầu tiên: người Việt khoảng N4–N3 đang
sống hoặc chuẩn bị làm việc tại Nhật, biết từ nhưng khó nghe và phản hồi.
Phân khúc, khả năng trả phí và hiệu quả học chưa được kiểm chứng.

Thứ tự: lưu kết quả thật → lịch ôn → Today → một chủ đề tình huống có kiểm duyệt
→ thử nghiệm trả phí. Không triển khai toàn bộ roadmap trong một lần giao việc.
Mỗi story dưới đây là một phần có thể review và commit riêng sau kiểm chứng.
Các mã L01–L07 phân biệt với P0 UI cũ trong `ENGINEERING_GUARDRAILS.md`.

Chưa đưa vào phạm vi đầu tiên: đồng bộ tiến độ, tải từ điển offline, chatbot tự do,
chấm phát âm bằng AI, bảng xếp hạng, năm mini-game riêng biệt, StoreKit hoặc paywall.
Không hứa số từ đã thuộc, thời gian thành thạo hay doanh thu khi chưa có bằng chứng.

## Hiện trạng đã đối chiếu

- `FlashcardApp/Entities/StudySession.swift`: state machine của một phiên; có
  flip/quiz, thứ tự, số câu trả lời và số câu đúng; chưa có persistence.
- `FlashcardApp/Modules/CardStudy/CardStudyPresenter.swift`: điều phối phiên,
  speech, câu ví dụ; tái sử dụng điểm tương tác này thay vì tạo luồng học song song.
- `FlashcardApp/Modules/Home/HomePresenter.swift` và
  `FlashcardApp/Interactors/HomeInteractor.swift`: danh sách cấp độ/nội dung API.
- Realm schema 3 lưu deck/card và chỉnh sửa câu ví dụ. Không có dictionary bundle.
- `BJTLearnerAPIInterface` hiện có preview/generate deck, đọc deck và tìm ảnh.
  Chưa xác nhận contract review/sync hay API tình huống của backend đang chạy.
  Thiếu integration trong iOS không có nghĩa server thiếu endpoint.

## Quyết định cho bản đầu

- Giữ UIKit/VIPER, Realm, RxSwift và networking hiện có; không thêm kiến trúc hay
  dependency để áp dụng quy trình AI.
- Giữ `StudySession` thuần trạng thái; Interactor phối hợp ghi kết quả qua lớp
  lưu trữ dùng `RealmService`. Không ghi database từ View hoặc state machine.
- Học trước trên card đã lưu. Khóa tiến độ theo chủ thể học + card ID + kỹ năng;
  không gom các card có cùng chữ thành một từ đã thuộc. Không dùng `hashValue`.
  Với nội dung remote trong giai đoạn sau, giữ nguyên source kind và UUID server.
- Tiến độ mới tách theo guest trên thiết bị hoặc UUID tài khoản. Login/logout
  không tự nhập tiến độ guest vào tài khoản; giữ dữ liệu guest để có thể quay lại.
  Không đổi ownership của các deck hiện có trong story này. Chưa có sync liên thiết bị.
- Lưu mỗi lượt đã trả lời; không chờ đến màn tổng kết. Kết quả và trạng thái ôn
  liên quan phải ghi nguyên tử. Mỗi lượt có ID ổn định để retry local không tính đôi.
- Lưu loại bài luyện, kết quả, thời gian, gợi ý đã dùng và phiên bản nội dung cần
  thiết để hiểu kết quả. Chỉ thêm trường có consumer/test trong story hiện tại.
- Lật thẻ, nghe audio hoặc bấm Next không phải bằng chứng nhớ. Quiz đúng thể hiện
  nhận biết; tự đánh giá khi lật thẻ được ghi là tự đánh giá, không giả làm bài kiểm tra.
- Kết quả nghe, nhận biết và tự nhớ lại không nâng trạng thái của nhau. Bản đầu chỉ
  kích hoạt kỹ năng thực sự có bài luyện; không tạo điểm nghe/nói giả.
- Đổi nội dung front/back/reading của card phải làm mất hiệu lực lịch ôn cho nội dung
  cũ, nhưng giữ lịch sử có phiên bản. Đổi tên deck/ảnh không tự reset kiến thức.
- Xóa card/deck không để lại mục ôn mồ côi. Chính sách xóa lịch sử theo card phải
  được thể hiện trong xác nhận xóa và test; không xóa dữ liệu học khác.

## Thứ tự thực hiện và nghiệm thu

### L01 — Kết quả một lượt học (DONE — commit `b32cfa8`)

Phạm vi: `Entities/StudySession.swift`, `FlashcardAppTests/StudySessionTests.swift`;
thêm value type chỉ khi cần cho consumer lưu trữ, đăng ký target đầy đủ.

Tiêu chí:
- Given một câu quiz, when chọn đáp án hai lần, then chỉ phát sinh một kết quả.
- Given chỉ flip/next/back, then không tự suy ra trả lời đúng hoặc nhớ vững.
- Given restart hoặc một lượt mới, then ID lượt mới khác; retry cùng lượt giữ ID.
- Kết quả chỉ rõ card, mode/kỹ năng và gợi ý; giữ hành vi quiz/flip hiện tại.

Test RED trước khi đổi logic; test clock/random bằng đầu vào cố định.
Commit dự kiến: `feat(study): model completed review attempts`.

**Kết quả triển khai (2026-10-23)**
- Quyết định: `ReviewAttempt` (id, cardID, `ReviewResult`, `hints`, `answeredAt`) trong
  `StudySession.swift`, không đổi `project.pbxproj`. `ReviewResult` gộp
  correct/incorrect (kỹ năng `recognition`) và remembered/needsReview (`selfRecall`) nên
  không tạo được tổ hợp vô nghĩa. ID = `<runID>/<vị trí>`: ổn định trong một lượt chạy
  (retry lưu cùng giá trị không tính đôi); `restart`/`setMode`/`setShuffled` tạo run mới.
  `rate(_:)` chỉ hợp lệ khi đã lật đáp án ở chế độ flip; `noteHint(_:)` (reading/audio) chỉ tính
  trước khi lộ đáp án. **Skip/Next không tạo attempt** (không có consumer ở L01); summary
  L03 chỉ đếm attempt đã lưu. Tự đánh giá không vào `answeredCount/correctCount`.
- Bổ sung sau khi bắt đầu L02: `StudyCard.contentVersion` (SHA-256 của front + reading + back, tách bằng U+001F;
  không tính note/ảnh/id) được gắn vào `ReviewAttempt`, vì kế hoạch yêu cầu lưu phiên bản nội dung và L04 cần nó để
  vô hiệu lịch cũ khi card đổi. Thuật toán được khóa bằng test với giá trị `shasum`; `StudySessionTests` 36/36 PASS.
- Chưa có trong L01 (để story có consumer): thời gian suy nghĩ, wiring presenter/UI (L03). `StudyMode`/presenter không đổi hành vi.
- RED: 12/31 test mới fail do assertion trên stub không hành vi (attempts rỗng, ...).
- GREEN: `StudySessionTests` 32/32 PASS; hồi quy `CardStudyPresenterTests` +
  `CardsIntegrationTests` + `LocalizationTests` 57/57 PASS (XcodeBuildMCP, scheme
  `FlashcardApp-Local`, iPhone 17, `CODE_SIGNING_ALLOWED=NO`, không song song).
- Coverage `StudySession.swift` 93,3% (152/163 dòng); phần chưa phủ là `StudyCard.init(entity:)`
  và closure mặc định production, không thuộc L01. Không đo coverage toàn app.
- Review: tự review kiến trúc/hồi quy (logic thuần, không UI/Realm/API), **không độc lập**.
- Rủi ro còn lại: chưa có consumer thật cho `ReviewAttempt` đến L02/L03; semantics Skip
  có thể cần đổi khi L03/L04 xác định summary và scheduler.

### L02 — Lưu lịch sử an toàn (VERIFIED — chờ commit hash bên dưới)

Phạm vi: `Services/RealmService.swift`, `Storage/Models/`, interactor/store học
phù hợp với pattern hiện có; `RealmServiceTests` và integration tests của store.

Tiêu chí:
- Ghi lượt, đóng/mở Realm mới, đọc lại đúng chủ thể/card/kết quả.
- Ghi lại cùng ID không tăng số lượt; transaction lỗi không ghi một phần.
- Nâng store schema 3 giữ ID, thứ tự và liên kết RDesk/RCard, RCardExample, cùng
  các trường dữ liệu người học hiện có; kiểm tra thêm đường nâng schema cũ được hỗ trợ.
- Fixture nâng cấp là database theo schema cũ, không chỉ là store mới gắn số version.
- Đổi tài khoản không đọc tiến độ của tài khoản khác; guest không bị mất khi đăng nhập.
- Dùng giá trị khi qua thread; không truyền Realm object còn sống sang queue khác.

Tăng schema từ version thực tế lúc triển khai, thêm model vào `storedTypes`.
Không sửa migration cũ để xóa store. Commit: `feat(study): persist learner review history`.

**Kết quả triển khai (2026-10-23)**
- Quyết định: `RReviewAttempt` (khóa `ownerKey|attemptId`, `cardId`, `contentVersion`, `result` thô, `hints` đã sắp xếp,
  `answeredAt`); `skill` không lưu vì suy ra từ `result` (mapping được ghim bằng test). `RealmReviewHistoryStore`
  (`Interactors/`, theo mẫu `CardExampleStore`): `save` tra-cứu-rồi-ghi trong **cùng một write transaction**, trả
  `true` khi ghi mới, `false` khi retry cùng attempt (so thời gian với dung sai 1 ms vì Realm làm tròn `Date`),
  ném `.conflictingAttempt` khi cùng id nhưng khác nội dung và giữ bản đã lưu, `.invalidAttempt` khi thiếu id/card/version.
  `attempts(ownerKey:cardId:)` trả value type theo thứ tự trả lời, bỏ qua `result` lạ (không đoán). Schema 3 → 4
  (thêm bảng, không cần migration). `DeskManagement.update/delete` xóa lượt học của card bị bỏ/xóa trong cùng transaction;
  sửa nội dung card **giữ** lịch sử (gắn `contentVersion` cũ). `ownerKey` giống `CardExampleStore`: UUID tài khoản hoặc
  `""` cho guest; guest không bị gộp vào tài khoản và vẫn còn khi đăng nhập.
- RED: store stub → 16/32 fail theo assertion; schema 3 không crash khi thêm bảng (Realm tự thêm bảng), nên RED nâng cấp
  là khẳng định version chưa tăng. GREEN sau khi cài đặt và tăng schema.
- Test: `ReviewHistoryStoreTests` 12, `RealmServiceTests` (fixture **database schema 3 thật** gồm 2 deck, thứ tự card,
  mọi trường card, ba loại `RCardExample`; cộng đường nâng từ schema 1 và 2), `DeskManagementTests` +3, `StudySessionTests` 37:
  69/69 PASS; toàn bộ `FlashcardAppTests` 482 PASS / 0 fail / 5 skip (Keychain, build không ký). Coverage
  `ReviewHistoryStore.swift` 100% (50/50), `RReviewAttempt.swift` 100% (4/4) trước hardening (logic không đổi nhánh).
- Runtime: build/launch trên iPhone 17 với container có sẵn 2 deck (30 + 20 card): app mở store schema 4, hai deck còn nguyên
  (tab Cards). Không kiểm UI journey vì chưa có UI dùng store này.
- Review độc lập (`flashcard-reviewer`): không blocker. Đã xử lý: lookup chuyển vào trong transaction; ghi chú tính duy nhất
  của khóa; ghim mapping result→skill. Ghi nhận, chưa làm (thuộc L03): (1) xác nhận xóa deck/card phải nói rõ lịch sử
  học của card cũng bị xóa (chưa ai theo dõi — **thêm vào tiêu chí L03**); (2) `save` không kiểm card còn tồn tại, nên L03
  phải từ chối lưu khi deck đã bị xóa giữa phiên; (3) store chỉ dùng trên main thread, L03 phải giữ ràng buộc này.
- Chưa có test ép transaction lỗi: `save` là một `realm.write` duy nhất nên nguyên tử theo cấu trúc; chỉ kiểm gián tiếp
  rằng id/nội dung không hợp lệ hoặc xung đột để lại đúng số dòng. Rollback: build cũ không mở được store schema 4;
  khắc phục bằng bản sửa tiến về trước, không xóa/hạ cấp store.
- Rủi ro còn lại: chưa có consumer thật (L03); `contentVersion` và mapping result→skill là hợp đồng bền, đổi cách tính
  phải có migration.

### L03 — Nối phiên học với persistence (PLANNED; sau L02)

Phạm vi: `Modules/CardStudy/`, `Interactors/CardStudyInteractor.swift`,
`Resources/Localizable.xcstrings`, presenter/integration tests và UI test liên quan.

Tiêu chí:
- Trả lời xong, thoát app trước tổng kết, mở lại vẫn có kết quả đã xác nhận lưu.
- Lưu lỗi hiện trạng thái có thể retry/thoát; không hiển thị thành công giả.
- Double tap, quay lại, restart hoặc retry không nhân đôi lượt đã ghi.
- Đổi tài khoản giữa lúc lưu không gán kết quả sang chủ thể mới.
- Nếu thêm tự đánh giá flip, giải thích rõ và bản địa hóa vi/en/ja; không tự đánh
  giá thay người học. Giữ menu, câu ví dụ, chỉnh sửa deck và navigation hiện có.
- Xác nhận xóa deck/card nói rõ lịch sử học của các card đó cũng bị xóa (vi/en/ja); không lưu lượt khi deck đã bị xóa
  giữa phiên; lưu qua `RealmReviewHistoryStore` chỉ trên main thread.
- Thiết kế UI theo hướng đã chọn ở U00 (`personalized-learning-ux.md` §14) sau khi được duyệt thị giác; gọi
  `noteHint(.reading)` khi cách đọc đang hiện trước khi trả lời.

Commit: `feat(study): save completed attempts during sessions`.

### L04 — Lịch ôn có thể kiểm chứng (PLANNED; sau L03)

Phạm vi: logic lịch ôn thuần Foundation, store ở L02 và focused XCTest.

Trước coding, chốt trong story: thuật toán/version, ý nghĩa rating, khoảng ôn,
giới hạn, cách xử lý đổi nội dung và thời gian. So sánh thuật toán đơn giản có nguồn
với FSRS dựa trên chi phí tích hợp Swift, giấy phép và dữ liệu đầu vào thực có.
Không tự gọi một heuristic là FSRS hoặc công bố xác suất nhớ chưa hiệu chỉnh.

Tiêu chí:
- Cùng trạng thái + kết quả + thời điểm cho cùng lịch; test mốc trước/đúng/sau hạn.
- Kết quả và lịch mới cập nhật nguyên tử, retry cùng lượt không dời hạn lần nữa.
- Lượt có gợi ý hoặc chỉ nhận biết không bị tính thành tự nhớ lại không hỗ trợ.
- Quá hạn, đổi múi giờ/giờ mùa hè, clock lùi và khoảng nghỉ dài có test rõ ràng.
- Không có review card đã xóa hoặc nội dung đã bị thay đổi mà vẫn mang lịch cũ.

Commit: `feat(study): schedule reviews from persisted attempts`.

### L05 — Today từ dữ liệu thật (PLANNED; sau L04)

Phạm vi: `Modules/Home/`, Home/CardStudy wireframes và interactors,
localization, HomePresenterTests và hành trình XCUITest.

Tiêu chí:
- Một CTA mở phiên từ các mục đến hạn, số đếm khớp query thực tế.
- Không có card/lịch sử: hướng dẫn tạo hoặc chọn deck; không dùng số liệu demo.
- Đã xong hôm nay: có điểm kết thúc và lựa chọn học tiếp; không ép thêm bài.
- Quay lại sau nghỉ dài: đề xuất phiên nhỏ, cho xem tổng số đến hạn, không giấu
  phần tồn hoặc thêm từ mới vượt thời lượng người học chọn.
- Cấp độ vẫn truy cập được; giữ đủ bốn tab và luồng cũ; local deck hoạt động khi API lỗi.
- “Đúng hôm nay” khác “nhớ qua nhiều ngày”; thời lượng là ước tính, không cam kết.

Chọn default giới hạn phiên bằng usability test, không đóng cứng ví dụ 8+5.
Build/test/chụp UI trên một Simulator theo guardrails.
Commit: `feat(home): show today's review plan`.

### L06 — Một chủ đề tình huống (PLANNED; sau L05 và kiểm chứng API/nội dung)

Khởi đầu bằng một chủ đề sinh hoạt, khoảng 10 tình huống; học nghe → phản hồi →
giải thích → ôn lại biến thể. Không xây một engine truyện tổng quát trước khi có bài.

Điều kiện vào: đọc contract và response đã che thông tin riêng tư; xác nhận ID,
nghĩa/ngữ cảnh, audio, nguồn/quyền dùng, ngôn ngữ và đáp án được người có chuyên môn duyệt.
Thiếu endpoint/audio/nội dung phải ghi rõ; không bịa DTO, route hay đáp án bằng AI.

Nghiệm thu: nghe trước khi hiện transcript; có lựa chọn dùng gợi ý; chấp nhận đáp án
hợp lệ; lỗi mạng/retry/cancel rõ ràng; kết quả nghe không tăng điểm nói. Bài kiểm tra
sau vài ngày dùng biến thể chưa học. Tách commit content/API và UI nếu đủ lớn.

### L07 — Kiểm chứng giá trị trả phí (PLANNED; sau pilot L06)

Thử với nhóm nhỏ đúng phân khúc, ghi cả người bỏ học và người tiếp tục. Đo hoàn
thành phiên đầu, quay lại ngày 7, kết quả kiểm tra trì hoãn bằng biến thể và mua thực.
Định nghĩa mẫu số, cohort và tiêu chí tiếp tục trước pilot; không tự đặt benchmark
thành công như một sự thật thị trường. Không thu âm/nội dung cá nhân mặc định.

Chỉ sau bằng chứng giá trị mới đặc tả paywall/StoreKit: trial, restore, hủy/hết hạn,
quyền lợi và sandbox tests. Deck tự tạo/lịch sử của người học không bị giữ làm điều kiện trả phí.
Chưa thực hiện gửi tin, thu tiền, publish hay thay đổi dữ liệu server trong kế hoạch này.

## Rủi ro và cách giao việc

- L02/L04 là rủi ro dữ liệu: review độc lập, test upgrade/transaction; rollback code
  không đảm bảo đọc được store đã nâng schema. Không downgrade/xóa store để rollback;
  ưu tiên bản sửa tiến về trước, bảo toàn dữ liệu.
- Backend sync chưa có contract được xác minh: không chặn L01–L05 local vì giả định
  server, cũng không thêm hàng đợi sync hoặc tự retry mutation từ bây giờ.
- Story nhiều lớp phải giao phạm vi file riêng cho người/agent; không giao hai agent
  cùng `project.pbxproj`, catalog hoặc migration. Người tích hợp sở hữu các file chung.
- Quy tắc kiểm chứng và quyền external action theo `../ENGINEERING_GUARDRAILS.md`
  và `../../AGENTS.md`. Mỗi story giữ acceptance, RED/GREEN, review, command/result,
  phần chưa kiểm chứng và commit thực tế ngay tại mục tương ứng khi thực hiện.
- Commit tính năng gồm test và implementation đã xanh; RED là bằng chứng chạy test,
  không bắt buộc tạo commit cố ý làm hỏng build. Không đánh dấu DONE chỉ vì đã có plan.

## Bằng chứng checkpoint (không phải nghiệm thu L01–L07)

- 2026-10-23: `scripts/tests/environment-validation.sh`: 18 ca PASS.
- XcodeBuildMCP `simulator test`, scheme `FlashcardApp-Local`, iPhone 17e iOS 26.5
  (`4D3A7DC6-7A3C-4BBB-98D6-A962E27CFA82`), `CODE_SIGNING_ALLOWED=NO`,
  `-disableAutomaticPackageResolution`, `-parallel-testing-enabled NO`:
  `LocalizationTests` + `StudySessionTests`: 22 PASS, 0 fail, 0 skip.
- Build app/test bundle thành công trong lệnh test trên; pins dependency không đổi.
- Review checkpoint: không có blocker; catalog có 15 key prototype chỉ có comment
  và một key rỗng. LocalizationTests của bundle thực tế vẫn PASS; chưa xác nhận UI prototype.
- Không đo coverage toàn app, chưa chạy UI journey, backend live, Keychain có ký,
  migration mới hoặc kiểm thử thiết bị thật. Không xem đây là chứng nhận release.
