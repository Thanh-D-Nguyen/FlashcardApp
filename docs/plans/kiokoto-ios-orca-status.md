# Kiokoto iOS — Orca status

Nguồn: [playbook](kiokoto-ios-orca-execution.md), [roadmap](kiokoto-ios-product-roadmap-2026-11-11.md).
Branch tích hợp: `Thanh-D-Nguyen/kiokoto-ios-integration` (chưa push). Worktree: `/Users/thanhnguyen/orca/workspaces/FlashcardApp/kiokoto-ios-integration`.
Model thực tế của phiên này: Sonnet 5.5 (`claude-sonnet-5-5`) — chưa có launch receipt từ Orca để đối chiếu effort.

lastKnownGoodCommit: `5a0eb80` (K-04); K-01 `af05f0e` → K-02 `d3d991f` → fix K-01 `31c1504`; baseline `d66c631`.
Story kế tiếp: **K-06**. File đang do integration owner giữ: `project.pbxproj`, `Localizable.xcstrings`.

| Story | State | Owner | Commit | Test/build/UI evidence | Blocker/Next |
| --- | --- | --- | --- | --- | --- |
| K-01 | VERIFIED (local commit) | integration | `af05f0e` | `BJTLessonAPITests` 16/16 PASS (XcodeBuildMCP `test_sim`, scheme FlashcardApp-Local, iPhone 17 Pro iOS 26.4, 2026-11-11); app + test target build qua test. Fixture từ GET production ẩn danh; 516/516 activity thật thoả điều kiện answer. Không có UI → không có kiểm Simulator UI. | PUT progress chỉ xác minh theo source backend, **NOT VERIFIED** với server thật. GET ẩn danh luôn `isCompleted=false`. Reviewer Codex chưa chạy (**review độc lập chưa có**). Chưa chạy toàn bộ test suite. RED hành vi: không có (test và code viết cùng lượt). |
| K-02 | VERIFIED (local commit) | integration | `d3d991f` | **RED thật:** `LessonListPresenterTests` 8/8 fail trên skeleton rỗng (vd. `idle` ≠ `empty`, sections rỗng) và `HomePresenterTests/testLessonsAreOffered…` fail (`nil` ≠ `J5`) — rồi cài đặt → **GREEN**: 51/51 (LessonList + Home + Localization + BJTLesson). Full `FlashcardAppTests` 1302 pass / 0 fail. XCUITest `testLevelScreenOpensItsLessonsGroupedByWeek` PASS. Simulator iPhone 17 Pro iOS 26.4, cỡ chữ mặc định, ngôn ngữ en: ảnh chụp danh sách Tuần 1 thật và trạng thái offline+Retry. | Backend local không chạy → UI chạy qua proxy **chỉ-GET** localhost:18081→kiokoto.com (PUT bị chặn 405). Hàng bài chưa bấm được (K-03). Chưa kiểm VoiceOver/Dynamic Type lớn. Không hiện `isCompleted` (GET ẩn danh luôn false). Tiêu đề bài là tiếng Việt khi app en (API không có tiếng Anh). |
| K-03 | VERIFIED (local commit) | integration | `febe083` + `6e7e85d` (project membership) | **RED thật:** 21 fail / 8 pass trên skeleton rỗng (cache/interactor/presenter/selectRow) → GREEN 46/46 (BJTLesson+Reader+Cache+List, sau cherry-pick fix K-01). Full `FlashcardAppTests` 1323/1324: 1 fail `DictionaryHandwritingPresenterTests/testAnotherStrokeBeforeTheDelayReplacesTheRequest` (timing, không liên quan) — chạy riêng lại 9/9 PASS, lần full trước đó cũng PASS ⇒ flaky có từ trước, không do K-03. XCUITest Today→cấp độ→Bài học→mở bài PASS (qua proxy chỉ-GET). Ảnh chụp thật: reader online (Situation, Vocabulary, Key points…) và **offline** (proxy tắt) hiện banner + bản đã lưu; file `Application Support/Lessons/j5-01-greetings-intro.json` xuất hiện. | Bắt được lỗi runtime: wireframe không được giữ sau push ⇒ `LessonListPresenter.wireframe` phải strong (đã sửa; test đơn vị không bắt được). Hàng danh sách là một phần tử a11y (button). Từ vựng **không** link DictionaryEntry vì lesson không có ID từ điển (không ghép ID từ text). Nút Luyện tập hiện số hoạt động nhưng tắt đến K-04. Chưa kiểm VoiceOver thực, Dynamic Type lớn, ja/en. Nội dung server có token máy ("senior-junior") trong câu — thuộc content gate. |
| K-04 | VERIFIED (local commit) | integration | `5a0eb80` | **RED thật:** 11 fail / 13 pass (store + presenter trên skeleton rỗng; các test nâng cấp schema đã xanh vì thay đổi cộng thêm) → GREEN 34/34 (store, presenter, RealmServiceTests gồm **nâng cấp schema 6→7 từ file schema-6 thật** giữ deck/card/attempt và mở lại không cần migrate thêm), rồi 46/46 sau khi nối Reader. Full `FlashcardAppTests` **1349 PASS / 0 FAIL**. XCUITest `testGuestCanPractiseALessonToTheEnd` + `testLevelScreenOpensItsLessonsGroupedByWeek` PASS. Ảnh chụp thật: câu hỏi, và sau khi chọn sai: ✗ + lý do cho đáp án đã chọn, ✓ + lý do cho đáp án đúng, phần giải thích. | `RLessonProgress` (schema 7, theo `ownerKey` như review history; guest và từng tài khoản tách biệt, không gộp). `completedAt` (xong trên máy) tách khỏi `serverConfirmedAt` (server đã xác nhận). Chọn một lần, lưu trước khi hiện kết quả; lỗi lưu ⇒ không hiện đã trả lời. Server PUT: chỉ khi đăng nhập, **một lần** sau khi hoàn thành, không tự gửi lại; mở lại bài đã xong chỉ hiện nút "Lưu vào tài khoản"; `.interrupted` = "chưa rõ"; kết quả đến sau khi đổi tài khoản bị bỏ. **NOT VERIFIED:** PUT với server thật (không gọi PUT production; chưa có tài khoản/backend test), luồng signed-in trên UI, VoiceOver, Dynamic Type lớn, ja/en. Giao diện luyện tập chưa có test ảnh chụp tổng kết (summary) trên máy. |
| K-05 | VERIFIED (local commit) | integration | xem `git log --grep K-05` | **RED thật:** 13 fail / 14 pass (saver + reader presenter trên skeleton) → GREEN 47/47 (LessonWordSaver, Reader, Localization, DictionaryDeckWriter). Full `FlashcardAppTests` **1364/1364 PASS** (lần chạy full đầu có 9 fail ở `MailLoginPresenterTests`, chạy riêng 26/26 PASS và full chạy lại sạch ⇒ flaky không liên quan; trước đó có 1 flaky khác ở `DictionaryHandwritingPresenterTests`). XCUITest `testLessonWordsCanBeSavedToADeckTheLearnerPicks` PASS: hỏi bộ thẻ, lưu, lưu lại báo "đã có sẵn". | Từ trong bài **không có ID từ điển** ⇒ thẻ có id xác định `lesson:<deck>:<slug>:<từ tiếng Nhật>` (không phải UUID bịa); mặt trước = từ, extra = reading, mặt sau = `meaningVi`; thiếu nghĩa/từ ⇒ bỏ qua, không tạo thẻ một mặt; trùng theo id hoặc cùng chữ với thẻ tự gõ/từ vựng từ điển (kanji/ngữ pháp cùng chữ vẫn là thẻ khác); không tự tạo bộ; lưu một lần ghi trong một transaction. Chọn từng từ: vuốt trái hoặc hành động VoiceOver "Lưu vào bộ thẻ"; hoặc "Lưu tất cả". **NOT VERIFIED:** Today nhận số liệu mới sau khi quay lại (chưa kiểm), ảnh chụp hộp chọn bộ thẻ (action sheet) bằng mắt (chỉ XCUITest), VoiceOver thật. |
| K-06 … K-18 | PLANNED / DEFERRED / BLOCKED theo roadmap | — | — | — | K-06 NEXT. |

