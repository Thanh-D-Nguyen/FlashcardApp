# Today — học tiếng Nhật từ cuộc sống (đề xuất sản phẩm và UX)

**Ngày:** 2026-10-23
**Trạng thái:** `PROPOSED / PLANNING ONLY` cho phần kế hoạch dưới đây. **Cập nhật 2026-10-24:** lát cắt P1 «今日の天気» đã được audit, thiết kế và triển khai cục bộ — xem [today-life-learning-weather-slice.md](today-life-learning-weather-slice.md). Nội dung bên dưới giữ nguyên làm ngữ cảnh sản phẩm; các ghi chú “chưa có route thời tiết” ở §3 phản ánh tình trạng *trước* lát cắt.
**Liên quan:** [personalized-learning.md](personalized-learning.md), [personalized-learning-ux.md](personalized-learning-ux.md), [personalized-learning-l06a-audit.md](personalized-learning-l06a-audit.md), [ENGINEERING_GUARDRAILS.md](../ENGINEERING_GUARDRAILS.md).

## 1. Quyết định sản phẩm

**Tầm nhìn:** Bất kỳ tình huống đời sống nào có nguồn đáng tin, quyền sử dụng phù hợp và giá trị học tập đều *có thể* trở thành bài học tiếng Nhật ngắn: thời tiết, đi tàu, mua sắm, chuyện nơi đang sống, tin tức, công việc, lịch sử địa phương, tài chính, Loto 6/7... Đây là định hướng mở rộng nội dung, **không phải cam kết tích hợp tất cả nguồn trong một phiên bản**.

**Lời hứa người học:** “Hiểu thêm một điều đang xảy ra quanh mình, học được cách diễn đạt bằng tiếng Nhật, và nhớ lại được điều đã học.” Chu trình bắt buộc:

`Sự kiện/sự vật thật → ngữ cảnh đã kiểm chứng → câu tiếng Nhật phù hợp trình độ → hiểu & tự trả lời → lưu kiến thức → ôn lại`.

Không biến Today thành mạng xã hội, ứng dụng xem tin hay dashboard tài chính. **Dữ liệu đời sống là đầu vào; khả năng học và ghi nhớ là đầu ra.** Bấm xem, cuộn tin, nghe audio hoặc lật thẻ không tính là “đã học thuộc”.

Đối tượng khởi đầu giữ nguyên giả thuyết hiện có: người Việt đang sống / chuẩn bị sống ở Nhật, khoảng N4–N3. Phân khúc và tác dụng cá nhân hóa chưa được kiểm chứng với người dùng thật.

## 2. Quy tắc không được phá vỡ

1. **Today vẫn là nơi bắt đầu phiên ôn đã lưu.** Giữ nguyên tab đầu, hero ôn deck và CTA theo trạng thái từ L05/U00; không giành vùng nhìn đầu bằng feed nội dung. Giữ các đường vào Dictionary, Cards, Settings, Levels.
2. **Khám phá tự chọn, không vô tận.** Bản đầu chỉ 1 đề xuất theo đời sống bên dưới khu vực ôn; có đường `Khám phá chủ đề` đến danh sách giới hạn. Không tự chạy carousel, video hoặc tự tải hàng chục feed.
3. **Mỗi mẩu nội dung phải dạy được điều gì đó.** Có câu tiếng Nhật, cách đọc/giải nghĩa, 1 hành động luyện nhớ có đáp án, và đường lưu về card/deck hiện có; nếu không đủ tiêu chuẩn thì không gắn nhãn “bài học”.
4. **Tách dữ kiện và diễn giải do AI tạo.** Giá, thời tiết, kết quả xổ số, sự kiện lịch sử phải gắn nguồn/thời điểm. AI chỉ đề xuất cách dạy hoặc ví dụ, không được tự tạo “sự kiện” rồi trình bày như tin thật.
5. **Độ tin cậy và quyền sử dụng là cổng phát hành.** Không mặc định có quyền sao chép, dịch hoặc phát lại nội dung/ảnh/audio của NHK hay nguồn khác chỉ vì server đã thu thập được. Tạo nội dung gốc hoặc deep link đến nguồn khi chưa có quyền tái sử dụng.
6. **Quyền riêng tư theo hành động.** Không hỏi vị trí khi mở Today; cho chọn khu vực thủ công. Chỉ xin quyền vị trí một lần khi người dùng bấm tìm hiểu nơi ở gần mình; từ chối vẫn dùng app bình thường, không theo dõi nền.
7. **Không thúc đẩy đầu cơ/cá cược.** Chứng khoán và Loto chỉ là ngữ cảnh dạy từ vựng, đọc số liệu, xác suất, tin tức đã công bố; không đưa khuyến nghị mua/bán, dự đoán số trúng hoặc liên kết đặt cược làm CTA.

