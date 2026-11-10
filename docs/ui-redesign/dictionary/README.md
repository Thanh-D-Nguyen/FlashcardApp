# Từ điển (Dictionary): tìm kiếm, chi tiết từ / kanji / ngữ pháp / câu, đã lưu, lịch sử, quét chữ, giọng nói

Phạm vi: tab **Từ điển** (`Modules/Dictionary`), các màn chi tiết mới (`Modules/DictionaryEntry`), màn **Đã lưu**
(`Modules/DictionarySaved`), **Quét chữ** (`Modules/DictionaryScan`) và **Tìm bằng giọng nói** (`Modules/DictionaryVoice`).
App vẫn **không đóng gói từ điển**: mọi nội dung từ, kanji, ngữ pháp, câu lấy từ API (xem `docs/DEVELOPMENT.md`). Backend và web
**không bị sửa**.

Nhãn: **[Đã kiểm chứng]** = đã chạy và quan sát/đo trong phiên này; **[Chưa kiểm chứng]** = chưa thể kiểm chứng ở đây.
Ngày kiểm chứng API: 2026-10-26, backend local `http://localhost:18081/api` và `https://kiokoto.com/api` (chỉ đọc, GET).

## 1. Audit trước khi làm

| # | Hiện trạng (mã cũ) | Hệ quả |
| --- | --- | --- |
| 1 | Kết quả mở bằng **hộp thoại** (`showAlert`) chỉ có tiêu đề, cách đọc, nghĩa, JLPT | Không có trang chi tiết, không hành động, không điều hướng liên quan |
| 2 | Một danh sách phẳng, ô mặc định; chỉ lấy 30 kết quả, không phân trang | Không dùng được cho từ có nhiều kết quả |
| 3 | `UISearchController` tìm ngay cả khi bộ gõ tiếng Nhật còn đang ghép chữ | Truy vấn rác ("t", "ta", "tab…") |
| 4 | Lỗi mạng hiện `AFError.localizedDescription`; nút làm mới ở thanh trên | Thông điệp khó hiểu, không có trạng thái lỗi/Thử lại đúng chỗ |
| 5 | Không có lịch sử, không có mục đã lưu, không nhập bằng camera/giọng nói | – |
| 6 | Test chỉ kiểm tra presenter với 1 trang kết quả và alert | Cần viết lại theo hợp đồng mới |

Tái sử dụng (không viết kiến trúc mới): `BJTSearchAPI`, `BJTLearnerAPI.perform` (bearer + Origin cho CSRF), `LearnerAPIError`
(offline / 404 / 429 / 5xx dùng chung toàn app), `CardExamplesInteractor` + `CardExampleLookup` (lọc câu ví dụ theo từ), `StateView`,
`DeskManagement`/`CardManagement` (bộ thẻ Realm cục bộ), `MailLoginWireframe(onFinish:)` (đăng nhập dạng modal),
`SystemSpeechService`, token `Design.*`.

## 2. Ma trận khả năng của backend (đã đối chiếu mã Go + phản hồi thật)

