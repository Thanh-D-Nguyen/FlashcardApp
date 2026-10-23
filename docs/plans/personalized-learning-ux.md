# Học cá nhân hóa — đặc tả UI/UX và chuyển động

Ngày: 2026-10-23. Trạng thái: **PROPOSED — chưa có mockup/prototype mới được duyệt,
chưa triển khai UI, chưa đo usability hoặc cảm giác rung trên thiết bị thật**.
Đi kèm [kế hoạch chức năng L01–L07](personalized-learning.md); không thay đổi trạng
thái triển khai các story đó. Thông số dưới đây là điểm bắt đầu để prototype/tinh chỉnh.

## 1. Hướng thiết kế và bằng chứng hiện có

Giữ hướng “Biên tập Nhật × Apple native”: nền giấy ấm, màu chàm, chữ Nhật là nội
dung chính, một hành động nổi bật mỗi màn. Người học cần tập trung, dễ bắt đầu và
cảm thấy tiến bộ thật. Không biến số lượt học thành bằng chứng thành thạo.

Nguồn visual: [blueprint](../UI_REDESIGN_BLUEPRINT.md),
[Home đã chụp](../ui-redesign/iphone17e-ios26.5_home_light.png),
[màn học đã chụp](../ui-redesign/cards/iphone17e-ios26.5/study_front_light.png).
Ảnh là tham chiếu lịch sử, không phải ảnh của thiết kế mới; ảnh học còn trước các
cập nhật [câu ví dụ/kiểu thẻ](../ui-redesign/card-study/README.md). Khi lệch, dùng
code hiện tại và render mới làm căn cứ, không đưa chữ tiếng Anh trong ảnh cũ trở lại.

Đã đối chiếu `DesignSystem.swift`, `CardStudyViewController.swift`,
`StudyPreferences.swift`, `UserPreferences.swift`: đã có màu/chữ/spacing dùng chung,
flip/chuyển thẻ, kiểm tra Reduce Motion, `StudyHaptics` và lựa chọn kiểu thẻ.
Blueprint §10 ghi công tắc chưa có consumer là mô tả cũ: màn học hiện đã đọc
`isSoundEnabled` cho haptics. Không tạo một haptic engine thứ hai từ đầu.

## 2. Cấu trúc điều hướng

Ở L05, tab đầu trở thành **Hôm nay / Today / 今日**. Giữ bốn tab native:
Hôm nay, Từ điển, Thẻ, Cài đặt; giữ identifier tab cũ. Màn Cấp độ được mở từ hàng
“Học theo cấp độ” trên Today, tái sử dụng luồng levels/content và wireframe hiện có.
Không tạo tab thứ năm, không ghép tất cả trạng thái mới vào presenter cấp độ bằng cờ.

| Điểm vào | Hành động chính | Điểm đến / cách quay lại |
| --- | --- | --- |
| Today, đã có bộ thẻ đang học | Bắt đầu ôn | Phiên học → kết quả → Today đã cập nhật |
| Today, chưa chọn bộ thẻ | Chọn bộ thẻ | Sheet danh sách → chọn → quay lại Today, không tự tạo deck |
| Today, chưa có bộ thẻ | Tạo bộ thẻ | Luồng tạo có sẵn; bỏ dở vẫn quay lại Today |
| Today, Học theo cấp độ | Chọn cấp độ | Levels → nội dung; Back về đúng vị trí cuộn |
| Tab Thẻ | Học bộ thẻ đã chọn | Luồng học hiện có; kết thúc quay lại thư viện |
| Today, bài tình huống (L06) | Luyện tình huống | Giới thiệu → nghe/phản hồi → giải thích → tổng kết |
| Today, Xem tiến bộ | Xem bằng chứng | Sheet thông tin ngắn; đóng về Today |

Bản đầu Today ôn **một bộ thẻ đang chọn**, ghi rõ tên bộ thẻ cạnh số lượng.
Không hiển thị tổng đến hạn của mọi deck rồi chỉ mở một deck. Nếu có một deck thì
dùng nó; nếu có nhiều deck và chưa chọn thì yêu cầu chọn một lần. Lưu lựa chọn theo
chủ thể học; deck bị xóa thì quay về trạng thái chọn, không dùng ID lỗi.
Từ điển và cấp độ không bị yêu cầu đăng nhập chỉ để xem nội dung công khai.

## 3. Màn hình và hành vi

### S01 — Today

Thứ tự trên trang cuộn:
1. Large title native “Hôm nay”; một câu hướng dẫn ngắn theo trạng thái.
2. Khối chàm chính: tên deck/mục tiêu → số mục đến hạn → thời lượng ước tính → CTA.
3. Hàng “Bộ thẻ đang học” và “Thời gian”; chỉnh bằng sheet/menu gần vị trí chạm.
4. Tiến bộ có bằng chứng: lượt đã lưu hôm nay và kết quả theo loại bài luyện.
5. Học theo cấp độ; nội dung khám phá/tình huống chỉ xuất hiện khi đã có nội dung thật.

Không có banner chào lớn chiếm màn đầu, carousel tự chạy hoặc nhiều CTA cùng màu.
Ở cỡ chữ mặc định, CTA bắt đầu nằm trong viewport đầu trên iPhone tham chiếu; chữ
lớn được phép cuộn để giữ nguyên nội dung. Không giảm font nhằm ép tất cả lên một màn.

Sheet thời gian đề xuất 3/5/10 phút, mặc định 5 phút là **giả thuyết cần thử**.
Thời lượng chỉ là ngân sách ước tính để giới hạn bài, không countdown; dữ liệu quá ít
thì hiển thị số mục thay cho lời hứa thời gian. Tùy chọn mới thuộc L05, được lưu/test
theo chủ thể học. Không thêm onboarding nhiều trang hay hỏi quyền thông báo lúc mở app.

| Trạng thái | Nội dung / CTA | Điều không được xảy ra |
| --- | --- | --- |
| Chưa có deck | “Bắt đầu với bộ thẻ của bạn” → Tạo bộ thẻ; lối phụ Học theo cấp độ | Số liệu demo, dashboard rỗng không có đường đi |
| Có deck, chưa có lượt học | “Bắt đầu luyện bộ thẻ này” | Gọi thẻ chưa học là đã quên hoặc đến hạn |
| Có lượt đến hạn | Số mục đến hạn thực + Bắt đầu ôn | Trộn điểm nghe với nhớ nghĩa |
| Không đến hạn | “Hôm nay chưa có mục cần ôn” + lựa chọn Luyện thêm | Đồng nhất với “đã hoàn thành” khi hôm nay chưa học |
| Hoàn thành phiên hôm nay | Xác nhận số lượt đã lưu + Xem kết quả / Luyện thêm | Bắt buộc học tiếp để nhận kết quả |
| Quay lại sau nghỉ dài | Phiên nhỏ trong ngân sách + tổng tồn hiển thị rõ | Thông báo trách móc, mất streak, ép ôn hết |
| Đang đọc store | Loading tại khối học; giữ điều hướng dùng được | Nháy 0 trước khi biết kết quả |
| Store lỗi | “Chưa đọc được tiến độ” + Thử lại | Dùng 0 thay lỗi hoặc tự xóa dữ liệu |
| API khám phá lỗi | Lỗi riêng tại khu vực khám phá + Thử lại | Khóa phiên học local còn dùng được |