## 3. Khả năng server hiện tại — chỉ là bằng chứng ở mức mã nguồn

Đã đối chiếu đăng ký route và handler trong `nihongo-bjt/apps/api-go/internal/httpserver` ngày 2026-10-23. **Route có trong source ≠ API đã kiểm runtime, dữ liệu có nội dung, hay quyền phân phối hợp lệ.**

| Nhóm | Bằng chứng đã thấy | Kết luận thiết kế |
| --- | --- | --- |
| Daily Radar | `GET /api/daily-radar/home`; handler lọc module/card `published` từ DB, có title, metadata, priority, target route | **Tái sử dụng trước** như kênh biên tập và discovery; phải kiểm response, nguồn, độ mới, quyền và destination từng card |
| Daily Home | `GET /api/daily/home`; tính `dueReviews` của tài khoản, nhưng trả `widgets: []`, `items: []` | Chưa dùng làm nguồn feed bài học; không đồng nhất lịch ôn server với Realm local trên iOS |
| Tin NHK | `GET /api/nhk-news`, `GET /api/nhk-news/{id}`; danh sách/chi tiết có ngày, tiêu đề, URL, body và dữ liệu từ vựng khi có | Chưa đủ xác nhận license cho in-app content và audio; kiểm riêng metadata, tính đúng và freshness |
| Magazine / Loto | `/api/magazine/today`, `/api/magazine/loto/feed`, `/next-draw`, `/stats` | Có hạ tầng nội dung; chưa xác minh kết quả, phép dùng data và giá trị học tiếng Nhật |
| Study plan | `/api/gamification/study-plan/today` | Có route, **không suy ra** đồng bộ được với lịch ôn local L05 |
| Tình huống | `/api/scenarios` và các route chi tiết/trả lời/hoàn thành | L06a đánh giá đủ điều kiện **dev text-only có điều kiện**, quyền nguồn/audio và nội dung vẫn là blocker phát hành |
| Weather, stocks, nearby/history/events | **Chưa xác nhận** route chuyên biệt đủ đáp ứng ứng dụng | Không thiết kế DTO/UI loading như thể API đã có; audit provider, giấy phép và response thực trước |

Các thay đổi `docs/openapi.json` và bản audit L06a ở backend/iOS hiện đang được agent khác sửa; không chỉnh hoặc phụ thuộc vào nội dung chưa được merge/verified. Mọi API dành cho iOS phải đi qua quy trình `flashcard-api-contract` và kiểm payload thật (ẩn dữ liệu nhạy cảm).

## 4. Kiến trúc trải nghiệm: Today tập trung, Discovery có chiều sâu

### 4.1 Today — giữ hero đã được duyệt

```text
┌ Hôm nay / 今日 ──────────────────────────────────┐
│ [HERO L05] Bạn có 8 thẻ cần ôn               │
│ Bộ thẻ: Giao tiếp công việc                  │
│ [Bắt đầu ôn]                                 │
│ [Bộ thẻ ▾] [3 / 5 / 10 phút ▾]               │
│ ─ Tiến độ hôm nay (chỉ số liệu đã lưu) ───────│
│                                                │
│ TỪ CUỘC SỐNG HÔM NAY                          │
│ [Thời tiết · chỉ khi nguồn có dữ liệu]         │
│ 今日の天気は？  Hôm nay thời tiết thế nào?      │
│ Bài học ~2 phút · N4 · nguồn và giờ cập nhật   │
│ [Học cách nói câu này →]                      │
│                                                │
│ Khám phá theo sở thích                  [Xem ›] │
│ Học theo cấp độ                             › │
└ Tab: Today | Dictionary | Cards | Settings ──┘
```

Nội dung minh họa ở wireframe **không phải dữ liệu server thật**. CTA học thời tiết là phụ so với CTA ôn trong hero. Không thêm tab thứ năm, floating action button hay một khối hình ảnh khổng lồ. Khi chưa có nội dung đạt gate, ẩn đề xuất và giữ nguyên L05.

### 4.2 Flow tương tác mới, tối đa ba bước học chính

`Today → Learning Story → Thử nhớ/áp dụng → Xong (lưu card nếu người dùng chọn) → Today`.

