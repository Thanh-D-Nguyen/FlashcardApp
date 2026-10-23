# Quy trình AI cho FlashcardApp

Quyết định ngày 2026-10-23: dùng **quy trình lấy ý tưởng từ BMAD cho dự án có sẵn,
kết hợp TDD bằng XCTest**. Đây là adaptation riêng của repo, không phải bản cài
BMAD chính thức và không cung cấp các lệnh `bmad-*` của upstream.

## Vì sao chọn cách này

| Phương án | Đánh giá cho app hiện tại |
| --- | --- |
| TDD đơn lẻ | Đã có trong project; tốt cho logic nhưng chưa giải quyết việc chia mục tiêu sản phẩm, thứ tự story và bằng chứng bàn giao. |
| Cài bộ BMAD đầy đủ | Có công cụ lập kế hoạch và delivery; cần duy trì thêm runtime, cấu hình, tài liệu và agent trùng với repo. Chưa cần cho phạm vi này. |
| Áp dụng vòng plan → story → TDD → review → verify → commit | Chọn: bổ sung phần tổ chức công việc còn thiếu, tái sử dụng UIKit/VIPER, XCTest và ba agent chuyên dự án. |

Tài liệu upstream được đối chiếu ngày 2026-10-23:
- [BMAD cho codebase có sẵn](https://docs.bmad-method.org/existing-codebases/start-in-an-existing-codebase/): dùng context của repo và chia thay đổi lớn thành phần nhỏ.
- [Build a Change](https://docs.bmad-method.org/build/build-a-change/): điều tra, lập kế hoạch, triển khai và review theo phạm vi thay đổi.
- [Cài BMAD](https://docs.bmad-method.org/start/install-bmad/): tại thời điểm đọc,
  trang ghi v6.12 ổn định và v7 preview alpha. Không lấy ETA trên trang làm bằng
  chứng đã phát hành, không cài `latest` hoặc giả định API/command hai bản giống nhau.
- [TDD — Martin Fowler](https://martinfowler.com/bliki/TestDrivenDevelopment.html):
  chọn test case, RED → GREEN → refactor. TDD là kỹ thuật phát triển, không phải runtime AI.

Không copy mã upstream, không thêm package vào app, không sửa cấu hình AI toàn máy.
Muốn dùng chính thức một bản BMAD sau này thì đánh giá riêng version, module,
installer diff và quyền chạy; không tự cập nhật workflow trong lúc làm feature.

## Điểm vào duy nhất

Skill chuẩn: [flashcard-delivery](../.claude/skills/flashcard-delivery/SKILL.md).
Codex tìm thấy cùng skill qua symlink `.agents/skills/flashcard-delivery`;
Claude/Xcode đọc `.claude/skills` và `AGENTS.md`. Không duy trì hai bản nội dung.
Nếu client chưa refresh skill mới, yêu cầu đọc trực tiếp đường dẫn chuẩn.

Ví dụ yêu cầu:

> Dùng flashcard-delivery để triển khai L01 trong docs/plans/personalized-learning.md.
> Giữ phạm vi L01, chạy RED/GREEN và kiểm tra liên quan, review rồi commit local.

> Dùng flashcard-delivery để lập kế hoạch cho bài nghe; chưa sửa app.

Một lỗi nhỏ không cần PRD mới. Một thay đổi nhiều lớp có một plan sống trong
`docs/plans/`, chia story và cập nhật bằng chứng tại đó. Không bắt đầu cả roadmap
khi người dùng chỉ giao một story, không hỏi lại quyền đã được cấp trong chat.

## Vai trò và nguồn quy tắc

- Agent chính giữ mục tiêu, scope, tích hợp, verification và commit.
- `flashcard-architect`: thiết kế thay đổi nhiều lớp/identity/migration.
- `flashcard-reviewer`: review độc lập diff theo acceptance và rủi ro cụ thể.
- `flashcard-verifier`: kiểm chứng hoặc chẩn đoán build/test, không tự sửa contract.
- `.claude/skills/flashcard-feature`, `flashcard-api-contract`, `flashcard-release`
  tiếp tục sở hữu cách triển khai trong từng mảng; không tạo thêm stack agent trùng lặp.

`AGENTS.md` và [engineering guardrails](ENGINEERING_GUARDRAILS.md) vẫn là nguồn
chính cho kiến trúc, dữ liệu, kiểm thử và giới hạn external action. Workflow mới
không nới các quy tắc đó. Hướng dẫn trong skill bổ sung cách giao việc và bằng chứng.

## Áp dụng đầu tiên

[Kế hoạch học cá nhân hóa](plans/personalized-learning.md) là đầu ra đầu tiên:
7 story có dependency, acceptance, ranh giới dữ liệu và commit dự kiến. Tất cả
L01–L07 đang PLANNED. Việc thiết lập workflow không đồng nghĩa đã thêm SRS/Today.

Checkpoint `99e4c8b` đã có build + 22 XCTest và 18 ca kiểm tra môi trường;
chi tiết/phần chưa kiểm chứng nằm cuối kế hoạch. Đây là kiểm chứng trạng thái có sẵn,
không phải bằng chứng RED/GREEN của một tính năng mới.

## Kiểm chứng workflow ngày 2026-10-23

- Kế hoạch được review kiến trúc độc lập, không có blocker; lưu ở `f05971c`.
- `quick_validate.py`: PASS cho skill delivery ở cả đường dẫn chuẩn và alias,
  và cho skill feature được cập nhật.
- 7 Markdown link local resolve; symlink Codex trỏ đúng một bản skill chuẩn;
  `CLAUDE.md` vẫn đọc `AGENTS.md`; 11 đường dẫn skill/agent/source tham chiếu tồn tại.
- Review độc lập và mô phỏng bốn yêu cầu: bug double tap có commit, chỉ lập kế hoạch
  Realm, sửa spacing Home, triển khai L02 khi server tắt. Không có finding còn mở;
  quyết định giữ scope và chọn mức kiểm chứng đúng cho từng trường hợp.
- Đây là kiểm tra quyết định trên tài liệu, không phải chạy bốn tính năng thật.
  Chưa kiểm chứng client tự refresh discovery trong một phiên Codex/Xcode mới.
- Không chạy lại app tests cho diff chỉ gồm hướng dẫn/Markdown/symlink. Bằng chứng
  app checkpoint vẫn tách riêng ở kế hoạch; không dùng để chứng nhận tính năng mới.
