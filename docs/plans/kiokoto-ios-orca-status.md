# Kiokoto iOS — Orca status

Nguồn: [playbook](kiokoto-ios-orca-execution.md), [roadmap](kiokoto-ios-product-roadmap-2026-11-11.md).
Branch tích hợp: `Thanh-D-Nguyen/kiokoto-ios-integration` (chưa push). Worktree: `/Users/thanhnguyen/orca/workspaces/FlashcardApp/kiokoto-ios-integration`.
Model thực tế của phiên này: Sonnet 5.5 (`claude-sonnet-5-5`) — chưa có launch receipt từ Orca để đối chiếu effort.

lastKnownGoodCommit: `d3d991f` (K-02) trên `af05f0e` (K-01), baseline `d66c631`.
Story đang làm: **K-03**. File đang do integration owner giữ: `project.pbxproj`, `Localizable.xcstrings`.

| Story | State | Owner | Commit | Test/build/UI evidence | Blocker/Next |
| --- | --- | --- | --- | --- | --- |
| K-01 | VERIFIED (local commit) | integration | `af05f0e` | `BJTLessonAPITests` 16/16 PASS (XcodeBuildMCP `test_sim`, scheme FlashcardApp-Local, iPhone 17 Pro iOS 26.4, 2026-11-11); app + test target build qua test. Fixture từ GET production ẩn danh; 516/516 activity thật thoả điều kiện answer. Không có UI → không có kiểm Simulator UI. | PUT progress chỉ xác minh theo source backend, **NOT VERIFIED** với server thật. GET ẩn danh luôn `isCompleted=false`. Reviewer Codex chưa chạy (**review độc lập chưa có**). Chưa chạy toàn bộ test suite. RED hành vi: không có (test và code viết cùng lượt). |
| K-02 | VERIFIED (local commit) | integration | `d3d991f` | **RED thật:** `LessonListPresenterTests` 8/8 fail trên skeleton rỗng (vd. `idle` ≠ `empty`, sections rỗng) và `HomePresenterTests/testLessonsAreOffered…` fail (`nil` ≠ `J5`) — rồi cài đặt → **GREEN**: 51/51 (LessonList + Home + Localization + BJTLesson). Full `FlashcardAppTests` 1302 pass / 0 fail. XCUITest `testLevelScreenOpensItsLessonsGroupedByWeek` PASS. Simulator iPhone 17 Pro iOS 26.4, cỡ chữ mặc định, ngôn ngữ en: ảnh chụp danh sách Tuần 1 thật và trạng thái offline+Retry. | Backend local không chạy → UI chạy qua proxy **chỉ-GET** localhost:18081→kiokoto.com (PUT bị chặn 405). Hàng bài chưa bấm được (K-03). Chưa kiểm VoiceOver/Dynamic Type lớn. Không hiện `isCompleted` (GET ẩn danh luôn false). Tiêu đề bài là tiếng Việt khi app en (API không có tiếng Anh). |
| K-03 … K-18 | PLANNED / DEFERRED / BLOCKED theo roadmap | — | — | — | K-03 NEXT (phụ thuộc content gate chưa làm). |

## Content gate (chất lượng nội dung bài học) — **MỞ**

Chưa có người đánh giá độc lập độ chính xác ngữ pháp, mức tự nhiên công sở, tiếng Việt, đáp án/rationale của J5/J4/J3/J2/J1. K-01 chỉ chứng minh decode đúng (84/84 bài J5, 516/516 activity nhất quán); J4–J1 chưa kiểm đếm. Reader K-03/K-04 chỉ hiển thị nguyên văn server, **không** thay thế đánh giá này; không quảng bá 420 bài trước khi qua gate.

## Reviewer findings

| Story | Nguồn | Mức | Finding | Xử lý |
| --- | --- | --- | --- | --- |
| K-01 | Codex gpt-6-sol/high (read-only) | HIGH | `BJTLessonDTO.swift:128`: `activities` vắng/null được decode thành `[]` (phải `invalidResponse`), thiếu test | Coordinator sửa + test ở worktree `kiokoto-ios-codex-review`, nhánh `fix/k01-activities`; integrator cherry-pick khi có hash. **Chưa tích hợp.** Integrator không sửa `BJTLessonDTO.swift`/`BJTLessonAPITests.swift` |
| K-01 | Codex | MEDIUM | status.md thiếu hash + xcresult | Đã bổ sung (mục dưới) |

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
