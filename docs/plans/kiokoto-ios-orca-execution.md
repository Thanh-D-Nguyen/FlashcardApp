# Kiokoto iOS — Orca multi-agent execution playbook

**Ngày:** 2026-11-11. **Trạng thái:** ready to hand off; **chưa launch worker hoặc triển khai iOS** qua playbook này.

**Nguồn đặc tả:** [Kiokoto iOS product roadmap](kiokoto-ios-product-roadmap-2026-11-11.md) (K-01…K-18). File này là **điểm vào duy nhất** cho một prompt ngắn trong Orca. Yêu cầu của chủ dự án cho phép **triển khai liên tục toàn bộ phần local khả thi** theo dependency, kiểm thử, review và commit **local** từng checkpoint mà không cần xin phép lại mỗi story. Không đồng nghĩa có quyền push, merge vào `main`, deploy, phát hành, sửa backend/production, credential hoặc dữ liệu tài khoản thực.

## 1. Kết quả cần bàn giao

1. Đưa ứng dụng từ `Today → cấp độ → lesson → activities → lưu từ → Today` đến một vertical slice chạy được, ưu tiên K-01→K-06; giữ navigation và review hiện có.
2. Triển khai tiếp các story **có điều kiện khả thi** K-07…K-18 theo bảng dependency của roadmap; tránh thêm tính năng phụ khi vertical slice chưa được xác minh. Story nào thiếu bằng chứng hoặc có blocker rõ ràng thì ghi `BLOCKED` + điều kiện mở, và tiếp tục story không phụ thuộc.
3. Mỗi story có code + relevant tests/UI/build evidence, diff review, một commit local, cập nhật trạng thái và hash; những test không chạy được ghi `NOT VERIFIED`, không mô tả thành PASS.
4. Bàn giao branch tích hợp **chưa push**, danh sách story `DONE / BLOCKED / NOT VERIFIED`, bằng chứng thực và các bước cần quyền/thiết bị thật.

## 2. Vai trò, model cố định

| Vai trò | Agent | Model / effort | Quyền sửa |
| --- | --- | --- | --- |
| Coordinator | phiên Orca nhận prompt | Điều phối, kiểm tra checkpoint, chọn story và chống xung đột | Không thực hiện coding song song trên checkout của worker |
| Integration owner | **Claude Code** | **Claude Sonnet 5.5**, `--model claude-sonnet-5-5 --effort medium` (**Normal ≈ medium**, mapping effort cần xác nhận ở runtime) | Một worktree tích hợp; toàn quyền đối với file dùng chung |
| Independent implementer / reviewer | **Codex** | **`gpt-6-sol` / `high`**, bắt buộc truyền `--model gpt-6-sol --effort high` | Worktree riêng; implement story được giao hoặc review **read-only** trên commit đã ổn định |

**Model preflight:** Orca CLI hiện hỗ trợ `--model` và `--effort` cho `worktree create`/`agent launch`. Codex local cache ngày 2026-11-11 liệt kê `gpt-6-sol` với effort `high`, **chưa chứng minh launch thành công cho account hiện tại**. Claude CLI nhận full model ID và effort `medium`; **ID `claude-sonnet-5-5` chưa được xác thực qua provider**. Trước khi giao việc phải kiểm tra launch receipt và model thực tế. Nếu version Sonnet 5.5 hoặc Codex ID không khả dụng, ghi `MODEL_BLOCKED` và báo rõ; **không fallback âm thầm** sang `sonnet`, `fable`, model mặc định hoặc effort khác. Không đổi model chỉ để vượt gate.

## 3. Bắt đầu từ đúng code và bảo vệ thay đổi