| Endpoint | Auth | Kết quả kiểm chứng | App dùng |
| --- | --- | --- | --- |
| `GET /search?q&scope&limit&offset` | Không | `q` 2–200 **byte**; `scope` = `lexeme|kanji|grammar|example|lesson`; `limit` ≤ 100; trả `[{id,kind,title,description,reading,jlptLevel}]`. **Không hỗ trợ romaji** (`taberu` → rác). Kết quả từ vựng theo xếp hạng của Meilisearch (đúng từ đứng đầu). `kanji`/`grammar` không khớp được cụm có okurigana (`食べる` → rỗng ở `kanji`) | **Có** (30/trang + `offset`) |
| `GET /search/suggest` | Không | Khớp chuỗi con, **sắp theo bảng chữ cái** (`お菓子を食べる` đứng trước `食べる`), không xếp hạng | Không (kém hơn `/search`) |
| `GET /content/lexemes/{id}` | Không | `headword, reading, kanjiMeaningVi, jlptLevel, shortMeaningVi, senses[], pronunciation[]`. **`senses` đang rỗng** với dữ liệu hiện tại (nghĩa duy nhất là `shortMeaningVi`). `pronunciation[].accent` = trọng âm cao/thấp (`LHL-L`) + `tokenizedKana` | **Có** |
| `GET /content/grammar/{id}` | Không | `pattern, meaningVi, jlptLevel, category, details[position, meaningVi?, explanation, note, synopsis]`. **Không có câu ví dụ, không có ngữ pháp liên quan** | **Có** |
| `GET /kanji/{id}` | Không | `meaningVi` (Hán Việt), `onyomi`, `kunyomi`, `strokeCount`, `level` (1–5 = N1…N5), `frequency`, `detail` (đoạn ngăn bằng `##`), `tip` (`<b>`), `strokeSvgHash`, `examples[]`, `components[]`. `examples[].id` **không phải id từ vựng** | **Có** |
| `GET /kanji?q=<ký tự>` | Không | Tìm theo ký tự/nghĩa/âm đọc (LIKE); app lọc đúng ký tự | **Có** (tra kanji theo ký tự) |
| `GET /kanji/{id}/stroke` + `Accept: image/svg+xml` | Không | SVG KanjiVG (CC BY-SA 3.0), `Content-Type: image/svg+xml`. **SHA-256 của file trùng `strokeSvgHash`** (đã kiểm 30/30 kanji thường dùng) | **Có**, kiểm hash + kiểm cú pháp |
| `GET /kanji/by-word/{lexemeId}` | Không | Kanji trong một từ (`id, character, meaningVi`) | **Có** |
| `GET /kanji/words/{id}` | Không | Từ chứa kanji, **sắp theo bảng chữ cái** (nhiễu) | Không (dùng `examples[]` đã chọn lọc) |
| `GET /bookmarks/words|kanji|grammar` | Bearer | `{items:[{id,targetId,type,createdAt}],limit,type}`; **chỉ có id** (không có tiêu đề), tối đa 100, không `offset` | **Có**, rồi tra từng id qua endpoint chi tiết |
| `GET /bookmarks/check/{type}/{id}` | Bearer | `{bookmarked}` | **Có** |
| `POST /bookmarks/{type}/{id}` | Bearer + `Origin` | **Toggle, không idempotent**; thiếu `Origin` → 403 `forbidden: missing origin`; không Bearer → 401 | **Có**, không bao giờ tự thử lại; đọc trạng thái trước khi gỡ |
| `POST /flashcards/cards/from-content` | Bearer + Origin | Tạo thẻ **trên server**. Bộ thẻ của app là **cục bộ** (chưa có đồng bộ) | **Không** — "Thêm vào thẻ" ghi vào bộ thẻ cục bộ do người học chọn |

## 3. Quyết định thiết kế (hướng: "Biên tập Nhật × Apple native", cùng hệ với Cấp độ/Thẻ)

Áp dụng tinh thần của `design-taste-frontend` cho UIKit: nội dung là chính, một màu nhấn (chàm 藍), chữ Nhật dùng Mincho cho từ đầu
mục và kanji, **không thẻ nổi, không bóng, không gradient**, hành động đặt gần nội dung nó tác động, mọi nút có chức năng thật.

- **Danh sách kết quả**: từ vựng/ngữ pháp = từ đầu mục + cách đọc + nghĩa (+ N5); kanji = ký tự lớn kiểu Mincho + nghĩa Hán Việt;
  câu = câu + bản dịch (cách đọc theo tuỳ chọn). Chữ khớp truy vấn được tô (bỏ dấu tiếng Việt, từ chia đuôi khớp qua thân từ).
- **Từ vựng**: từ đầu mục (Mincho 52 pt, co giãn), cách đọc phía trên, JLPT + Hán Việt, **đường trọng âm** (vẽ từ `accent`, chỉ khi
  dữ liệu khớp số âm tiết), Nghe / Lưu / Thêm vào thẻ, Nghĩa, Chữ Hán trong từ, Câu ví dụ (tối đa 5, lọc theo từ).