### S02 — Phiên ôn: trước khi lộ đáp án

Header: tên deck rút gọn được, chỉ báo tiến độ, Back và menu có sẵn.
Phân biệt vị trí “Thẻ 2/8” với “Đã lưu 1/8”; progress hoàn thành dựa trên lượt
đã lưu, không phải chỉ số thẻ đang hiển thị. Điểm này cần đổi/test ở L03.

Thân: nhãn kiểu bài → headword/câu hỏi → nút nghe → vùng đáp án hoặc nút Hiện đáp án.
Giữ kiểu thẻ do người học chọn; ảnh không có thì không để lỗ trống, không ảnh AI
trang trí thay cho nội dung học. Thẻ dài co giãn/cuộn; nút dưới nằm trên safe area.
Chạm Loa/Menu không lật thẻ. Câu ví dụ và nghĩa vẫn ẩn trước khi trả lời như hiện tại.

Phân biệt hai mục đích trong UI: xem/luyện tự do và ôn có ghi kết quả. Ở ôn có
ghi kết quả, xem reading/nghĩa/gợi ý phải được ghi là hỗ trợ, kể cả reading được bật
sẵn trong preferences. Không lấy một mặt thẻ đã lộ đáp án làm bài tự nhớ lại sạch.
Nút nghe có chủ đích vẫn dùng được khi tắt âm thanh phản hồi.

### S03 — Trả lời, tự đánh giá và lưu

Quiz giữ các lựa chọn dọc, vùng chạm đủ rộng. Chạm lựa chọn chốt một lần, hiện chữ
“Đúng” hoặc “Chưa đúng” + ký hiệu và đáp án; không chỉ đổi xanh/đỏ. Câu trả lời sai
được giải thích ngắn, có thể mở chi tiết. Không rung lắc mạnh, không tự nhảy câu khi
người học đang đọc hoặc VoiceOver chưa đọc xong.

Flip: sau Hiện đáp án, mode ôn đề xuất hai nút **Cần ôn lại / Đã nhớ**, nhãn phụ
“Bạn tự đánh giá”; không tự chấm khi lật. Tên này là quyết định UX đề xuất; L04 phải
chốt mapping rating với scheduler, không suy ra mức nhớ chắc chắn. Chuyển Next mà
không đánh giá được tính là bỏ qua, không đúng. Giữ luồng xem thẻ tự do hiện có.

| Trạng thái lưu | Hiển thị | Hành vi |
| --- | --- | --- |
| Đang lưu | Đáp án vẫn đọc được; chỉ báo nhỏ nếu lưu chưa xong sau ~300 ms | Không thêm lượt do double tap; không delay ghi để diễn animation |
| Đã lưu | CTA Câu tiếp theo; bộ đếm hoàn thành tăng một lần | Cập nhật ngay sau transaction thành công, không đợi hiệu ứng kết thúc |
| Lưu lỗi | “Chưa lưu được lượt này” + Thử lại | Giữ câu/đáp án, không báo đã hoàn thành; retry cùng attempt ID |
| Muốn rời khi lưu lỗi | Xác nhận rõ lượt chưa lưu sẽ không có trong tiến độ | Cho Quay lại / Rời phiên; không chặn vô hạn |
| Đổi tài khoản giữa phiên | Thông báo phiên thuộc tài khoản trước; kết thúc luồng hiện tại | Không hiển thị/lưu lại kết quả sang chủ thể mới |

Back bình thường không cần alert khi mọi lượt đã lưu. Bản đầu không hứa resume
đúng vị trí phiên sau kill app: chỉ hứa giữ các lượt đã lưu, dựng phiên mới từ lịch.
Không dùng chữ “Tiếp tục phiên” nếu chưa có state phục hồi vị trí bền vững.

### S04 — Kết quả và tiến bộ

Một tiêu đề hoàn thành → số lượt đã lưu → breakdown đúng/sai/bỏ qua/tự đánh giá
theo dữ liệu thật → lời giải thích ngắn → **Xong**; Luyện thêm là hành động phụ.
Nếu kết thúc sớm: tiêu đề “Đã lưu tiến độ”, không đóng dấu hoàn thành cả bài.
Lượt lỗi không nằm trong tổng đã lưu. Tỷ lệ đúng chỉ có mẫu số là câu đã chấm;
không gộp tự đánh giá vào accuracy. Không có dữ liệu thì nói chưa đủ dữ liệu.

Sheet tiến bộ trên Today ban đầu là danh sách có ngày và loại bài, không radar
nghe/nói/đọc/viết giả. Biểu đồ tuần chỉ làm nếu giúp trả lời một câu hỏi cụ thể;
khi có, kèm giá trị văn bản và ngày theo locale/múi giờ đã định nghĩa ở L04.
Chưa dùng “nhớ vững” cho đến khi có tiêu chí kiểm tra trì hoãn được đặc tả/test.

### S05 — Bài tình huống (L06)

Giới thiệu gọn: bối cảnh, việc sẽ làm được, số bước, CTA Bắt đầu. Không autoplay audio
trước hành động bắt đầu; không xin microphone vì bản đầu chưa thu/chấm lời nói.
Trong bài: tên người nói → nút Nghe/Nghe lại và trạng thái playback → lựa chọn phản
hồi → giải thích sắc thái → bước kế tiếp. Nút Xem lời thoại luôn dễ tìm; dùng nó
được ghi hỗ trợ và không còn tính là nghe không transcript.

Không bật transcript qua accessibility label của nút audio. VoiceOver vẫn có đường
Xem lời thoại hoặc chuyển sang đọc; phân loại bằng chứng theo bài thực sự thực hiện.
Không đánh sai vì người dùng cần cách tiếp cận khác. Replay audio không tạo lượt mới;
số lần replay được ghi nếu đã nằm trong contract đánh giá, không âm thầm đổi quy tắc.

Ảnh bối cảnh chỉ dùng khi giúp hiểu tình huống, có quyền sử dụng và không chứa đáp án.
Audio loading/lỗi là trạng thái thật, không dùng waveform giả như đang phát.
Audio lỗi: Thử lại hoặc Học bằng lời thoại, không tính đường đọc thành nghe đúng.
Rời màn/background/cuộc gọi đến: dừng hoặc pause theo playback contract; quay lại
không tự phát âm thanh bất ngờ. Chỉ một nguồn speech/audio hoạt động tại một thời điểm.

Lưu từ từ bài: chọn deck → báo kết quả lưu thật → trở lại đúng bước. Không bắt
người học bỏ bài sang một flow không có đường quay lại. Nghĩa theo ngữ cảnh và
đáp án thay thế cần duyệt; Sentence Builder có cách bấm để xếp/gỡ từ ngoài kéo thả.