- **Learning Story:** tiêu đề đời sống, dữ kiện nguồn/ngày; câu Nhật + furigana khi cần + giải nghĩa vi/en; chọn đọc/nghe chỉ khi audio hợp lệ; 1–3 từ có thể lưu; xem nguồn gốc một chạm. Văn bản chính nhìn được trước khi mở các chi tiết.
- **Thử nhớ/áp dụng:** che một phần câu, cho người học chọn hoặc tự nhớ lại cách diễn đạt; có feedback giải thích chính xác *sau* trả lời, không tính `Next` là học thành công. Luyện 1–3 câu, không kéo thành một feed vô hạn.
- **Hoàn tất:** phân biệt rõ “đã làm bài”, “đã lưu card” và “đã ghi lượt ôn”. Chỉ xác nhận mỗi thao tác sau persistence thành công; lỗi lưu có retry rõ ràng, tránh ghi trùng.
- **Khám phá:** nhóm `Gần tôi` (opt-in), `Thời tiết & đời sống`, `Tin tức`, `Nơi chốn`, `Tiền bạc & số liệu`, `Sở thích`; chỉ nhóm có ít nhất một bài hợp lệ mới xuất hiện. Có bộ lọc quan tâm gọn; không bắt người dùng thiết lập khi onboarding.

### 4.3 Các trạng thái và thứ tự ưu tiên

| Tình huống | Ứng xử |
| --- | --- |
| Offline/API lỗi | Hero ôn local vẫn hoạt động; vùng khám phá báo thử lại riêng, không thay số thẻ cần ôn bằng 0 |
| Nguồn stale/hết hạn | Không giới thiệu là “hôm nay”; ẩn hoặc ghi ngày lịch sử rõ ràng |
| Không có bài phù hợp trình độ | Gợi ý xem chủ đề khác hoặc Levels; không tạo số liệu/học phần giả |
| Người dùng chưa login | Cho đọc bài công khai nếu server cho phép; lưu theo guest Realm nếu hành vi hỗ trợ; không ép đăng nhập |
| Không cho quyền vị trí | Cho tìm tỉnh/thành/quận thủ công, giữ lựa chọn trong phạm vi đã được người dùng cho phép |
| Người dùng lưu 2 lần/đổi màn nhanh | Không tạo hai thẻ hoặc hai attempt; chỉ dùng cơ chế idempotency thực sự có, kiểm riêng local/server |
| Tin đang thay đổi / dữ liệu tài chính | Thể hiện thời điểm và tính tạm thời; tránh câu hỏi có đáp án bị lỗi thời |

## 5. Content contract tối thiểu để không biến thành các module rời rạc

Đây là **schema khái niệm cho P0**, không phải DTO hay một endpoint đã tồn tại:

| Trường | Ý nghĩa / validation |
| --- | --- |
| `id`, `version`, `topic`, `level`, `locale` | Stable ID/version, loại chủ đề, trình độ Nhật, locale vi/en/ja; không dùng `hashValue` hoặc ID tạm theo vị trí |
| `sourceProvider`, `sourceUrl`, `sourcePublishedAt`, `fetchedAt`, `expiresAt` | Xuất xứ và độ mới; trường hợp dữ liệu nguyên gốc không có URL phải có mô tả nguồn đủ kiểm toán |
| `rightsStatus`, `reviewStatus` | `unknown / cleared / blocked`, `draft / reviewed / published`; thiếu quyền hoặc duyệt thì không publish |
| `factText`, `factAsOf`, `factualityStatus` | Dữ kiện gốc, thời điểm áp dụng, trạng thái đã xác minh; không coi bản dịch AI là bằng chứng |
| `japaneseText`, `reading`, `translations`, `vocabulary[]` | Nội dung ngôn ngữ kèm ngữ cảnh và cách đọc; kiểm từ đồng âm, số, tên riêng, kính ngữ |
| `exercise`, `answer`, `explanation`, `skillType` | Một bài có đáp án và giải thích; `skillType` phải phản ánh đúng nhận biết/nhớ lại/nghe/nói |
| `saveTarget`, `route`, `assetRights` | Đường dẫn UI đã kiểm, đích lưu hợp lệ, bản quyền ảnh/audio riêng khỏi bài viết |

**Đường dữ liệu ưu tiên:** existing provider/storage → biên tập/kiểm thực nguồn → tạo *learning story* → kiểm câu Nhật/độ khó/quyền → công bố qua Daily Radar nếu hợp contract → iOS hiển thị → học/lưu bằng các service hiện có. Một adapter mới chỉ khi P1 chứng minh thiếu. Không xây “universal AI ingestion engine”, agent đa cấp hay thêm database/search stack ngay ở P0.

