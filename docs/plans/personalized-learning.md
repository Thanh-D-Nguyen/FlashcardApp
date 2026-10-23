# Kế hoạch học cá nhân hóa

Ngày: 2026-10-23. Trạng thái: **PLANNED — chưa triển khai tính năng**.
Checkpoint trước khi lập kế hoạch: `99e4c8b` (tiếp nối `3fa411a`).
Đặc tả bố cục, tương tác, trạng thái và motion đề xuất: [personalized-learning-ux.md](personalized-learning-ux.md)
(U00–U05; chưa có prototype được duyệt, không thay đổi trạng thái L01–L07).
U00: ba phương án Today/Study/Results và đề xuất ở §14 của tài liệu UX — **đã duyệt** (2026-10-23); L03/L05 được code UI theo hướng đó.

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

### L02 — Lưu lịch sử an toàn (DONE — commit `2cf189d`)

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

### L03 — Nối phiên học với persistence (DONE — commit `4051455`)

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

**Kết quả triển khai (2026-10-23)**
- Quyết định: Study từ tab Cards luôn là phiên **có lưu** (không có chế độ "xem tự do" riêng; "Bỏ qua" tương đương xem rồi
  chuyển). Quiz lưu ngay khi chọn đáp án; flip có hai nút **Cần ôn lại / Đã nhớ** sau khi hiện đáp án (cùng trọng lượng, theo U00 đã
  duyệt), Next/Bỏ qua không tạo lượt. Việc ghi là **đồng bộ trên main thread** (một write Realm), nên không có trạng thái
  "đang lưu" riêng; chỉ có `none / saved / failed`. Chủ thể (`ownerKey`) được chốt khi bắt đầu một run; đổi/đăng xuất tài khoản
  làm phiên dừng, đóng băng và báo người học (hỏi lại khi quay về màn). Lưu lỗi: ở lại câu hỏi, đáp án giữ nguyên, **Thử lại**
  gửi đúng attempt cũ, **Rời phiên** có xác nhận; trong lúc chưa lưu: không đi tiếp, không đổi chế độ/xáo trộn/bắt đầu lại/sửa deck
  (menu bị tắt), nút Back hệ thống được thay bằng "Rời phiên" và vuốt-quay-lại bị tắt. Tiến độ và "Đã lưu n/N" chỉ đếm lượt đã lưu
  (khác "Thẻ n/N" là vị trí); mọi thay đổi run (restart, đổi chế độ, xáo trộn) đặt lại bộ đếm. Cách đọc hiện trước khi trả lời và nghe
  mặt trước được ghi là gợi ý (`noteHint`), có nhãn "Cách đọc đang bật · tính là gợi ý / Đã dùng gợi ý: cách đọc". Tổng kết chỉ
  tính lượt đã lưu: quiz đúng/sai, tự đánh giá tách riêng (không vào tỷ lệ), số thẻ bỏ qua, danh sách "Cần ôn lại". Xác nhận xóa
  deck/card nay nói rõ lịch sử học cũng bị xóa. Hook debug `-FailReviewSaves N` (chỉ `#if DEBUG`) để kiểm thử lỗi lưu trên UI thật.
- Sai khác so với mockup U00: không có chip "Tự nhớ/Chọn đáp án" trên thẻ; không có bước "Dừng sớm" (chưa có thao tác kết thúc sớm);
  bản dịch ja rút gọn (復習が必要 / 覚えた) để vừa nửa chiều rộng; nút tổng kết tái dùng "Xong".
- RED/GREEN: L03a (presenter): 22/110 test fail do assertion trên stub trước khi cài đặt; sau review, 2 test mới (đổi chế độ/xáo trộn
  đặt lại bộ đếm; phiên đã kết thúc bị đóng băng) fail trước khi sửa (đếm 4 > tổng 3) rồi xanh.