### S06 — Giá trị trả phí (thiết kế sau bằng chứng pilot L07)

Chưa đặt paywall trong L01–L06. Khi đủ điều kiện: xuất hiện sau khi đã xem kết quả,
giải thích chương trình được mở, giá/kỳ hạn thực từ StoreKit, trial/renewal rõ ràng,
Khôi phục giao dịch và đóng màn dễ thấy. Đặc tả mua đang chờ, hủy, lỗi, offline,
hết hạn và restore trước implementation. Không khoá deck/historical data của người học,
không countdown giả hoặc hứa kết quả học chắc chắn.

## 4. Ngôn ngữ thị giác và component

| Thành phần | Quy tắc đề xuất |
| --- | --- |
| Nền / bề mặt | Dùng `Design.Color.background` / `.surface`; giữ light/dark hiện có |
| Nhấn | `.accent` và một khối `.hero` trên Today; màu trạng thái kèm chữ/ký hiệu |
| Bố cục | Gutter 16, spacing 4/8/12/16/24/32 theo `Design.Spacing`; tăng theo nội dung, không frame cố định |
| Chữ Nhật chính | Vai trò `.term`/`.headword` hiện có; tên/câu dài wrap, không shrink đến khó đọc |
| Nghĩa / giải thích | `.meaning`/`.explanation`; dòng reading `.reading` từ dữ liệu thật |
| Số liệu / phụ đề | `.figure`/`.metadata`; số theo `AppLanguage.current.locale` |
| Nút chính | Dùng `Design.Button`, vùng chạm ít nhất 44×44 pt; chiều cao gợi ý 52–56 pt, được tăng khi chữ lớn |
| Card | `CardSurfaceView`, tôn trọng theme hiện có; không áp hero Today lên nội dung thẻ |
| Lỗi / rỗng | Tái sử dụng `StateView` khi phù hợp; lỗi một vùng không thay cả màn |
| Điều hướng / sheet | UIKit native; không blur/glass tự dựng phủ lên chữ đang học |
| Icon / hình | SF Symbols từ chức năng; không dùng emoji làm navigation icon hoặc icon rỗng không nhãn |

Không thêm font dependency. Furigana căn từng ký tự chỉ làm khi có mapping đúng;
khi chỉ có reading toàn từ/câu thì dùng dòng reading riêng. Không trang trí kanji
to cạnh câu hỏi nếu nó vô tình tiết lộ đáp án. Không tạo design system thứ hai.

## 5. Ma trận motion × haptic × audio

**Thông số là đề xuất cho prototype, không phải khuyến cáo thời lượng của Apple.**
Các chuyển cảnh native dùng timing hệ thống. Motion tuỳ biến nằm trong UIKit hiện
có; không chuyển sang SwiftUI chỉ để dùng ví dụ API trong skill.

| Sự kiện | Visual / timing đề xuất | Rung / âm thanh | Reduce Motion / ngắt giữa chừng |
| --- | --- | --- | --- |
| Nhấn CTA | Highlight native; custom card tối đa scale 0.98 trong 80–120 ms nếu cần | Không rung thêm cho mọi nút | Bỏ scale, giữ highlight; touch cancel trả trạng thái |
| Today → phiên | Push native, giữ hướng Back quen thuộc | Không âm mở màn | Tôn trọng thiết lập hệ thống; không khóa Back vì animation |
| Lật thẻ | Kế thừa trục theme; hiện đang 450 ms, prototype so với 300–350 ms | Reuse `StudyHaptics.flip`, không SFX mặc định | Crossfade ~150 ms; chỉ một đổi mặt được xử lý mỗi lượt |
| Chọn đáp án | Viền/ký hiệu/text đổi trong 120–180 ms, feedback giữ đến Next | Reuse answered; sai nhẹ hoặc tắt, không buzzer | Nội dung/text có ngay; double tap không chấm/rung hai lần |
| Lưu thành công | Bộ đếm/progress cập nhật ~180–220 ms; không toast mỗi lượt | Không rung lần hai sau answered | Giá trị cập nhật ngay; render lại không replay |
| Lưu lỗi | Dòng lỗi xuất hiện cạnh thao tác, fade ~150 ms | Một warning nếu bật; không lặp theo mỗi render | Static cùng thông tin; Retry vẫn dùng được |
| Chuyển thẻ | Kế thừa forward/backward ~250 ms, dịch tối đa 12–16 pt | Không SFX vuốt | Đổi nội dung trực tiếp hoặc fade ≤150 ms; không xếp hàng các tap |
| Mở ví dụ/giải thích | Expand ~180–220 ms, giữ vị trí đọc; không scroll giật | Không rung | Thay layout trực tiếp; focus vẫn ở nút mở |
| Audio phát/dừng | Trạng thái icon + elapsed/progress thực; không loop trang trí | Chỉ speech/audio bài học, không chồng âm phản hồi | Không cần motion để biết trạng thái; luôn có nút dừng |
| Hoàn thành phiên | Một checkmark xuất hiện + số liệu thật trong 250–350 ms | Một success nếu bật, không fanfare mặc định | Checkmark tĩnh; Xong dùng được ngay; chỉ fire một lần |

Không confetti mỗi thẻ, nền hạt bay, parallax hoặc nhấp nháy đỏ. Nếu thêm celebration
hiếm sau này, phải gắn với mốc thật và không che nội dung/khóa thao tác.

### Trách nhiệm và quyền kiểm soát

- Presenter quyết định event/domain state; ViewController là nơi render và phát
  feedback qua `StudyHaptics` hiện có. Không cho cả presenter và view tự phát rung.
- Cùng attempt/event chỉ phát phản hồi một lần; reload, quay từ editor, đổi theme,
  reconnect hoặc app foreground không replay success. Animation completion không
  được quyết định việc persist, cộng điểm hoặc sinh lượt mới.
- Khi thao tác mới/ngắt cảnh xuất hiện, hủy/hoàn tất visual về state mới nhất;
  không giữ reference card cũ, không trì hoãn input chỉ để xem hiệu ứng.
- Giữ công tắc “Âm thanh và rung” hiện có trong phạm vi này; không đổi giá trị đã
  lưu. Tắt thì không có feedback rung/SFX; audio học do người dùng chủ động bật vẫn
  riêng với feedback, còn autoSpeak theo preference hiện có và dừng khi rời màn.
- Chưa thêm SFX vào bản đầu. Nếu làm sau, cần quyết định riêng về asset, mute,
  silent switch, audio session và tách điều khiển nếu cần; không tự tạo Core Haptics
  engine hoặc SoundService chỉ vì skill có ví dụ.
- Mục tiêu prototype: chuyển động ổn định trên thiết bị tham chiếu; không decode
  ảnh, đọc Realm, gọi API hoặc format dữ liệu trong mỗi frame. Đo trước khi kết luận
  “mượt”; thiết bị 120 Hz không phải lý do bắt mọi máy đạt 120 fps.