Việc AI tạo *giải thích hoặc bài tập* phải được kiểm bằng bộ câu tình huống cố định; với nguồn động không thể duyệt toàn bộ biến thể bằng tay thì dùng giới hạn template + fact validation + kiểm thử mẫu và cơ chế ngừng phát hành khi lỗi.

## 6. Backlog theo lát cắt có thể nghiệm thu

| Ưu tiên | Story / kết quả bàn giao | Gate để chuyển bước |
| --- | --- | --- |
| **P0 (ngay)** | Chốt concept, content contract, inventory nguồn, 2 wireframe bố cục, prototype Today → Story → Practice → Save; mô phỏng ít nhất 6 trạng thái và 3 locale | Review sản phẩm và UX; không sửa code/DB; không xung đột L06 đang chạy |
| **P1** | Một nguồn đời sống có **quyền sử dụng rõ** và dữ liệu thật; 1 story cuối đến đầu; ít nhất một câu hỏi, lưu từ vào deck và quay lại ôn | API/payload thực, nguồn + freshness + ownership, unit/integration/UI test, 1 Simulator; không đánh dấu học thành công nếu lưu lỗi |
| **P2** | Mở rộng thành hai loại chủ đề (`thời tiết` và `tin`) qua cùng flow; cache/expiry/fallback hợp lệ | Nguồn và license riêng từng loại; không thêm ứng dụng đọc tin tổng hợp |
| **P3** | Quan tâm chủ đề và trình độ tối giản (người dùng sửa/tắt được); xếp hạng bằng quy tắc đơn giản kiểm thử được | Chỉ đo cải thiện sau khi có đủ dữ liệu; không dùng AI recommender khi chưa có baseline |
| **P4** | “Học quanh đây”: chọn địa danh thủ công trước, vị trí hiện tại chỉ khi người dùng yêu cầu; học lịch sử/sự kiện theo địa điểm | Bằng chứng quyền dữ liệu địa điểm, độ chính xác, consent, retention, fallback khi từ chối |
| **P5** | Tài chính/chứng khoán, Loto 6/7, đi tàu, ẩm thực, mua sắm, lễ hội... mở rộng nguồn theo nhu cầu thật | Dữ kiện/thời điểm cập nhật, giới hạn khuyến nghị tài chính/cờ bạc, chất lượng Nhật ngữ và mức độ sử dụng |

**Chọn P1 cụ thể:** ưu tiên thử với **một bài thời tiết theo thành phố do người dùng chọn**, nếu tìm được nhà cung cấp có dữ liệu và quyền dùng đủ rõ. Nếu chưa đạt, lấy **một nội dung đời sống do đội ngũ tự biên soạn và có nguồn dữ kiện được phép dùng**, phát hành bằng Daily Radar; ghi rõ đó là bài tình huống, không đánh lừa rằng thời tiết trực tiếp. Không chặn P1 vì NHK/Loto chưa sẵn sàng.

### Acceptance P0 (trước bất kỳ commit implementation nào)

- Ở một iPhone tham chiếu, người dùng tìm được **Bắt đầu ôn** ngay mà không cần cuộn; phần gợi ý đời sống không làm mất khả năng chọn deck/thời lượng.
- Từ một chủ đề đời sống đến câu luyện đầu tiên tối đa 2 thao tác sau khi mở chi tiết; đường quay lại Today dự đoán được; có bài học ngắn thực sự, không là link mở báo thuần túy.
- Với `loading / empty / offline / stale / unauthorized-location / save-failed`, mockup nêu rõ nội dung, CTA, khi nào dữ liệu được giữ. Ghi rõ trường hợp số liệu giả chỉ là fixture.
- Prototype được đọc ở vi/en/ja; tiếng Nhật có xuống dòng, ruby không che nghĩa; Dynamic Type, VoiceOver order và Reduce Motion nằm trong checklist thiết kế. Một Simulator là vòng lặp kiểm nhanh, **không thay cho** kiểm accessibility khi phát hành.
- P0 chốt *owner* nội dung, bộ quy tắc duyệt nguồn, trách nhiệm sửa sai và chính sách xóa dữ liệu location trước khi tiến vào P1.

### Thử nghiệm người dùng / thước đo (giả thuyết, chưa phải kết quả)