## Content gate (chất lượng nội dung bài học) — **MỞ**

Chưa có người đánh giá độc lập độ chính xác ngữ pháp, mức tự nhiên công sở, tiếng Việt, đáp án/rationale của J5/J4/J3/J2/J1. K-01 chỉ chứng minh decode đúng (84/84 bài J5, 516/516 activity nhất quán); J4–J1 chưa kiểm đếm. Reader K-03/K-04 chỉ hiển thị nguyên văn server, **không** thay thế đánh giá này; không quảng bá 420 bài trước khi qua gate.

## Reviewer findings

| Story | Nguồn | Mức | Finding | Xử lý |
| --- | --- | --- | --- | --- |
| K-01 | Codex gpt-6-sol/high (read-only) | HIGH | `BJTLessonDTO.swift:128`: `activities` vắng/null được decode thành `[]` (phải `invalidResponse`), thiếu test | Coordinator sửa + test ở worktree `kiokoto-ios-codex-review`, nhánh `fix/k01-activities`; **Đã tích hợp: cherry-pick `721a76e` → `31c1504`.** Integrator không sửa `BJTLessonDTO.swift`/`BJTLessonAPITests.swift` |
| K-01 | Codex | MEDIUM | status.md thiếu hash + xcresult | Đã bổ sung (commit `5ee8189`) |

## Evidence (xcresult, `~/Library/Developer/XcodeBuildMCP/workspaces/kiokoto-ios-integration-8d8a7a6ddc82/result-bundles/`)

Thiết bị: iPhone 17 Pro iOS 26.4 (`5483C259-8877-4502-B6E2-1AD05ABA9AC5`), scheme FlashcardApp-Local, 2026-11-11 (UTC).