## 6. UX writing và bản địa hóa

Giọng: rõ ràng, bình tĩnh, khuyến khích vừa đủ. Không nói người học “thất bại” khi
trả lời sai. Không dùng thuật ngữ scheduler, Realm, event hoặc sync cho flow học.
Copy dưới đây là bản nháp; key English khi triển khai, đủ vi/en/ja trong catalog.

| Vị trí | English key đề xuất | Tiếng Việt | 日本語 (cần rà soát bản ngữ) |
| --- | --- | --- | --- |
| Tab | Today | Hôm nay | 今日 |
| Bắt đầu | Start review | Bắt đầu ôn | 復習を始める |
| Mở đáp án | Show answer | Hiện đáp án | 答えを見る |
| Tự đánh giá | Needs review | Cần ôn lại | もう一度復習する |
| Tự đánh giá | I remembered | Đã nhớ | 思い出せた |
| Tiết lộ lời thoại | Show transcript | Xem lời thoại | セリフを見る |
| Lưu lỗi | Couldn't save this attempt. | Chưa lưu được lượt này. | 今回の学習結果を保存できませんでした。 |
| Retry | Try again | Thử lại | もう一度試す |
| Hoàn thành | Progress saved | Đã lưu tiến độ | 学習の進み具合を保存しました |

Tái sử dụng key đã có nếu cùng nghĩa; không nhân đôi key chỉ do viết hoa khác nhau.
Chuỗi đếm/thời lượng dùng placeholder/plural và locale của app, không nối các mảnh
dịch. Nội dung backend thiếu ngôn ngữ hiển thị fallback có giải thích phù hợp;
không gọi TTS/dịch tự động để giả làm bản nội dung đã kiểm duyệt.

## 7. Accessibility và kiểm chứng trải nghiệm

- Thứ tự VoiceOver: tiêu đề → trạng thái tiến độ → câu hỏi → hỗ trợ/nghe → đáp án
  → phản hồi → Next. Nội dung mặt sau không xuất hiện trong accessibility tree
  trước khi reveal; không đọc trùng do container và label con cùng accessible.
- Sau Next, focus vào câu hỏi mới; feedback sai/lỗi đọc một lần khi thay đổi,
  không announce progress từng frame hoặc giành focus khỏi câu đang đọc.
- Dynamic Type: stack dọc cho số liệu/nút khi cần, đáp án/giải thích wrap, vùng
  điều khiển không che nội dung và bàn phím. Không bắt thao tác kéo thả/gesture bí mật.
- Kiểm tra tương phản theo theme thực, Reduce Transparency/Increase Contrast khi
  thay đổi material/màu liên quan; không dựa riêng vào xanh/đỏ, âm thanh hoặc rung.
- Routine: một Simulator, build, flow thực và screenshot cỡ chữ mặc định. Với
  story thay motion: kiểm thêm Reduce Motion trên cùng thiết bị; với thay font/layout:
  một cỡ accessibility có rủi ro. Không mặc định chạy ma trận toàn bộ thiết bị/ngôn ngữ.
- Haptic/silent switch/audio interruption cần iPhone thật trước nghiệm thu cảm giác.
  Simulator xác minh wiring/UI, không chứng nhận độ mạnh rung hay cân bằng âm lượng.

## 8. Các gói thiết kế và điều kiện bàn giao

| Gói | Gắn story | Đầu ra bắt buộc trước khi đóng story UI |
| --- | --- | --- |
| U00 — Chọn bố cục | Có thể song song L01–L02; chốt trước code UI L03/L05 | Mockup Today + học + kết quả, so sánh 2–3 bố cục nếu cấu trúc còn mở; ghi hướng được chọn, không coi spec này là mockup đã duyệt |
| U01 — Học và lưu | L03 | S02–S04: prototype đúng/sai/self-rating/saving/error/exit; chỉ rõ gợi ý và tiến độ đã lưu; test hành vi tương ứng |
| U02 — Today | L05 | S01 đầy đủ trạng thái, chọn deck/thời gian, đường vào Levels và quay lại; không fake số liệu |
| U03 — Motion và feedback | Cùng L03/L05, không để đến cuối roadmap | Clip ngắn flip/answer/retry/summary thường và Reduce Motion; ghi duration thực/owner/toggle, haptic test trên máy thật còn thiếu phải ghi rõ |
| U04 — Tình huống | L06 | S05: audio/transcript/đáp án/giải thích/lưu từ, lỗi audio và fallback đọc; nội dung đã duyệt |
| U05 — Usability và trả phí | L07 | Protocol thử nghiệm + phát hiện/sửa lỗi; chỉ dựng S06 sau điều kiện pilot |

Mockup/prototype dùng fixture đánh dấu rõ, không đưa số liệu fixture vào bản phát hành.
Chọn định dạng phù hợp với bước thiết kế: hình để chốt bố cục, prototype UIKit để
kiểm chứng tương tác/motion. Không tạo một web app hoặc đổi app sang SwiftUI để
thực hiện kế hoạch này. Chỉ dùng preview SwiftUI cô lập nếu dự án đã có chỗ phù hợp.

Tác vụ usability đề xuất: bắt đầu ôn mà không cần hướng dẫn; phân biệt thẻ chưa học
và đến hạn; phục hồi khi lưu lỗi; tìm lại Levels; bật lời thoại rồi giải thích điểm
nghe; kết thúc phiên mà không bị ép học tiếp. Ghi hoàn thành, chạm sai, câu hỏi,
thời gian tìm CTA; không suy ra willingness-to-pay chỉ từ người dùng nói “đẹp”.

Mỗi story UI bàn giao: frame/prototype được chọn, bảng state, copy ba ngôn ngữ,
event×channel đã nối, diff/test, ảnh/clip đúng build và danh sách chưa kiểm chứng.
Test RED/GREEN dành cho tương tác/domain (double tap, save failure, hỗ trợ, route,
feedback fire một lần), không viết test so sánh từng ms/màu/khoảng cách để đủ coverage.

## 9. Skill áp dụng theo công việc

