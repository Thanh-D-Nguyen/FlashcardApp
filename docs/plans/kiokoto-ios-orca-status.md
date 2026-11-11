# Kiokoto iOS — Orca status

Nguồn: [playbook](kiokoto-ios-orca-execution.md), [roadmap](kiokoto-ios-product-roadmap-2026-11-11.md).
Branch tích hợp: `Thanh-D-Nguyen/kiokoto-ios-integration` (chưa push). Worktree: `/Users/thanhnguyen/orca/workspaces/FlashcardApp/kiokoto-ios-integration`.
Model thực tế của phiên này: Sonnet 5.5 (`claude-sonnet-5-5`) — chưa có launch receipt từ Orca để đối chiếu effort.

lastKnownGoodCommit: `d66c631` (baseline docs) → xem commit K-01 trong `git log`.
Story kế tiếp: **K-03**. File đang do integration owner giữ: `project.pbxproj`, `Localizable.xcstrings`.

| Story | State | Owner | Commit | Test/build/UI evidence | Blocker/Next |
| --- | --- | --- | --- | --- | --- |
| K-01 | VERIFIED (local commit) | integration | xem `git log --grep K-01` | `BJTLessonAPITests` 16/16 PASS (XcodeBuildMCP `test_sim`, scheme FlashcardApp-Local, iPhone 17 Pro iOS 26.4, 2026-11-11); app + test target build qua test. Fixture từ GET production ẩn danh; 516/516 activity thật thoả điều kiện answer. Không có UI → không có kiểm Simulator UI. | PUT progress chỉ xác minh theo source backend, **NOT VERIFIED** với server thật. GET ẩn danh luôn `isCompleted=false`. Reviewer Codex chưa chạy (**review độc lập chưa có**). Chưa chạy toàn bộ test suite. RED hành vi: không có (test và code viết cùng lượt). |
| K-02 | VERIFIED (local commit) | integration | xem `git log --grep K-02` | **RED thật:** `LessonListPresenterTests` 8/8 fail trên skeleton rỗng (vd. `idle` ≠ `empty`, sections rỗng) và `HomePresenterTests/testLessonsAreOffered…` fail (`nil` ≠ `J5`) — rồi cài đặt → **GREEN**: 51/51 (LessonList + Home + Localization + BJTLesson). Full `FlashcardAppTests` 1302 pass / 0 fail. XCUITest `testLevelScreenOpensItsLessonsGroupedByWeek` PASS. Simulator iPhone 17 Pro iOS 26.4, cỡ chữ mặc định, ngôn ngữ en: ảnh chụp danh sách Tuần 1 thật và trạng thái offline+Retry. | Backend local không chạy → UI chạy qua proxy **chỉ-GET** localhost:18081→kiokoto.com (PUT bị chặn 405). Hàng bài chưa bấm được (K-03). Chưa kiểm VoiceOver/Dynamic Type lớn. Không hiện `isCompleted` (GET ẩn danh luôn false). Tiêu đề bài là tiếng Việt khi app en (API không có tiếng Anh). |
| K-03 … K-18 | PLANNED / DEFERRED / BLOCKED theo roadmap | — | — | — | K-03 NEXT (phụ thuộc content gate chưa làm). |