- Repository: `/Users/thanhnguyen/Documents/Develop/FlashcardApp`; baseline đang là local `main` tại thời điểm chạy. Có các file modified/untracked của tác vụ khác. Đọc `git status --short --branch` và `git log -1 --oneline`; **không** reset/clean/stash/stage/commit file khác. Tránh làm việc trong checkout `main` đang bẩn.
- Hai tài liệu `kiokoto-ios-product-roadmap-2026-11-11.md` và **file này** phải nằm trong **commit local** trên `main` trước khi mở worktree; file chỉ untracked trong `main` sẽ **không** hiện ở worker checkout. Nếu chưa có trong lịch sử, coordinator tạo một commit docs chỉ chứa đúng hai file, sau khi xem staged diff; không cần commit cả working tree. Nếu commit docs gặp xung đột, giữ file nguyên vẹn và báo blocker thay vì dùng worktree thiếu plan.
- Đọc `AGENTS.md`, `docs/ENGINEERING_GUARDRAILS.md`, `docs/AI_WORKFLOW.md`, `.claude/skills/flashcard-delivery/SKILL.md`. Khi chạm API đọc thêm `flashcard-api-contract`, khi chạm release đọc thêm release skill. Ưu tiên CodeGraph cho câu hỏi cấu trúc khi index hoạt động. Không thay stack UIKit/VIPER, RxSwift, Alamofire, Realm hay 5 tab.
- Tạo **một** worktree integration từ **local `main`** bằng Orca và branch riêng; `--base-branch main` để lấy toàn bộ commit local, kể cả docs; tránh base remote `origin/main`. Nếu Orca không quản lý repo hiện tại, xác nhận repo selector của đúng đường dẫn trước khi tạo; không tự chọn một repo cùng tên.

## 4. Khởi tạo worker bằng Orca CLI

Chạy từ repository root, sau model preflight. Các lệnh sau là mẫu thực thi (thay tên worktree đã tồn tại bằng tên mới, đọc JSON receipt và branch thực từ response):

```bash
orca worktree create \
  --name kiokoto-ios-integration --no-parent --base-branch main \
  --agent claude --model claude-sonnet-5-5 --effort medium \
  --prompt 'Bạn là integration owner. Đọc docs/plans/kiokoto-ios-orca-execution.md và roadmap liên quan. Bắt đầu K-01, triển khai và commit local theo các gate; ghi status/evidence và gửi checkpoint cho coordinator. Không push/merge/deploy.' \
  --json
```

Codex **phải** chạy trong worktree **khác**. Sau khi Claude commit một checkpoint, lấy **branch/hash thật** từ output của Orca/Git rồi tạo worktree Codex từ branch đó (thay `<integration-branch>`); review có thể chạy read-only, hoặc implement story độc lập với file ownership rõ:

```bash
orca worktree create \
  --name kiokoto-ios-codex-review --no-parent --base-branch '<integration-branch>' \
  --agent codex --model gpt-6-sol --effort high \
  --prompt 'Đọc docs/plans/kiokoto-ios-orca-execution.md. Review READ-ONLY checkpoint tích hợp vừa commit theo acceptance, rủi ro dữ liệu/auth và test evidence; trả findings severity + file:line. Không sửa file, push hoặc merge.' \
  --json
```

- Sau checkpoint đầu có thể tái sử dụng terminal/worktree qua `orca agent launch --agent codex --worktree <selector> --model gpt-6-sol --effort high --prompt '...' --json`, hoặc tạo review worktree mới từ commit mới. Không mặc định reviewer hiện tại có code mới chỉ vì integrator vừa commit; phải đồng bộ **local** branch/checkout và xác minh SHA trước khi review.
- Chỉ tạo worker thực sự cần cho checkpoint. Nếu một story tách được độc lập (VD: kiểm API distractors, read-only source audit, test fixture), Codex có thể implement trong **branch riêng**, trên phạm vi file ghi rõ; integrator review rồi tích hợp commit local. Khi cùng cần `project.pbxproj`, `Localizable.xcstrings`, Realm schema/migration, storyboard, Today, navigation, integration owner giữ độc quyền các file đó. Không để hai worker sửa cùng một checkout hoặc cùng một file.
- Theo dõi launch receipt: kết quả có handle, mode và trạng thái giao prompt; failure phải kiểm tra worktree/session trước khi retry, dùng `--retry-launch <operationId>` nếu CLI trả operation ID. Không nhân đôi worktree/agent sau timeout.

## 5. Vòng thực thi không dừng giữa các story khả thi

**Wave A — MVP:** K-01 → K-02 → K-03 → K-04 → K-05 → K-06. Mỗi bước: đọc current source/contract, xác nhận AC, TDD (RED thật → GREEN), build/test liên quan, check UI trên **một iPhone Simulator** khi có UI, review, commit local, ghi evidence. Reviewer Codex kiểm tra checkpoint quan trọng (K-01 API contract; K-04 Realm/auth; K-06 complete flow). Coordinator không cho story kế tiếp phụ thuộc một story chưa đạt gate; vẫn có thể chuyển đến phần độc lập.

**Wave B — review:** K-07 (distractor/choice; **đáp đúng không tự chấm Good**) → K-08 (lapse queue theo dữ liệu thực). Codex có thể nhận một story implementation độc lập sau checkpoint của Claude, **nếu** scope file không giao nhau; nếu không, Claude thực hiện tuần tự và Codex review.