| Skill | Áp dụng | Ràng buộc của app |
| --- | --- | --- |
| [UI UX Pro Max](../../.claude/skills/ui-ux-pro-max/SKILL.md) | Kiểm tra phân cấp, vùng chạm, error states, motion và khả năng đọc | Đã chạy `--design-system` và tra cứu `--domain ux`; đề xuất Claymorphism/Baloo 2/Comic Neue và landing App Store lệch ứng dụng học tiếng Nhật cho người lớn, **không áp dụng** |
| [Apple Design](../../.claude/skills/design/SKILL.md) | Điều hướng bản địa, chữ, UX writing, event×feedback, Reduce Motion | Dùng UIKit và `Design.*` hiện có; không sao chép các ví dụ API SwiftUI |
| [Liquid Glass](../../.claude/skills/design/liquid-glass/SKILL.md) | Kiểm tra nav/tab/toolbar, vật liệu và phân lớp | Dùng bar native của iOS 26+; không phủ glass lên nội dung, không tự tạo glass nhiều tầng |
| `impeccable` / shape | Phân cấp, trạng thái và đặc tả trước code | Dùng context repo hiện có; không tạo PRODUCT/DESIGN song song hay ép đổi visual identity |
| [design/ux-writing](../../.claude/skills/design/ux-writing/SKILL.md) | Copy hành động, lỗi, rỗng, kết quả | Chỉ hứa trạng thái dữ liệu thật; localization vi/en/ja |
| [design/typography](../../.claude/skills/design/typography/SKILL.md) | Chữ Nhật, hierarchy, Dynamic Type | Dùng `Design.TextRole`; mức kiểm thử theo guardrails |
| [design/animation-patterns](../../.claude/skills/design/animation-patterns/SKILL.md) | Motion và interruptibility | Áp dụng nguyên tắc bằng UIKit; không copy API SwiftUI vào app |
| [design/game-feel](../../.claude/skills/design/game-feel/SKILL.md) | Ma trận event×channel, nhịp feedback | Reuse `StudyHaptics`; người học cá nhân không cần torch/fanfare/custom engine |
| [design/ui-prototyping](../../.claude/skills/design/ui-prototyping/SKILL.md) | So sánh bố cục, edge state, tune khi vào U00 | Đọc skill lúc làm prototype; kế hoạch này chưa thực hiện các preview |
| [ios/ui-review](../../.claude/skills/ios/ui-review/SKILL.md) | Review UI thực sau triển khai | Điều chỉnh checklist cho UIKit, không mặc định refactor SwiftUI |
| [flashcard-delivery](../../.claude/skills/flashcard-delivery/SKILL.md) | Nối UX acceptance → TDD → review → commit | Không đánh dấu DONE từ tài liệu/mockup |

Nguyên tắc nền tảng đã đối chiếu: motion có mục đích, ngắn và có thể ngắt; haptics
bổ trợ phản hồi khác, dùng nhất quán. Nguồn: [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion),
[Apple Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).
Các bố cục, số lựa chọn và timing ở đây là quyết định đề xuất của dự án, chưa phải
bằng chứng người học thích hoặc sẵn sàng trả tiền.

## 10. Review độc lập: điều gì đã chốt, điều gì còn phải kiểm chứng

Đối chiếu ba bộ skill với `MainPresenter`, `HomeViewController`,
`CardStudyViewController`, `CardStudyPresenter`, `StudySession`, blueprint và
kế hoạch L01–L07. Kết quả CLI UI UX Pro Max là **gợi ý theo từ khóa**, không phải
bằng chứng về sở thích người học hay thiết kế đã được duyệt. Các tiêu chí có thể
chuyển sang UIKit: mục tiêu chạm ≥44 pt, lỗi được thông báo cả bằng chữ/VoiceOver,
nhãn rõ nghĩa, tránh nhảy bố cục và luôn có đường thoát khỏi trạng thái rỗng.

| Đánh giá | Kết luận có thể giao việc | Trạng thái |
| --- | --- | --- |
| Kiến trúc màn | Tab đầu hiện dùng `HomeWireframe` để hiển thị Levels; L05 cần điểm vào Today riêng, vẫn dùng `HomeWireframe` hiện có cho Levels và giữ `tab_levels`, `home_levels` ở đúng đối tượng kiểm thử | CHỐT HƯỚNG, chưa code |
| Nội dung học | Study hiện có `CardStudyTransition`, card flip/quiz, audio, examples, menu, preferences, `StudyHaptics`; mở rộng cùng presenter/interactor, không tạo engine thứ hai | ĐỦ CƠ SỞ để đặc tả |
| Dữ liệu tiến bộ | `StudySession.progress` hiện dựa vào vị trí, không phải lượt persist; không được gọi đó là tiến độ ôn đã lưu | BLOCK L03 cho đến khi L01–L02 xong |
| Thiết kế thẩm mỹ | Giữ giấy/chàm và hệ text role đã triển khai; đề xuất claymorphism, font thiếu định hướng CJK và landing CTA từ tool bị loại | CHỐT HƯỚNG, chưa nghiệm thu ảnh |
| Liquid Glass | Tab/navigation và các nút phụ native đang có nền tảng tương thích; tránh phủ vật liệu lên hero và nội dung từ vựng | CHỐT QUY TẮC, phải xem render |
| Tương tác/hiệu ứng | Ma trận §5 đủ làm prototype; timing và cảm giác haptic cần so sánh trước/sau | GIẢ THUYẾT cần U03 |
| Scenario/audio | Chưa có bộ dữ liệu, response và quyền sử dụng đã duyệt cho L06 | BLOCK implementation cho đến gate L06 |
| Usability | Chưa có prototype của Today, phiên có lưu, Scenario và thử nghiệm người thật | NOT VERIFIED; làm U00–U05 |

**Quyết định cần lấy bằng chứng ở U00**, không tự đánh dấu approved: độ lớn hero
Today so với nội dung dưới fold, cách hiện hai lựa chọn tự đánh giá ở cuối màn,
và việc có nên dùng thời lượng 3/5/10 phút thay cho số câu. Chốt bằng prototype
trên máy tham chiếu và task usability; không cần tạo bộ màu/font mới để quyết định.

## 11. Layout blueprint có thể dựng bằng UIKit

Các sơ đồ là **wireframe dạng chữ**, để xác nhận thứ bậc và hành vi; chưa phải
mockup pixel-perfect hay ảnh chạy thật. Dùng `Design.Spacing.gutter`, text roles,
safe area và UIKit controls hiện có. `→` biểu thị hành động; chữ trong khung là
nhãn minh họa cần bản địa hóa khi code, không phải copy đã chốt.

### W01 — Today (S01, U00/U02)

```text
┌─ Navigation: Hôm nay (large title) ─────────────┐
│ Gợi ý ngắn theo trạng thái, không hiển thị streak│
│ ┌─ Khối chính .hero ───────────────────────────┐ │
│ │ Bộ thẻ: [Tên đang học / Chưa chọn]            │ │
│ │ [Số cần ôn thật / Trạng thái chưa có lịch]     │ │
│ │ [ Bắt đầu ôn / Chọn bộ thẻ / Tạo bộ thẻ → ]   │ │
│ └──────────────────────────────────────────────┘ │
│ Bộ thẻ đang học                   [Thay đổi  ›] │
│ Ngân sách phiên                        [5 phút ›]│
│ ── Tiến bộ ────────────────────────────────────│
│ [Đã lưu hôm nay]  [Loại bài]  [Xem chi tiết ›]  │
│ ── Khám phá ───────────────────────────────────│
│ Học theo cấp độ                              › │
│ Tình huống thực tế (chỉ khi dữ liệu đã duyệt) › │
└─ Tab native: Today | Dictionary | Cards | Settings┘
```