- Test: `FlashcardAppTests` 512 PASS / 0 fail / 5 skip (Keychain, build không ký); coverage `CardStudyPresenter.swift` 97% (trước các
  sửa review; logic mới đều có test). UI test (một Simulator iPhone 17, vi): `testDeckCanBeCreatedStudiedEditedPersistedAndDeleted`
  (đã cập nhật: lật → chấm → đã lưu 1 → bỏ qua → tổng kết), `testAFailedSaveKeepsTheLearnerOnTheCardUntilItIsRetried` (mới: lưu lỗi →
  không đi tiếp → hỏi khi rời → ở lại → thử lại → đếm tăng → rời không hỏi), `testStudyShowsExampleSentences…`,
  `testExampleSentencesCanBeAddedEditedRemovedAndRestored`: 4/4 PASS. Bằng chứng ảnh từ build thật:
  `docs/ui-redesign/personalized-learning/l03/` (rating, lưu lỗi, tổng kết — vi; rating — ja).
- Tiêu chí "thoát app trước tổng kết, mở lại vẫn còn": test tích hợp presenter + Realm thật trên đĩa (đóng/mở lại). Chưa có UI đọc
  lịch sử (L05), nên chưa kiểm bằng UI sau kill app.
- Review độc lập (`flashcard-reviewer`): 1 blocker (B1: đổi chế độ/xáo trộn không đặt lại bộ đếm đã lưu — đã sửa + test) và các điểm
  đã xử lý: khôi phục cử chỉ vuốt-quay-lại, phiên đã kết thúc bị đóng băng và hỏi lại, thông điệp đổi tài khoản trung tính, thông báo
  VoiceOver đăng sau khi vẽ lại và độc lập chế độ, tắt các mục menu khi chưa lưu, nhãn gợi ý khớp trạng thái cách đọc.
  Còn ghi nhận: gợi ý audio được ghi mỗi khi tự đọc mặt trước (quyết định sản phẩm); header luôn hiện "Đã lưu 0/N" kể cả khi chỉ
  xem; không kiểm "lưu sau khi deck bị xóa giữa phiên" vì `load()` dựng lại/thoát phiên khi deck đổi (giả định chưa có test riêng).
- NOT VERIFIED: Dynamic Type cỡ accessibility, VoiceOver thực tế, Reduce Motion, haptic và âm thanh trên máy thật (chỉ nối dây, đúng
  một lần/sự kiện theo thiết kế), chạy UI test song song nhiều thiết bị, giao diện tiếng Anh sau thay đổi cuối (đã xem trước đó).

### L04 — Lịch ôn có thể kiểm chứng (DONE — commit `c78053a`)

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

**Quyết định đã chốt (2026-10-23; người sở hữu sản phẩm chọn FSRS, phương án B)**
- Thuật toán: **FSRS-6**, tham chiếu `py-fsrs` 6.3.2 (open-spaced-repetition, giấy phép MIT), 21 tham số **mặc định** (không cá nhân
  hóa), `desired_retention` 0,90, khoảng tối đa 36500 ngày. Phiên bản lưu cùng lịch: `fsrs6-default`. Tham số mặc định được huấn
  luyện từ dữ liệu quần thể của nguồn gốc, **chưa hiệu chỉnh theo người học của app**: không hiển thị "xác suất nhớ" hay "đã thuộc"
  cho người học; chỉ dùng retrievability nội bộ trong công thức. Dữ liệu từ điển/mẫu câu trên server là nội dung học, không phải
  lịch sử ôn tập, nên không dùng để tối ưu tham số. Muốn tối ưu sau này cần lịch sử ôn thật (thư viện gốc có optimizer).
- Khác tham chiếu (có chủ đích): không có learning/relearning step tính bằng phút và **không fuzz** (một lượt trả lời được ghi một
  lần mỗi phiên, không có hàng đợi trong phiên; mọi khoảng ôn là số ngày nguyên ≥ 1; cùng đầu vào cho cùng lịch). Đây đúng là cấu
  hình `learning_steps=()`, `relearning_steps=()`, `enable_fuzzing=False` của thư viện gốc nên vẫn kiểm chứng được bằng vector.
  Làm tròn khoảng ôn theo half-to-even như Python. Đồng hồ lùi: một lượt có thời điểm trước lần ôn trước được lên lịch như thể xảy ra
  ở lần ôn trước (hạn không bao giờ sớm hơn lần ôn trước + 1 ngày); đây là khác biệt duy nhất không nằm trong vector tham chiếu và có test
  riêng. Hệ quả chấp nhận: nếu đồng hồ máy từng bị đặt quá xa về tương lai rồi sửa lại, lịch của thẻ đó bị kẹt ở thời điểm sai cho tới
  khi qua mốc ấy (không có đường khôi phục tự động).