- Mời thử ít nhất **5 người** thuộc nhóm mục tiêu; giao 3 tác vụ: bắt đầu ôn cũ, học từ một tin đời sống, lưu được một từ và tìm lại để ôn. Ghi thời gian, đường đi, lỗi hiểu nhầm, lý do thoát. Đây là pilot định tính, không chứng minh thống kê rằng UI tốt.
- **Primary learning metric:** tỷ lệ hoàn tất một câu kiểm tra nhớ lại, tỷ lệ lưu thành công và tỷ lệ nhớ đúng ở lần ôn cách ngày. Phân biệt bài học, thao tác mở, và số thẻ đã lưu.
- **UX health metric:** tỷ lệ tìm được CTA ôn, tỷ lệ bỏ giữa Story → Practice, latency P95 tải story, tỷ lệ lỗi/stale/no-content, số người tắt chủ đề; đo số lần trở lại app như tín hiệu thứ cấp.
- Chỉ mở rộng loại nguồn khi story đầu tiên đủ chất lượng và người dùng **tự nguyện** quay lại học; không tối ưu bằng thông báo dồn dập, mất streak hoặc cuộn vô hạn.

## 7. Nguyên tắc visual & ba skill thiết kế

- `ui-ux-pro-max`: dùng checklist accessibility, touch, typography, loading/error và tìm phản ví dụ. Đề xuất tự động “Vibrant & Block-based / bento / horizontal journey” của skill **không phù hợp với hierarchy Today đã duyệt**; không áp máy móc.
- Apple iOS skill ở `.claude/skills/ios/`: UIKit native navigation/tab/sheets, hit target ≥44 pt, semantic typography/colors, Japanese text/ruby, VoiceOver. Vẫn giữ iOS 26+ hiện tại.
- `design/liquid-glass`: giữ glass ở navigation/toolbar theo Apple; **không phủ glass lên văn bản Nhật, bài học hoặc nội dung tin**. Một CTA nổi bật ở hero; màu chàm và nền giấy hiện có là điểm xuất phát, chưa tự ý thay toàn bộ design system.
- Motion tối giản và có mục đích: chọn chủ đề → mở story, trả lời → feedback, lưu → xác nhận **sau** khi hoàn tất; xử lý double tap, reduce motion và lỗi. Không dùng animation để gây nghiện hoặc che thời gian tải.

## 8. Câu hỏi quyết định cần xác minh, chưa tự phê duyệt

1. **Nguồn bản quyền:** ai là người xác nhận quyền dùng/sửa/hiển thị lại văn bản, hình và audio? Từng loại cần hồ sơ riêng.
2. **Nội dung có người duyệt:** P1 do ai phụ trách biên tập Nhật ngữ và kiểm tra fact? Nếu chưa có owner, giới hạn ở môi trường thử nghiệm.
3. **Dữ liệu thời tiết:** provider nào, điều kiện cấp phép/caching, rate limit, phút cập nhật, fallback thiếu dữ liệu? Không mặc định weather API tồn tại.
4. **Lưu card:** P1 lưu offline vào Realm local hay gọi API server? Theo app hiện tại, **ưu tiên Realm** và chấp nhận chưa đồng bộ. Kiểm trùng theo source+learning item khi có ví dụ thật.
5. **Đo lường:** hiện có hay chưa sự kiện analytics ẩn danh và consent phù hợp? Nếu thiếu, dùng quan sát usability thủ công trước; không đưa SDK analytics mới vào P0.

## 9. Bằng chứng nghiên cứu / tiêu chuẩn để tra cứu khi review

- Retrieval practice và spaced practice có bằng chứng hỗ trợ ghi nhớ; chưa có bằng chứng rằng xem nhiều tin làm người dùng giỏi tiếng Nhật hơn: Carpenter, Pan & Butler (2022), *Nature Reviews Psychology*: https://www.nature.com/articles/s44159-022-00089-1
- Autonomy, competence, relatedness liên quan động lực học; việc chọn chủ đề và thấy mình giải quyết được nhiệm vụ có cơ sở hơn cơ chế ép streak: Ryan & Deci (2020), *Contemporary Educational Psychology*: https://doi.org/10.1016/j.cedpsych.2020.101860
- Progressive disclosure giảm độ phức tạp bề mặt khi chức năng mở rộng: Nielsen Norman Group: https://www.nngroup.com/articles/progressive-disclosure/
- Xin quyền vị trí theo hành động và cho phép từ chối; Apple HIG Privacy: https://developer.apple.com/design/human-interface-guidelines/privacy/
- Quyền NHK không mặc nhiên bao gồm sao chép, biên dịch hoặc dùng làm dữ liệu AI; phải kiểm từng sản phẩm/nguồn và xin phép khi cần: https://www.nhk-g.co.jp/standard/

**Không nằm trong P0:** commit code, đổi MainTabBar/Realm, kiến trúc backend mới, API giả, tích hợp NHK/stock/Loto, tracking nền, paywall hay model recommendation. Chúng chỉ được giao từng story sau khi kế hoạch được duyệt và nguồn dữ liệu vượt gate.