- **Vùng nhìn đầu**: đặt tên deck, trạng thái có thật và CTA trong hero đầu tiên;
  không chèn ảnh decor hay banner phía trên. Sheet đổi deck/time là hành động phụ
  theo hàng riêng, chỉ hiển thị các lựa chọn có tác dụng trong story hiện tại.
  Không mặc định thêm metric/điều khiển mới vào bản phát hành trước L04/L05.
- **Scroll và khung nhỏ**: Today cuộn như một nội dung duy nhất; CTA nằm trong vùng
  nhìn đầu ở cỡ chữ mặc định trên simulator mục tiêu (đây là gate U00, chưa đo).
  Không sticky hero hoặc đặt hai CTA nổi đè tab bar; khi chữ lớn, cho cuộn.
- **Loading/error**: chỉ hero có skeleton tĩnh hoặc loading label khi đọc local;
  không dịch chuyển hàng ngay khi số thực về. Khi store lỗi, giữ action Levels
  hoạt động; khi tải khám phá lỗi, chỉ hiện retry trong vùng khám phá. Nếu lựa chọn
  deck đã bị xóa, xóa **chỉ lựa chọn UI lỗi thời**, không xóa dữ liệu khác.
- **CTA**: không deck → Tạo bộ thẻ; nhiều deck/chưa chọn → Chọn bộ thẻ;
  có deck/chưa có lịch → Luyện bộ thẻ; có mục đến hạn → Bắt đầu ôn; không có
  mục đến hạn → Luyện thêm. Phân biệt luyện tự do với ôn có lưu kết quả.

### W02 — Study trước khi trả lời (S02) và Answer/Save (S03, U01)

```text
┌─ Nav: ‹  [Tên deck]                  [•••] ─────┐
│ Thẻ 2/8                    Đã lưu 1/8          │
│ [━━━━ tiến độ ĐÃ LƯU ━━━━━━━━━━━━━━━━━━━━━]    │
│              [KIỂU BÀI: TỰ NHỚ]              │
│ ┌─ CardSurfaceView ─────────────────────────┐ │
│ │             [ TỪ / CÂU HỎI ]              │ │
│ │       [ Nghe (SF Symbol speaker) ]        │ │
│ │       [ Hiện đáp án ] / [ Lựa chọn ]      │ │
│ └───────────────────────────────────────────┘ │
│ [Ví dụ / Giải thích] — cuộn theo nội dung      │
│                                                │
│ ── Safe-area controls ──────────────────────── │
│ [Bỏ qua]     [Cần ôn lại]    [Đã nhớ]          │
└────────────────────────────────────────────────┘
```

- Header phân biệt **vị trí duyệt thẻ** và **số attempt đã commit**; progress bar
  dành cho tỷ lệ commit theo phiên có lịch. Phiên tự do giữ chỉ báo vị trí hiện tại,
  không hiển thị nhãn `Đã lưu`. Tên deck được truncate, nhưng accessible label
  còn đầy đủ. Không tính `StudySession.progress` cũ là giá trị đã lưu.
- Khi **chưa reveal**, chỉ hiện một CTA `Hiện đáp án` hoặc các đáp án quiz. Khi
  **đã reveal**, hiện kết quả đúng/sai hoặc hai lựa chọn tự đánh giá, tùy mode;
  `Bỏ qua` là secondary. Không để cả `Hiện đáp án` và `Đã nhớ` cùng lúc. Sau khi
  chấm, vùng đáp án/giải thích luôn đọc được cho tới lúc người học bấm tiếp.
- **Không ép ba nút ngang hàng** như sơ đồ ở màn nhỏ: với hai rating, dùng hai
  nút có text rõ, cân bằng thị giác; `Bỏ qua` là text control riêng, không làm
  người học nhầm là chấm đúng. Khi chữ lớn, rating xếp dọc. `Previous/Next`
  của chế độ xem tự do giữ chức năng cũ; ở chế độ có lưu, việc đi lại sau khi
  commit chỉ được phép xem lại, không phát sinh attempt/feedback lần hai.
- Nội dung dài cuộn trong `scrollView`; bottom controls nằm trên safe area và
  không che giải thích. Audio/menu/expand không kích hoạt gesture lật; việc lật
  chỉ từ vùng đã xác định. Khi VoiceOver bật, có nút `Hiện đáp án` rõ nghĩa thay
  cho yêu cầu người học phải khám phá gesture.
- **Saving**: khóa rating cho attempt đó và giữ nguyên câu; chỉ báo lưu hiện
  trong vùng feedback sau một khoảng trễ ngắn để tránh nháy. **Saved**: cập nhật
  số lượt rồi cho `Câu tiếp theo`. **Failed**: `Thử lại` cùng attempt ID và nút
  rời có xác nhận; không chuyển thẻ hoặc tự tăng tiến độ. Spinner không thay toàn
  bộ card; never show success từ animation completion.

### W03 — Results (S04, U01)

```text
┌─ Nav: Kết quả ──────────────────────────────────┐
│ [Checkmark tĩnh / một lần khi thật sự hoàn tất]│
│ Đã lưu [N] lượt học                            │
│ Quiz: [a] đúng / [b] chưa đúng                 │
│ Tự đánh giá: [c] lượt (không cộng accuracy)    │
│ Bỏ qua: chỉ hiện khi có attempt đã lưu hợp lệ │
│ [Các mục cần ôn lại / giải thích ngắn]         │
│                                                │
│ [                   Xong                    ]  │
│ [                 Luyện thêm                 ]  │
└─ Trở về tab/nguồn mở phiên, không ép mở Today ──┘
```

- `[N]`, `[a]`, `[b]`, `[c]` là placeholder cho wireframe, không được đưa
  vào sản phẩm; dữ liệu thực phải lấy từ attempt đã commit. Nếu bỏ giữa chừng, dùng `Đã lưu
  tiến độ`, không gắn nhãn hoàn thành. Nếu cả phiên chưa lưu lượt nào, hiển thị
  thông báo phù hợp, không xuất biểu đồ 0% hoặc danh hiệu.
- `Xong` gọi Wireframe trả về Today hoặc Cards theo nguồn mở; chọn tab khác
  khi quay lại không được làm phát lại success. Sau `Luyện thêm`, chỉ tạo phiên
  mới từ scheduler thực; không chấm lại tự động lượt cũ.

### W04 — Scenario (S05, U04; bị chặn bởi điều kiện L06)

```text
┌─ Nav: ‹  Tình huống: [Tên thật]    Bước 2/5 ──┐
│ [Bối cảnh / mục tiêu một câu]                  │
│ [Người nói]                                   │
│ [ Phát / Dừng / Nghe lại ] [trạng thái thật]   │
│ [ Xem lời thoại ]  [Ẩn lời thoại]             │
│ ┌─ Chọn phản hồi ───────────────────────────┐  │
│ │ [Phương án A]                            │  │
│ │ [Phương án B]                            │  │
│ └───────────────────────────────────────────┘  │
│ [Giải thích nghĩa/ngữ cảnh — sau khi chọn]     │
│ [Lưu từ vào bộ thẻ — nếu contract hỗ trợ]      │
│ [               Bước tiếp theo              ]  │
└────────────────────────────────────────────────┘
```