- Kỹ năng và khóa: lịch riêng cho từng **chủ thể học + card + kỹ năng** (`recognition` từ quiz, `selfRecall` từ tự đánh giá); kết quả
  của kỹ năng này không đổi lịch của kỹ năng kia.
- Ý nghĩa rating (giả thuyết sản phẩm, có phiên bản, cần xem lại khi có dữ liệu): `incorrect`/`needsReview` → **Again**;
  `correct`/`remembered` không gợi ý → **Good**; có gợi ý (cách đọc/nghe trước khi trả lời) → **Hard**. Không bao giờ gửi **Easy**
  vì chưa có tín hiệu nào nói "dễ hẳn". Skip không tạo lượt nên không đổi lịch.
- Đổi nội dung (`contentVersion`): lịch cũ không còn hiệu lực — không xuất hiện trong danh sách đến hạn và lượt kế tiếp bắt đầu
  lịch mới; lịch sử attempt giữ nguyên với phiên bản cũ. Đổi tên deck/ảnh/ghi chú không reset (không nằm trong `contentVersion`).
- Dữ liệu: lịch là **dữ liệu suy ra** (attempt là nguồn sự thật). Cập nhật lịch nằm trong **cùng write transaction** với việc ghi
  attempt; retry cùng attempt không dời hạn lần nữa. Có `rebuildSchedules` phát lại attempt theo thứ tự để dựng lại lịch (đổi
  thuật toán/khôi phục). Xóa card xóa cả lịch. Hạn là **thời điểm tuyệt đối** (`lastReview` + n × 86400 s) nên không phụ thuộc múi
  giờ/giờ mùa hè; "đến hạn hôm nay" theo ngày lịch là việc của L05.
- Kiểm chứng: `scripts/fsrs_reference_vectors.py` sinh `FlashcardAppTests/FSRSReferenceVectors.swift` từ thư viện gốc (11 chuỗi
  ôn, gồm lapse, sớm/muộn, cùng ngày, retention 0,8, trần 30 ngày, lịch sử ngẫu nhiên seed 42); test Swift phải khớp.

**Kết quả triển khai (2026-10-23)**
- Code: `Entities/ReviewScheduler.swift` (FSRS-6 thuần Foundation: `ReviewGrade`, `FSRSParameters`, `ReviewState`, `ReviewScheduler.next/grade/
  isDue`), `Storage/Models/RReviewAttempt.swift` (+ `RReviewState`, `deleteReviewHistory(forCards:)`), `Interactors/ReviewHistoryStore.swift`
  (`save` cập nhật lịch trong cùng write transaction; `schedules`, `dueSchedules`, `rebuildSchedules`, `ensureSchedules`), schema 4 → 5
  (thêm bảng, không cần migration), `THIRD_PARTY_NOTICES.md` (MIT của py-fsrs).
- Bỏ qua bản cập nhật lịch nhưng vẫn lưu attempt khi attempt thuộc **wording cũ** đến muộn (sau khi card đã sửa và trả lời lại), để không
  đè lịch của wording hiện tại; phát lại theo thời gian cho cùng kết quả. `rebuildSchedules` là **phát lại theo thời điểm trả lời**, không
  phải khôi phục chính xác nếu các lượt được lưu không theo thứ tự thời gian (đồng hồ chỉnh lùi). `ensureSchedules` dựng lịch khi có
  attempt nhưng thiếu lịch hoặc lịch của thuật toán khác (cài đặt cũ ở schema 4, cập nhật thuật toán).
- RED/GREEN: bộ lập lịch stub → 12/16 test fail theo assertion, sau đó 16/16 PASS; lịch lưu: 13/46 fail → xanh; sau review 2 test mới
  (attempt cũ đến muộn, `ensureSchedules`) đỏ rồi xanh. Phép thử đột biến: đổi `exp(w8)` thành `exp(w8 + 0.001)` làm test vector đỏ (152 sai lệch).
- Kiểm chứng số học: 11 chuỗi vector tham chiếu khớp (ổn định/độ khó ≤ 1e-9 tương đối, hạn ≤ 1 ms). Reviewer độc lập còn biên dịch
  riêng `ReviewScheduler.swift` và so với py-fsrs 6.3.2 trên **3000 lịch sử ngẫu nhiên (38.398 bước; grade 1–4; khoảng cách < 1 ngày
  đến 4000 ngày; retention 0,7–0,99; trần 1/2/30/365/36500): 0 sai lệch**.