- **Kanji**: ký tự lớn, nghĩa Hán Việt, số nét · JLPT · hạng tần suất, âm On/Kun (chạm để nghe), **thứ tự nét** (phát/tạm dừng/phát lại/
  từng nét, số nét, lưới luyện chữ), bộ phận, mẹo nhớ, từ chứa chữ này (chạm → tra mục từ), giải nghĩa dài (thu gọn).
- **Ngữ pháp**: mẫu câu, nghĩa, cấp độ · nhóm, Cấu trúc / Giải thích / Lưu ý theo từng cách dùng, câu chứa mẫu (tìm theo mẫu đã bỏ
  `〜 … ()`, chỉ khi còn ≥ 2 ký tự Nhật).
- **Câu**: câu chọn được chữ (menu "Tra từ điển"), cách đọc ẩn/hiện, bản dịch, chữ Hán trong câu (tra từng ký tự, không tự tách từ).
- **Không bịa dữ liệu**: không có furigana từng chữ trong dữ liệu → chỉ hiện dòng cách đọc cả câu; không có tách từ → chỉ tra
  kanji/đoạn người dùng chọn; `senses`/loại từ/ghi chú chỉ hiện khi API có; JLPT, tần suất chỉ hiện khi có.

## 4. Kiến trúc (giữ nguyên VIPER-style, không thêm framework)

```
DictionaryViewController → DictionaryPresenter → DictionaryInteractor → BJTSearchAPI / DictionaryHistoryStore
        └ DictionaryWireframe → DictionaryEntryWireframe | DictionarySavedWireframe | DictionaryScanWireframe | DictionaryVoiceWireframe
DictionaryEntryViewController → DictionaryEntryPresenter → DictionaryEntryInteractor → BJTDictionaryAPI, BJTBookmarkAPI,
        CardExamplesInteractor, DictionaryDeckWriter (Realm, bộ thẻ cục bộ), DictionaryHistoryStore
```

Điểm đáng chú ý:

- `DictionaryQuery` (kiểm tra theo **byte**, NFKC, gộp khoảng trắng) và `RomajiConverter` (romaji → hiragana, chỉ khi **toàn bộ** chữ
  chuyển được; chỉ **đề xuất**, vì "an" cũng là tiếng Việt).
- Tìm kiếm: debounce 300 ms trong `flatMapLatest` (huỷ yêu cầu cũ), không gọi lại cùng (truy vấn, phạm vi), phân trang `offset` theo
  số dòng server đã trả (không phải số dòng hiển thị), kết quả muộn của truy vấn cũ bị bỏ, đổi phạm vi không chờ debounce, không tìm
  khi bộ gõ Nhật còn đang ghép (`markedTextRange`). Khi đang tải truy vấn mới, danh sách cũ **mờ và không chạm được**.
- `KanjiStrokeDrawing`: tự phân tích `<path d>` của KanjiVG (M L H V C S Q T Z, tương đối/tuyệt đối), **từ chối cả file** nếu có DOCTYPE/
  ENTITY, cung tròn, lệnh lạ, > 64 nét, `d` > 2000 ký tự; mọi phần tử khác (script, style, image, text) bị bỏ qua. Hash SHA-256 phải
  khớp `strokeSvgHash` mới vẽ.
- Yêu thích = **bookmark của tài khoản** (cùng danh sách với web), không có hệ yêu thích thứ hai. Khách bấm Lưu → màn đăng nhập
  modal rồi quay lại mục. Lịch sử **tách riêng** (UserDefaults, không phải Realm → không cần migration).
- "Thêm vào thẻ" luôn hỏi bộ thẻ (hoặc tạo bộ "Đã lưu từ từ điển" khi người học chọn). Thẻ có id cố định `dict:<bộ>:<loại>:<id>` và
  từ đã có trong bộ không bị thêm lần hai.