- Intro trước màn này cho biết kết quả học được và số bước; không autoplay.
  Transcript là hành động có nhãn và không lộ trong nhãn VoiceOver của audio.
  Lựa chọn/giải thích chỉ có hiệu lực khi dữ liệu nội dung được duyệt; không
  đánh giá `nghe độc lập` nếu transcript đã mở hoặc audio lỗi.
- Khi audio loading: có nhãn `Đang tải âm thanh`, dừng được và không có waveform
  giả. Khi lỗi: `Thử lại` hoặc `Học bằng lời thoại`; đường lời thoại không cấp
  điểm nghe. Khi app background/cuộc gọi: pause/stop theo audio contract đã chốt,
  không tự phát khi resume. Nếu người học lưu từ, giữ vị trí và hiển thị kết quả
  lưu thật; cancellation không tự đánh dấu xong bước.

## 12. State và navigation contracts để triển khai không phải đoán

**Tách hai loại phiên từ điểm vào**:
`browse` (lật/xem/next, không ghi thành tích) và `review` (lượt có bằng chứng
và lưu). Không gắn review khi người học chỉ nghe hoặc lật. Việc chọn mode và
chuyển qua lại phải được presenter định nghĩa trước lúc L03 code; không âm thầm
chuyển mode giữa attempt đang mở. Quy tắc chung cho cả hai: nguồn Today/Cards
được giữ trong Wireframe; Levels vẫn dùng navigation stack hiện có.

| State phiên `review` | Event hợp lệ | State tiếp theo / UI bắt buộc |
| --- | --- | --- |
| `question` | Reveal / chọn quiz | `revealed`/`answered`: đáp án và giải thích, có dữ liệu gợi ý đã dùng |
| `question` hoặc `revealed` | Skip | `skipped` nếu contract ghi lượt bỏ qua; nếu không, next không tăng số đã lưu và phân biệt rõ trong summary |
| `revealed` | Chọn tự đánh giá | `saving`: khóa chấm và điều hướng thẻ, lưu attempt ID ổn định |
| `answered` | Submit quiz | `saving`: chỉ một attempt cho câu; chạm lặp không gửi đôi |
| `saving` | Transaction thành công | `saved`: cập nhật progress một lần, cho Next |
| `saving` | Transaction lỗi | `saveFailed`: giữ nguyên bài/answer/ID, hiện Retry và cảnh báo khi rời |
| `saveFailed` | Retry | `saving`: tái sử dụng đúng ID, không chấm lại |
| `saved` | Next / hết phiên | `question` kế tiếp hoặc `results`; không tái ghi result cũ |
| Bất kỳ state chưa commit | Đổi chủ thể học, background/kill, deck không còn | Không nhận commit dưới chủ thể mới; chỉ lượt đã commit tồn tại sau khởi động lại |

**Lưu ý mapping:** việc Skip có tạo attempt `skipped` hay chỉ bỏ qua là quyết
định domain của L01/L03; summary phải theo semantics đã test. Không thiết kế
counter `bỏ qua` nếu L01 không có dữ liệu. `question` và `revealed` khác nhau
ở khả năng nhìn đáp án, không đồng nghĩa với điểm đúng/sai. Trong `saving`,
không cho swipe chuyển card; nút Back có thể yêu cầu đợi kết quả transaction,
sau đó thoát an toàn. Không khẳng định transaction đã hủy khi hệ điều hành kill.

`Scenario`: `intro → audioReady/loading/playing → response → explanation → next
step → summary`. `transcriptOpen` và `audioUnavailable` là thuộc tính hỗ trợ
trên từng bước, không tự tạo thêm một lần trả lời; `background` làm dừng hoặc
pause audio theo chính sách của L06. Review answer/score chỉ xảy ra từ event
có input hợp lệ, không từ việc phát/replay audio.

**Flow cuối cùng:** `Today → Chọn deck (nếu cần) → Study(review) → Results →
Today`; `Cards → Study(browse/review tùy điểm vào) → Results nếu đã ghi →
Cards`; `Today → Học theo cấp độ → Levels → Nội dung → Back → Today`.
Trong sheet lựa chọn deck, bấm Cancel đóng sheet không mất context. Sau khi
đổi deck, số và CTA phải phản ánh đúng deck vừa chọn. Mỗi thao tác rời màn phải
giải phóng mạng/speech hiện có mà không xóa attempt đã lưu.

## 13. Acceptance và lịch kiểm chứng gắn với story

| Gate | Given / When / Then và bằng chứng cần nộp |
| --- | --- |
| U00 (trước khi chốt UI L03/L05) | So sánh mockup ít nhất hai phương án hero/controls với cùng nội dung thật hoặc fixture **đánh dấu**; chọn bố cục bằng tác vụ `tìm CTA / đọc câu hỏi / thấy số đã lưu`, ảnh annotated và lý do chọn |
| U01 / L03 | Given trả lời quiz hai lần, when nhấn liên tục, then chỉ một attempt persist; Given transaction lỗi, then đáp án không biến mất, Retry đúng ID, không tăng tiến độ; Given rời/kill, then chỉ attempt committed hiện lại |
| U01 / L03 | Given flip và xem reading, when chưa tự đánh giá, then không có `remembered` tự động; Given chuyển mode/back, then trạng thái lưu và điều hướng vẫn nhất quán |
| U02 / L05 | Given không deck/chưa chọn/không due/quá hạn/store lỗi, when mở Today, then mỗi state có CTA phù hợp và không có số giả; Given chọn deck, when quay lại Today, then số và tên deck cùng đổi |
| U02 / L05 | Given mở Levels từ Today, when quay lại, then vị trí cuộn và cả bốn tab giữ nguyên; Given đến Study từ Cards, when Xong, then trở lại Cards |
| U03 | Given answer/flip/save success/save error, when event xảy ra, then phản hồi chỉ một lần đúng owner, không che nội dung; với Reduce Motion, nội dung/trạng thái tương đương không cần chuyển động; clip và thiết bị kiểm chứng được ghi |
| U04 / L06 | Given audio lỗi, when chọn transcript, then bài vẫn đọc được và không ghi điểm nghe; Given bấm Replay, then không thêm attempt; Given lưu từ, then quay lại cùng bước và chỉ thông báo sau khi lưu thành công |
| U05 / L07 | Làm tác vụ không có hướng dẫn, ghi lỗi tìm CTA, thoát giữa phiên, phân biệt quiz và tự đánh giá; không suy ra hiệu quả học hay tỷ lệ mua từ ý kiến thẩm mỹ |

Kiểm chứng từng story khi triển khai: focused XCTest RED/GREEN cho logic, một
simulator `FlashcardApp-Local` cho navigation và UI, kiểm tra một luồng thành
công cùng các lỗi ảnh hưởng dữ liệu, ảnh/video từ **build thật**. Với thay đổi
motion kiểm thêm Reduce Motion; haptic và audio-interruption cuối cùng cần thiết
bị thật. U00 và tài liệu này chưa qua build/test/prototype nên mọi gate UI vẫn
**NOT VERIFIED**. Việc xem được wireframe, chạy script design hay review mã
không thay cho kết quả sử dụng thực tế.