- Test: `FlashcardAppTests` 546 PASS / 0 fail / 5 skip (Keychain, build không ký). Coverage `ReviewScheduler.swift` 100% (77/77),
  `ReviewHistoryStore.swift` 100% (137/137) trước các sửa review nhỏ (nhánh mới có test). Fixture nâng cấp: database **schema 4 thật**
  (store schema 3 nâng bởi code schema 4, có attempt) → mở bằng schema 5 giữ deck/card/ví dụ/attempt, bảng lịch rỗng, `rebuildSchedules`
  dựng đúng lịch.
- Review độc lập (`flashcard-reviewer`): không blocker. Đã xử lý: store schema 4 cũ không có lịch (→ `ensureSchedules`), attempt wording cũ
  đến muộn, bổ sung test (lịch của thuật toán khác không "đến hạn", xóa deck/card xóa lịch), tiền điều kiện cho tham số, bỏ trường
  `lastAttemptId` không có consumer, NOTICE giấy phép.
- **Điều kiện cho L05**: gọi `ensureSchedules(ownerKey:)` một lần trước khi đọc lịch; chỉ dùng `dueSchedules` (không dùng `schedules` để
  suy ra "đến hạn" vì nó có cả lịch cũ/khác thuật toán); `dueSchedules` có thể trả hai dòng cho một card (recognition và selfRecall) nên
  gộp theo card khi hiển thị một lần; "đến hạn hôm nay" theo ngày lịch cục bộ là việc của L05; hiển thị `THIRD_PARTY_NOTICES` (màn
  cảm ơn/giấy phép) là điều kiện trước phát hành.
- Chưa kiểm chứng: không có test ép lỗi giữa chừng một transaction (lịch và attempt cùng một `realm.write` nên nguyên tử theo cấu trúc,
  nhưng nếu ai tách thành hai transaction thì test hiện tại vẫn qua); test múi giờ/DST chỉ khẳng định lịch là thời điểm tuyệt đối vì bộ lập
  lịch không dùng `Calendar`; tham số FSRS mặc định chưa hiệu chỉnh theo người học của app; ý nghĩa rating là giả thuyết sản phẩm.

### L05 — Today từ dữ liệu thật (DONE — L05a logic `6ea9cda`, L05b giao diện `16e7db8`; sau L04)

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

**Quyết định đã chốt cho L05 (2026-10-23; theo hướng Today A đã duyệt ở U00)**
- Today lập kế hoạch cho **một bộ thẻ đang chọn** (một deck thì là deck đó; nhiều deck mà chưa chọn thì hỏi; lựa chọn lưu theo chủ thể,
  deck bị xóa thì quay về chọn). Loại bài đang xét theo **chế độ học hiện tại**: flip → `selfRecall`, quiz (và deck tạo được quiz) →
  `recognition`; "đến hạn" chỉ tính lịch của loại bài đó, nên học xong thì số đếm giảm đúng.
- Trạng thái: `noDeck`, `chooseDeck`, `practice` (chưa từng trả lời loại bài này: "Luyện bộ thẻ này", không gọi là đến hạn/đã quên),
  `due`, `returning` (đến hạn và lần ôn gần nhất cách ≥ 7 ngày: phiên nhỏ + hiện cả tồn), `nothingDue`, `doneToday`. Số đến hạn =
  đếm từ lịch hiện hành của wording hiện tại; "đã lưu hôm nay" = lượt đã lưu trong **ngày lịch cục bộ** của deck đang chọn, quiz đúng/sai
  tách khỏi tự đánh giá.
- Phiên: các thẻ đến hạn, cũ nhất trước, tối đa theo ngân sách 3/5/10 phút (mặc định 5). **Giả thuyết chưa đo**: 20 giây/mục (3 → 9,
  5 → 15, 10 → 30 mục) vì app chưa ghi thời gian phản hồi; phút chỉ để cỡ phiên và hiển thị "ước tính" cạnh số mục thật, cần usability
  test trước khi coi là mặc định đúng. Phiên không chèn thẻ mới vào lúc có thẻ đến hạn; thẻ chưa học chỉ vào qua "Luyện bộ thẻ này" /
  "Luyện thêm" (học cả bộ như tab Cards, vẫn lưu kết quả). `CardStudyWireframe(deckId:cardIDs:)` học đúng danh sách thẻ theo thứ tự
  đã lập (bỏ qua xáo trộn; thẻ đã bị xóa thì bỏ qua; không còn thẻ nào thì rời màn).