- Quét chữ: Vision `VNRecognizeTextRequest` (`ja-JP`, `en-US`), chạy trên máy, ảnh không tải lên/không lưu; chọn ảnh bằng `PHPicker`
  (không cần quyền thư viện), camera bằng `UIImagePickerController` khi có và được cấp quyền.
- Giọng nói: `SFSpeechRecognizer(ja-JP)` + `AVAudioEngine`, ưu tiên nhận dạng trên máy; luôn dừng (nút dừng, kết quả cuối, 30 giây,
  rời màn hình, huỷ đăng ký).


## 5. Kết quả kiểm chứng (chạy thật, 2026-10-26)

Môi trường: Xcode 27, scheme `FlashcardApp-Local`, **một** simulator **iPhone 17 Pro / iOS 26.5** cho build, test và ảnh; iPhone 17e / iOS 26.5
chỉ cho ảnh "màn nhỏ" và cỡ chữ AX. Backend local `localhost:18081` đang chạy; production `kiokoto.com` chỉ GET để đối chiếu hợp đồng.

| Kiểm tra | Kết quả |
| --- | --- |
| Build (`FlashcardApp-Local`) | SUCCEEDED |
| Toàn bộ unit + UI (`FlashcardAppTests` + `FlashcardAppUITests`, backend local thật) | **992 đạt, 0 lỗi, 10 bỏ qua** (5 test Keychain cần build ký, 2 Google, 1 đăng nhập thật và 1 Life lesson cần tài khoản/server, 1 `DictionaryUITests` đăng nhập — chạy riêng, xem dưới) |
| Test đăng nhập → Lưu → Đã lưu → Gỡ (`testSignedInLearnerSavesAnEntryFindsItInSavedAndRemovesIt`) | **Đạt** với build ký ad-hoc + tài khoản dùng một lần trên DB local (`FLASHCARD_E2E_*`); Keychain được xoá trước/sau; bookmark được gỡ sạch (đã kiểm bằng API) |
| `DictionaryUITests` (không cần đăng nhập) | 13/13 đạt: tìm → chi tiết → quay lại giữ truy vấn · đổi phạm vi · kanji + thứ tự nét (lùi/tiến/phát lại/phát) · ngữ pháp + câu · Nghe · khách bấm Lưu → đăng nhập · Đã lưu khi chưa đăng nhập · thêm vào bộ thẻ (chọn bộ, trùng lặp) · trống/lỗi mạng/Thử lại · lịch sử xem/tìm + xoá · quét chữ (Vision) → sửa → tra · bộ chọn nguồn ảnh · kanji liên quan → quay lại · tờ giọng nói |
| Coverage dòng (unit + UI) của file mới | Logic miền: `DictionaryQuery` 100% · `DictionaryItem` 100% · `DictionaryHistoryStore` 100% · `BJTBookmarkAPI` 100% · `TextHighlight` 100% · `DictionaryEntry` 98,6% · `PitchPattern` 98,3% · `DictionaryPresenter` 95,8% · `DictionaryEntryPresenter` 94,5% · `BJTDictionaryAPI` 94,7% · `DictionarySavedPresenter` 93,1% · `DictionaryDeckWriter` 90,3% · `KanjiStrokeDrawing` 88,2% · `DictionaryVoicePresenter` 99,0%. Màn hình (VC): 74–99%. **`SpeechRecognitionService` 8%** (cần micro thật), wireframe modal 35–65%. Toàn app **không** được suy ra từ số này |
| Ảnh thật (Simulator) | `iphone17pro-ios26.5/`: tìm (sáng/tối), trang chủ trống, kanji (đầu + thứ tự nét, sáng/tối), ngữ pháp, câu, từ vựng tối, quét chữ, tờ giọng nói. `iphone17e-ios26.5/`: kanji, từ vựng, từ vựng + tìm ở **AX-XXXL**. `ui-test-attachments/`: bộ chọn bộ thẻ, lỗi mạng, không kết quả, Đã lưu khi khách, lịch sử, bộ chọn nguồn ảnh |