| Story | Lần chạy | Kết quả | xcresult |
| --- | --- | --- | --- |
| K-01 `af05f0e` | `BJTLessonAPITests` | 16/16 PASS | `test_sim_2026-11-11T03-08-44-619Z_pid40304_1354f6ad.xcresult` |
| K-02 `d3d991f` | RED `LessonListPresenterTests` (skeleton rỗng) | 8/8 FAIL (hành vi) | `test_sim_2026-11-11T03-13-56-180Z_pid40304_755912e1.xcresult` |
| K-02 | RED `HomePresenterTests/testLessonsAreOffered…` | FAIL | `test_sim_2026-11-11T03-16-11-454Z_pid40304_16fe3ac3.xcresult` |
| K-02 | GREEN LessonList + Home + Localization + BJTLesson | 51/51 PASS | `test_sim_2026-11-11T03-17-49-991Z_pid40304_ce6c3a1e.xcresult` |
| K-02 | Full `FlashcardAppTests` | 1302 PASS / 0 FAIL | `test_sim_2026-11-11T03-22-05-643Z_pid40304_79340e85.xcresult` |
| K-02 | XCUITest `testLevelScreenOpensItsLessonsGroupedByWeek` (qua proxy chỉ-GET) | PASS | `test_sim_2026-11-11T03-24-13-625Z_pid40304_1df582b6.xcresult` |
| K-01 fix | Coordinator RED→GREEN (`721a76e`, sim iPhone 17e) | RED 16 pass/1 fail → GREEN 17/17 | `/private/tmp/claude-501/k01fix-red.xcresult`, `/private/tmp/claude-501/k01fix-green.xcresult` |
| K-01 fix | Integrator chạy lại sau cherry-pick `31c1504` (kèm K-03 chưa commit) | 46/46 PASS | `test_sim_2026-11-11T03-47-44-735Z_pid40304_210e7b21.xcresult` |
| K-03 | RED (skeleton rỗng) | 21 FAIL / 8 pass | `test_sim_2026-11-11T03-43-28-638Z_pid40304_a6c33140.xcresult` |
| K-03 | GREEN lần đầu (55 test gồm Localization) | 55/55 PASS | `test_sim_2026-11-11T03-46-23-545Z_pid40304_92494727.xcresult` |
| K-03 | XCUITest `testLevelScreenOpensItsLessonsGroupedByWeek` (đã mở reader) | PASS | `test_sim_2026-11-11T03-57-46-048Z_pid40304_e4093270.xcresult` |
| K-03 | Full `FlashcardAppTests` | 1323 PASS / 1 FAIL (flaky, không liên quan) | `test_sim_2026-11-11T03-58-58-557Z_pid40304_e64cfb67.xcresult` |
| K-03 | `DictionaryHandwritingPresenterTests` chạy riêng | 9/9 PASS | `test_sim_2026-11-11T04-00-44-545Z_pid40304_18373265.xcresult` |
| K-04 | RED (skeleton rỗng) store + presenter + Realm | 11 FAIL / 13 pass | `test_sim_2026-11-11T04-08-59-534Z_pid40304_0d185374.xcresult` |
| K-04 | GREEN store + presenter + RealmServiceTests | 34/34 PASS | `test_sim_2026-11-11T04-10-54-372Z_pid40304_4ca75639.xcresult` |
| K-04 | GREEN Reader/Practice/List/Localization | 46/46 PASS | `test_sim_2026-11-11T04-13-10-729Z_pid40304_fa6667d1.xcresult` |
| K-04 | XCUITest practise to the end + lessons list | 2/2 PASS | `test_sim_2026-11-11T04-14-14-725Z_pid40304_d7c2768b.xcresult` |
| K-04 | Full `FlashcardAppTests` | 1349 PASS / 0 FAIL | `test_sim_2026-11-11T04-18-39-394Z_pid40304_91f600fb.xcresult` |
| K-05 | RED (skeleton) saver + reader | 13 FAIL / 14 pass | `test_sim_2026-11-11T04-22-01-700Z_pid40304_c4ff50b5.xcresult` |
| K-05 | GREEN saver + reader + Localization + DictionaryDeckWriter | 47/47 PASS | `test_sim_2026-11-11T04-24-08-360Z_pid40304_37da80d8.xcresult` |
| K-05 | XCUITest lưu từ vào bộ thẻ | PASS | `test_sim_2026-11-11T04-25-20-638Z_pid40304_b46c54ba.xcresult` |
| K-05 | Full `FlashcardAppTests` lần 1 (flaky MailLogin) | 1355 PASS / 9 FAIL | `test_sim_2026-11-11T04-26-41-097Z_pid40304_f24de74d.xcresult` |
| K-05 | `MailLoginPresenterTests` chạy riêng | 26/26 PASS | `test_sim_2026-11-11T04-28-18-805Z_pid40304_b142a3dc.xcresult` |
| K-05 | Full `FlashcardAppTests` lần 2 | 1364/1364 PASS | `test_sim_2026-11-11T04-29-04-179Z_pid40304_ed331d56.xcresult` |