**Wave C — mở rộng có kiểm soát:** K-09, K-10, K-11, K-12, rồi K-13…K-18 theo dependency/gate trong roadmap. Ưu tiên tính năng dùng được và xác minh trên máy thay vì hoàn thành đủ số story. K-11 chỉ phát analytics khi đã có privacy/consent phù hợp và API contract; K-13 chỉ khi có **kết luận quyền dùng nội dung bằng văn bản**; K-17 nếu API export thực sự hoàn tất; K-18 chỉ khi backend có idempotency/identity contract và được giao scope backend riêng. Nếu không đủ điều kiện, ghi `BLOCKED` chính xác, **không tự tạo giả data hoặc bỏ qua gate**. K-14 yêu cầu device/mic có thể `NOT VERIFIED` nếu chỉ chạy simulator.

**Giới hạn mutation:** GET production công khai read-only được phép cho contract. Không gọi PUT/POST production để thử, không dùng tài khoản thật làm dữ liệu thử, không cập nhật shared backend, DNS, App Store, analytics production hoặc push code. Local test backend chỉ được ghi vào dữ liệu test biệt lập, không xóa/migrate dữ liệu đang sử dụng; nếu không có test backend an toàn thì dùng fixtures và ghi rõ integration chưa kiểm.

## 6. Quality gate và chính sách dừng

1. Story có fixture/payload **lấy từ source hoặc runtime thực** (redacted), error states, cancellation, stale auth, session ownership. Không invent API/lesson IDs/reading/furigana. Nếu contract thiếu, tách phần độc lập; phần còn lại ghi `BLOCKED`.
2. Giữ nguyên Realm data khi migration; test upgrade fixture từ schema cũ và reopen, không reset DB để chữa lỗi. Không cộng local FSRS và server review thành một lịch, không tự retry mutation không idempotent.
3. Vi/en/ja dùng `Localizable.xcstrings`; build/test scheme local và file membership; verify màn UI trên một Simulator; bảo toàn privacy/accessibility. Không giả PASS từ code inspection. Review Codex không thay thế XCTest/UI runtime.
4. Sau mỗi story: verify `git status`, diff (kể cả staged), secret check, run focused tests, commit theo kiểu `feat:`/`fix:`/`test:` hoặc `docs:` với **chỉ** file story; cập nhật roadmap trong cùng checkpoint/commit khi có thể. Thêm commit hash vào entry sau commit bằng một commit docs bổ sung nếu cần, không rewrite history chỉ để cập nhật hash.
5. **Chỉ dừng hẳn** khi mọi story được phân loại `DONE / BLOCKED / NOT VERIFIED` và các phần local khả thi đã hoàn thành, hoặc có blocker hạ tầng/model nghiêm trọng không còn đường local an toàn. Không hỏi lại quyền cho story đã được ủy quyền; không bypass blocker để tuyên bố đủ 18/18.

## 7. Checkpoint bền vững / resume sau compaction

- Integration owner duy trì `docs/plans/kiokoto-ios-orca-status.md` **trong branch tích hợp** (tạo khi bắt đầu wave): bảng `Story | State | Owner | Commit | Test/build/UI evidence | Blocker/Next`; kèm `lastKnownGoodCommit`, branch, worktree thực, reviewer finding, story kế tiếp và file đang do ai sở hữu. Không ghi token hoặc PII trong log/docs.
- Sau mỗi checkpoint, coordinator đọc trạng thái từ **repo và Orca**, so với commit thực, không chỉ tin câu trả lời của worker. Nếu context hết hoặc agent đứt, prompt tiếp theo là: `Tiếp tục docs/plans/kiokoto-ios-orca-execution.md dựa vào docs/plans/kiokoto-ios-orca-status.md và trạng thái worktree thực; không làm lại story DONE.`
- Nếu worker/crash hoặc test infrastructure lỗi, giữ branch + commit; ghi error thực và phục hồi theo lệnh CLI được hỗ trợ. Nếu gặp commit xung đột, ưu tiên integration owner sửa, chạy lại relevant tests. Không cherry-pick mù hoặc `git reset --hard` vào shared worktree.
- Báo cáo cuối bằng tiếng Việt: nhánh/hash commit, story thật sự DONE, chưa đạt, đường dẫn bằng chứng, các lệnh kiểm thử đã chạy, các gate App Store/backend/thiết bị còn mở; **không** đẩy lên remote.