Lỗi chỉ lộ ra nhờ ảnh/test thật và **đã sửa**: (1) cột trọng âm đè lên chú thích và các âm tiết chồng nhau ở AX-XXXL; (2) mũi tên `>` của dòng bị kéo giãn
và nút loa bị cắt vì ràng buộc xung đột (`EntryRowControl`); (3) tiêu đề mục lịch sử bị lộ **hai lần** với VoiceOver (đổi sang
`UITableViewHeaderFooterView`); (4) ô văn bản quét chữ chiếm cả màn hình; (5) fixture quét chữ cắt mất chữ "す" (lỗi của fixture, không phải OCR);
(6) nút văn bản thô lệch lề trái; (7) toast biến mất trước khi test/người dùng đọc kịp (2,4 s → 3,5 s).

### Review độc lập (agent `flashcard-reviewer`, chỉ đọc mã) và cách xử lý

11 điểm, không có crash/injection/lộ token/mất dữ liệu. **Đã sửa kèm test hồi quy:** chân trang phân trang không bao giờ cập nhật và ghi chú "150 kết quả" kẹt lại
sang màn khác (`DictionaryViewControllerTests`); Thử lại/tải thêm hỏng sau khi tìm bằng văn bản đặt từ chương trình (lịch sử, quét chữ, giọng nói, "Tra từ điển") (`DictionaryPresenterTests`);
Gỡ hai lần cùng một hàng gửi hai toggle và **thêm lại** bookmark (`DictionarySavedPresenterTests`); chống trùng thẻ theo chữ làm mất thẻ kanji 日 khi bộ đã có từ 日
(`DictionaryDeckWriterTests`); Đã lưu không còn tải lại về 30 dòng mỗi lần quay lại và vòng quay không kẹt khi làm mới lỗi; trạng thái lưu **chưa biết** (offline) không còn bị coi là "chưa lưu"
(chạm = hỏi lại, không toggle); đổi tài khoản khi mục đang mở đọc lại trạng thái; thông báo VoiceOver "Đang nghe" chỉ phát một lần; nhãn VoiceOver cho nút micro; dừng ghi âm
cho bộ nhận dạng **nói nốt** những chữ cuối thay vì bỏ; ký tự không phải kanji (bộ thủ ⺅, ノ) trả "không có mục từ" thay vì lỗi.
**Chưa sửa (phía backend, ngoài phạm vi):** `getLexemeDetailHandler`/`getGrammarDetailHandler` trả **404 cho mọi lỗi DB**, nên một lỗi tạm thời của server hiện ra như
"N mục đã lưu không còn trong từ điển"; danh sách bookmark chỉ trả 100 mục mới nhất (không có `offset`). Cần backend trả 500 khi lỗi không phải `ErrNoRows` và thêm phân trang.

## 6. Ma trận khả năng (so với các ứng dụng từ điển Nhật)

Nghiên cứu thị trường (Mazii, Takoboto, Shirabe Jisho, Akebi): được dùng làm **danh mục khả năng**, không sao chép giao diện/nội dung/biểu tượng. Chưa có khảo sát người dùng.