**Kết quả triển khai L05b — giao diện Today (2026-10-23)**
- Code: `Modules/Today/` (`TodayPresenter` với `makeState` thuần, `TodayViewController` gồm hero/hàng deck/hàng thời lượng/tiến độ/hàng Cấp độ,
  `TodayWireframe`), tab đầu tiên là Today (`MainTabbarName.today`), `TextRole.heroFigure`, `CardStudyWireframe(deckId:cardIDs:)`,
  `StudySession(quizPool:)`, schema Realm 5 → 6 (bỏ cột `RReviewState.lastAttemptId` không dùng; không xóa dữ liệu, có fixture nâng cấp
  từ schema 5 có cột thừa). Chuỗi vi/en/ja trong `Localizable.xcstrings` (có plural "%lld more are waiting").
- Review độc lập (`flashcard-reviewer`) tìm **blocker B1**: phiên quiz theo danh sách ít thẻ rơi về flip/thiếu đáp án nhiễu → sửa bằng
  `quizPool` (toàn deck làm nguồn đáp án nhiễu), có test. Đã sửa thêm: N1 (luyện tiếp bằng thẻ chưa học: `practiceCardIDs`), N2 (đến hạn
  theo ngày lịch cục bộ: `dueBefore` = cuối ngày), N3 (làm mới khi vào foreground/đổi ngày/múi giờ), N4 (`Calendar.autoupdatingCurrent`),
  N7 (deck rỗng → `noDeck`), N10 (plural), N8 (assert tiến độ chính xác).
- Test: `FlashcardAppTests` **628 PASS / 0 fail / 5 skip** (Keychain, build không ký) sau các sửa review (trước đó coverage `TodayPlan.swift`
  100%, `TodayInteractor.swift` 100% ở L05a). UI test trên một Simulator (iPhone 17): hành trình Today (chọn deck → luyện → thấy "Đã lưu 1 lượt
  học" → đổi thời lượng 3/5/10) PASS; thêm 6 UI test không cần backend PASS (tạo/học/sửa/xóa deck, lưu lỗi rồi thử lại, offline + tài khoản,
  đổi ngôn ngữ tab "Today"/"今日", ví dụ câu sau khi lật, Cấp độ ở cỡ chữ accessibility).
- Bằng chứng UI: `docs/ui-redesign/personalized-learning/l05/` (`today_practice_vi_light.png`, `today_done_vi_light.png`,
  `today_ax_xxxl_en_light.jpg`). Ở cỡ chữ AX XXXL nút hero từng vỡ chữ → bỏ mũi tên và dùng góc `.large` ở cỡ accessibility, đã chụp lại.
- Lệch so với thiết kế U00: trạng thái "đã xong" không có nút "Xem kết quả"; chọn deck/thời lượng qua action sheet có dấu ✓; định danh
  `tab_levels` nay nằm trên tab Today (hàng "Cấp độ" mở Levels); "đến hạn" tính theo ngày lịch cục bộ; luyện tiếp có thể dùng thẻ chưa học.
- **Chưa kiểm chứng / rủi ro còn lại**: (1) 3/5/10 phút và 20 giây/mục là giả thuyết, chưa qua usability test (U05); (2) 5 UI test gọi API
  thật **NOT VERIFIED** vì backend `localhost:18081` không chạy (hạ tầng, không phải lỗi mã nguồn); (3) VoiceOver với hàng `UIControl`,
  haptics, Reduce Motion, dark mode, iPad và DST chưa kiểm bằng runtime; (4) N5: `ensureSchedules`/băm nội dung chạy trên main thread mỗi lần
  nạp Today — chưa đo với deck lớn; (5) N6: phiên theo danh sách bỏ qua tuỳ chọn xáo trộn; (6) N9: chưa có alias `tab_today`.
- Tiếp theo: L06 cần hợp đồng API/nội dung/quyền âm thanh đã xác minh (cổng sản phẩm); L07 cần pilot thật.

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