**Thứ tự giao Claude/Codex**: U00 (chốt bố cục trước khi sửa UI); L01 → L02 →
L03 + U01/U03 → L04 → L05 + U02 → L06 + U04 → L07 + U05. Giao từng story
có phạm vi file/test và review riêng, không bắt một agent triển khai cả roadmap.

## 14. U00 — bàn giao chọn bố cục (2026-10-23)

**Trạng thái: ĐỀ XUẤT, CHỜ DUYỆT THỊ GIÁC.** Chưa là thiết kế đã duyệt; không bắt đầu code UI
L03/L05 cho đến khi người sở hữu sản phẩm chọn/sửa hướng dưới đây. L01–L02 không phụ thuộc.

Bằng chứng (ảnh trong [`docs/ui-redesign/personalized-learning/u00/`](../ui-redesign/personalized-learning/u00/);
nguồn HTML tĩnh trong `src/`, dùng đúng token `DesignSystem.swift`, số liệu là **fixture**):
[Today ×3](../ui-redesign/personalized-learning/u00/today_alternatives.png),
[Today trạng thái](../ui-redesign/personalized-learning/u00/today_states.png),
[Study ×3](../ui-redesign/personalized-learning/u00/study_alternatives.png),
[Study trạng thái](../ui-redesign/personalized-learning/u00/study_states.png),
[Results ×2 + ngoại lệ](../ui-redesign/personalized-learning/u00/results_alternatives.png).
Dựng lại: `chrome --headless=new --screenshot=<png> --window-size=<w>,<h> file://…/src/<tên>.html`.

### Đề xuất và lý do

| Màn | Chọn | Lý do (dựa trên ảnh/đo layout, chưa phải usability test) | Phương án bị loại |
| --- | --- | --- | --- |
| Today | **A · Hero-first** | Cùng ngôn ngữ với màn Cấp độ đã có; một khối nổi bật; đổi bộ thẻ/thời lượng, tiến bộ và Cấp độ đều trong màn đầu. CTA đo được y 350–404 pt (iPhone 17, 852 pt); với chữ +35% và tên bộ thẻ dài vẫn y 440–513, trên tab bar (y 767) | **B** (danh sách gọn, CTA y 288–342): ba khối trắng cùng trọng lượng, mất điểm nhấn; **C** (khối chàm ~70% màn, số 132 pt, CTA y 516–570): chỉ lộ 2 hàng, số tồn lớn dễ tạo áp lực |
| Study (ôn có lưu) | **A + câu hỏi của C** | Hai nút tự đánh giá ở thanh dưới, cùng vị trí ngón cái với “Hiện đáp án”, thẻ giữ chiều cao; thêm dòng “Bạn nhớ từ này không?” đủ rõ; hai nút **cùng trọng lượng** (không nút “đúng” nổi bật, tránh thiên lệch tự đánh giá); “Bỏ qua” là chữ | **B** (nút trong thẻ): hai điểm chạm chính cùng lúc (rating + Câu tiếp theo bị khóa); **C** (panel gắn đáy): thẻ mất ~125 pt, thêm một lớp bề mặt |
| Results | **A · Danh sách trước** | Con số nằm trong câu, không thành huy hiệu; “Tự đánh giá” tách khỏi tỷ lệ đúng; danh sách “Cần ôn lại” suy ra từ lượt đã lưu | **B** (khối chàm với số lượt lớn): dễ đọc như điểm số/thành tích |

Thời lượng 3/5/10 phút: giữ làm **ngân sách ước tính**, luôn hiển thị số mục thật cạnh nó
(“12 mục cần ôn · ≈4 phút”). Mặc định 5 phút vẫn là giả thuyết; chốt bằng usability test ở L05.

### Quy tắc rút ra từ ba skill thiết kế (đã đối chiếu với UIKit/sản phẩm)

- **Liquid Glass**: giữ tab bar/nav bar hệ thống (nổi, glass). Hero và thẻ học là lớp nội dung, không glass;
  không glass-trên-glass (loại panel C vì lý do này và vì tốn chỗ); chỉ một nút nhấn (tint) mỗi màn.
  Nút rating dùng bề mặt đặc cùng trọng lượng; có dùng `UIButton.Configuration.glass()` cho nút phụ hay không
  phải xem render thật trước (chưa kiểm).
- **Apple Design / UX writing**: nhãn hành động rõ (“Bắt đầu ôn”, “Hiện đáp án”, “Cần ôn lại/Đã nhớ”), lỗi nói
  điều gì đã xảy ra và lối ra (“Chưa lưu được lượt này.” + Thử lại), không trách móc khi quay lại sau nghỉ.
- **UI UX Pro Max**: chỉ dùng checklist chuyển được sang UIKit (vùng chạm ≥44 pt, lỗi gần thao tác, nút khóa
  khi đang lưu, không nháy bố cục). Bảng màu/phông do công cụ gợi ý tiếp tục **không áp dụng** (xem §9).
- Trạng thái đã vẽ: Today ×6 (chưa có bộ thẻ, chưa có lượt học, không đến hạn, xong hôm nay, nghỉ dài, store lỗi),
  Study ×6 (trước lộ đáp án, tự đánh giá, đang lưu, đã lưu, lưu lỗi, quiz đã trả lời), Results ×2 ngoại lệ
  (dừng sớm, chưa lưu lượt nào).

### Phát hiện từ mockup cần xử lý trong L03/L05

1. Cách đọc bật sẵn theo tùy chọn trước khi trả lời phải được ghi là **gợi ý** (nhãn ở mặt trước và mặt sau),
   nếu không lượt tự nhớ không còn “sạch”. L03 gọi `StudySession.noteHint(.reading)` khi cách đọc đang hiện.
2. “Thẻ n/12” (vị trí) và “Đã lưu n/12” (đã commit) phải là hai chỉ số riêng; thanh tiến độ chỉ theo lượt đã lưu.
3. Trạng thái “đến hạn” chỉ có từ L04. Trước đó Today dùng “Luyện bộ thẻ này” (trạng thái 2), không dùng từ “đến hạn”.
4. Chưa xác định: thẻ đã lật nhưng người học không tự đánh giá rồi bấm back/next — theo L01 là không có lượt.

### Chưa kiểm chứng (NOT VERIFIED)

Mockup HTML xấp xỉ render iOS (phông hệ thống, tab bar glass, SF Symbols vẽ tay); không phải UIKit chạy thật,
chưa có Dynamic Type thật, VoiceOver, Reduce Motion, tương tác/motion (U03), chưa có người dùng thật
(U05). Giá trị CTA y là hình học của mockup, không phải của app. Mọi gate UI ở §13 vẫn **NOT VERIFIED**.