| Khả năng | Trạng thái | Bằng chứng / giới hạn |
| --- | --- | --- |
| Tra Nhật–Việt (kanji/hiragana/katakana/tiếng Việt) | **DONE** | `testSearchOpen…`, dữ liệu thật; **romaji**: chỉ **đề xuất** tìm theo kana (server không hỗ trợ); `RomajiConverter` 100% test |
| Nghĩa từ vựng | **DONE (nghĩa ngắn)** | API hiện chỉ có `shortMeaningVi` (`senses` rỗng) → hiện một nghĩa; loại từ/ghi chú sẽ hiện khi API có |
| Nhiều cách đọc | **DONE** | Nhiều mục trọng âm; trường `reading` nhiều cách đọc hiển thị nguyên văn |
| Kanji (nghĩa, On/Kun, nét, JLPT, tần suất, bộ phận, mẹo nhớ, từ liên quan) | **DONE** | Ảnh + `testSwitchingCategories…` |
| Thứ tự nét (phát/tạm dừng/phát lại/từng nét) | **DONE** | Dữ liệu KanjiVG thật, hash SHA-256 khớp 30/30; test lùi/tiến/phát; ghi công CC BY-SA 3.0 trên màn. Reduce Motion: chỉ bước từng nét |
| Ngữ pháp | **DONE** | Cấu trúc/giải thích/lưu ý từ API. **Ngữ pháp liên quan: BLOCKED** (API không có) |
| Câu ví dụ, bản dịch, tô từ khớp, chọn chữ để tra | **DONE** | Câu lấy từ `/search?scope=example`, lọc theo từ. **Furigana từng chữ và tách từ: BLOCKED** (không có dữ liệu; chỉ có dòng cách đọc cả câu, ẩn/hiện được) |
| JLPT, tần suất | **DONE (khi có)** | JLPT: từ/kanji/ngữ pháp; tần suất: kanji. Từ vựng không có tần suất trong API |
| Trọng âm cao/thấp | **DONE** | Vẽ từ `pronunciation.accent`, đúng quy tắc của web; chỉ vẽ khi dữ liệu khớp số âm tiết |
| Phát âm | **DONE (giọng tổng hợp)** | `AVSpeechSynthesizer ja-JP`, thông báo khi máy chưa có giọng Nhật. **Không phải bản thu người thật.** Âm thanh thật trên thiết bị: NOT VERIFIED |
| Sao chép / chia sẻ | **DONE** | Menu "…", menu giữ lâu trên câu và kết quả |
| Yêu thích (từ/kanji/ngữ pháp) | **DONE** | Bookmark của tài khoản, hợp đồng kiểm với backend thật; khách → đăng nhập |
| Màn Đã lưu, gỡ | **DONE** | Test đăng nhập thật. Chỉ thấy 100 mục mới nhất (giới hạn server) |
| Bộ sưu tập từ vựng | **PARTIAL** | "Thêm vào thẻ" vào bộ thẻ **cục bộ** do người học chọn; chưa có đồng bộ/bộ sưu tập phía server (`from-content` tạo thẻ trên server, không khớp mô hình cục bộ) |
| Lịch sử tìm + xem gần đây | **DONE** | UserDefaults, tách khỏi bookmark; xoá từng mục/tất cả; test 100% |
| Quét chữ bằng camera/ảnh | **PARTIAL** | Vision `ja-JP` chạy trên máy, đọc đúng ảnh tạo sẵn (unit + UI); chọn ảnh qua PHPicker. **Camera trực tiếp, ảnh chụp thật, chữ dọc (縦書き): NOT VERIFIED** (Simulator không có ảnh thật; chưa thử trên máy). Không có xem trước trực tiếp (live scan) |
| Tìm bằng giọng nói | **PARTIAL** | `SFSpeechRecognizer ja-JP`, quyền, từ chối/không khả dụng/thử lại, dừng chắc chắn: máy trạng thái 99% test. **Micro + nhận dạng thật: NOT VERIFIED** (cần thiết bị). `SpeechRecognitionService` 8% coverage |
| Chữ viết tay | **DONE (đo trên nét giả lập; chưa thử bằng tay người thật)** | Nút bút trên thanh điều hướng → canvas vuông (ngón tay/Apple Pencil), hoàn tác nét, xoá, dải gợi ý, ghép nhiều chữ rồi "Tra cứu". Bộ khớp nét tự viết với dữ liệu KanjiVG đóng gói (xem `docs/DEVELOPMENT.md` ▸ Tìm bằng chữ viết tay). Đo: 20/20 chữ thật từ API đúng top-1 (nhiễu vừa), mẫu 165 ký tự có biến dạng: top-1 157–164, top-5 165/165. **NOT VERIFIED:** chữ viết tay thật của người, Apple Pencil, VoiceOver, iPad, hiệu năng Release trên máy thật (Debug/Simulator: ~0,6 giây/lần) |
| Từ điển ngoại tuyến | **NOT DONE (theo quyết định dự án)** | Không đóng gói, không tải CSDL (xem `AGENTS.md`). Offline: lịch sử và bộ thẻ cục bộ; màn từ điển báo mất mạng + Thử lại. Tải từ điển cần quyết định riêng về đóng gói, phiên bản, giấy phép, dung lượng, migration |

## 7. Rủi ro còn lại

1. Bản dịch **en/ja** do người viết (AI), chưa người bản ngữ rà soát; nghĩa từ/kanji/ngữ pháp từ API **chỉ có tiếng Việt** (người dùng en/ja vẫn đọc nghĩa Việt).
2. **Giọng nói và camera thật chưa được kiểm chứng**; trên máy thật cần thử quyền (từ chối rồi cho phép lại), ngắt âm thanh (cuộc gọi), iPad.
3. `-FailFirstSearch`, `-DictionaryQuery`, `-DictionaryOpen`, `-InitialTab`, `-EntryScrollTo`, `-ScanFixtureText`, `-DictionaryOpenScanner/Voice` là móc **chỉ có trong build Debug** (`#if DEBUG`) để chụp ảnh/UI test.
4. VoiceOver thật, Increase Contrast, iPad, thiết bị thật, Reduce Motion bật chưa kiểm chứng (chỉ cỡ chữ AX và Dark Mode đã chụp). Chưa chạy ma trận ngôn ngữ en/ja bằng ảnh.
5. Dữ liệu: `senses` rỗng và 404-cho-mọi-lỗi của backend (mục 5); chất lượng xếp hạng kết quả phụ thuộc Meilisearch (nhiễu do dung sai lỗi gõ ở kết quả phía sau).
6. Tài khoản thử `ios-dict-test-…@example.test` đã tạo trên DB **local** (đã gỡ bookmark); mật khẩu chỉ ở scratchpad của phiên, không nằm trong repo.
7. Thư mục `test-products` của XcodeBuildMCP (~14 GB) tích tụ sau mỗi lần chạy test; dọn thủ công (`~/Library/Developer/XcodeBuildMCP/workspaces/*/test-products`) — không dọn tự động vì thao tác xoá bị chặn.

## 8. Tệp quan trọng đã thêm/đổi

Mạng/DTO: `Networks/BJTClient/{BJTDictionaryAPI,BJTBookmarkAPI}.swift`, `Models/BJTDictionaryDTO.swift` (mới); `BJTSearchAPI.swift` (offset, lỗi thống nhất),
`BJTLearnerAPI.swift` (`perform` dùng chung + query). Miền: `Entities/{DictionaryQuery,DictionaryItem,DictionaryEntry,PitchPattern,KanjiStrokeDrawing}.swift`.
Dịch vụ: `Services/{DictionaryHistoryStore,DictionaryPreferences,TextRecognitionService,SpeechRecognitionService}.swift`. Use case:
`Interactors/Dictionary*Interactor.swift`, `DictionaryDeckWriter.swift`. Màn: `Modules/{Dictionary,DictionaryEntry,DictionarySaved,DictionaryScan,DictionaryVoice}/`,
`Commons/Views/NoticeToastView.swift`, `Commons/Utils/{TextHighlight,DesignSystem}.swift` (thêm vai trò chữ). Cấu hình: `Info.plist` +
`InfoPlist.xcstrings` (camera, micro, nhận dạng giọng nói), `Localizable.xcstrings` (+140 khoá vi/en/ja). Test mới: 16 tệp trong `FlashcardAppTests/` và
`FlashcardAppUITests/DictionaryUITests.swift`. `project.pbxproj` được thêm tệp bằng gem `xcodeproj` (**thứ tự mục bị sắp xếp lại**, nội dung tương đương; đã so sánh tập dòng).
