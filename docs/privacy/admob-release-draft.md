# Bản nháp: quyền riêng tư và AdMob trên iOS

Chưa xuất bản. Đối chiếu lại với cấu hình AdMob, đối tượng người dùng, các đối tác quảng cáo và bản build phát hành trước khi dùng; các nội dung trong ngoặc vuông phải được xác minh.

## Đề xuất bổ sung chính sách quyền riêng tư

### Quảng cáo và đối tác

Ứng dụng iOS sử dụng Google AdMob để hiển thị quảng cáo. Google và [các đối tác quảng cáo thực tế] có thể xử lý địa chỉ IP, thông tin thiết bị, mã nhận dạng thiết bị hoặc quảng cáo khi được phép, vị trí tương đối suy ra từ IP, thông tin về quảng cáo được hiển thị và tương tác, dữ liệu hiệu năng và chẩn đoán. Tùy cấu hình và lựa chọn của bạn, dữ liệu này có thể được dùng để phân phối và đo lường quảng cáo, giới hạn tần suất, phát hiện gian lận, cải thiện dịch vụ và [cá nhân hóa quảng cáo nếu được phép].

Quảng cáo không cá nhân hóa vẫn có thể yêu cầu xử lý thông tin để phân phối và đo lường. Xem [Chính sách quyền riêng tư của Google](https://policies.google.com/privacy) và [cách Google sử dụng thông tin từ các ứng dụng sử dụng dịch vụ của Google](https://policies.google.com/technologies/partner-sites).

**Đoạn tiếng Anh để biên tập cùng bản tiếng Việt:** The iOS app uses Google AdMob to display advertising. Google and its advertising partners may process IP addresses, device information, device or advertising identifiers when permitted, approximate location derived from IP addresses, ad interactions, and performance or diagnostic information. Depending on the configuration and your choices, this information may be used to deliver and measure ads, limit their frequency, prevent fraud, improve services, and personalize ads where permitted. Non-personalized ads may still require processing information for delivery and measurement. See [Google's Privacy Policy](https://policies.google.com/privacy) and [how Google uses information from apps that use its services](https://policies.google.com/technologies/partner-sites).

**Đoạn tiếng Nhật để biên tập cùng bản tiếng Việt:** iOSアプリは広告の表示にGoogle AdMobを利用します。Googleおよび広告パートナーは、IPアドレス、端末情報、許可された場合の端末識別子または広告識別子、IPアドレスから推定されるおおよその位置、広告への反応、パフォーマンスや診断に関する情報を処理する場合があります。設定と利用者の選択に応じて、これらの情報は広告の配信・測定、表示頻度の制限、不正防止、サービスの改善、許可された場合の広告のパーソナライズに利用されることがあります。パーソナライズされていない広告でも、配信と測定のために情報の処理が必要な場合があります。[Googleのプライバシーポリシー](https://policies.google.com/privacy)と[Googleのサービスを使用するアプリからの情報の利用方法](https://policies.google.com/technologies/partner-sites)をご覧ください。

### Lựa chọn quyền riêng tư

Ở những khu vực áp dụng, ứng dụng hiển thị thông báo về mục đích xử lý và đối tác quảng cáo. Khi có sẵn, bạn có thể xem hoặc thay đổi lựa chọn tại **Cài đặt → Lựa chọn quyền riêng tư quảng cáo**. [Nếu bản phát hành yêu cầu quyền theo dõi của Apple: giải thích riêng thông báo ATT, cách từ chối và thay đổi quyền trong Cài đặt iOS → Quyền riêng tư & Bảo mật → Theo dõi.]

### Trẻ em và người chưa đủ tuổi đồng ý

[Mô tả chính xác đối tượng mục tiêu, cách xử lý khi biết người dùng chưa đủ tuổi đồng ý theo pháp luật áp dụng, các hạn chế quảng cáo thực sự được thực hiện và kênh liên hệ cho cha mẹ hoặc người giám hộ.]

Chính sách hiện tại cũng cần nêu rõ đơn vị vận hành và cách liên hệ, nhóm bên nhận dữ liệu, thời hạn lưu giữ hoặc tiêu chí xác định, quyền rút lại đồng ý, cách yêu cầu xóa/xuất dữ liệu và cách thông báo thay đổi. Xác minh các thao tác xóa/xuất trước khi mô tả.

## App Privacy: danh sách đối chiếu, chưa phải khai báo cuối cùng

Ứng dụng yêu cầu SDK giới hạn nội dung quảng cáo ở mức G. Giới hạn nội dung này không xác định tuổi người dùng và không thay thế các cài đặt xử lý dữ liệu trẻ em hoặc người chưa đủ tuổi đồng ý.

Theo [Google Mobile Ads SDK 13.12.0](https://developers.google.com/admob/ios/privacy/data-disclosure) và manifest SDK trong bản build Simulator, xem xét **Device ID**, **Coarse Location**, **Advertising Data**, **Product Interaction**, **Crash Data**, **Performance Data** và **Other Diagnostic Data**. Manifest SDK khai Device ID có thể dùng tracking; Coarse Location, Advertising Data, Product Interaction và Device ID có thể liên kết người dùng. Các mục đích trong manifest gồm quảng cáo bên thứ ba, quảng cáo của nhà phát triển và analytics tùy loại dữ liệu. Đây là khai báo của SDK, không thay thế đánh giá hành vi của toàn ứng dụng. Xác định từng mục có liên kết với người dùng, có dùng để tracking, và mục đích thực tế. Không giả định ATT hoặc lựa chọn không cá nhân hóa loại trừ mọi việc thu thập dữ liệu.

Đối chiếu thêm dữ liệu của toàn ứng dụng, SDK đăng nhập, analytics, server và mọi đối tác mediation thực tế; kiểm tra Privacy Report từ archive và App Store Connect trước khi khai báo. UMP và ATT là các lựa chọn độc lập. Với người dùng chưa đủ tuổi đồng ý, cờ UMP và cấu hình yêu cầu quảng cáo phải được xử lý riêng theo [Google](https://developers.google.com/admob/ios/privacy/gdpr).

Kiểm tra thêm [App Review Guidelines §2.5.18 và §5.1](https://developer.apple.com/app-store/review/guidelines/): quảng cáo phải phù hợp độ tuổi, cho xem thông tin nhắm mục tiêu trong ứng dụng và cho phép báo cáo quảng cáo không phù hợp; chính sách cần mô tả thu thập, chia sẻ, lưu giữ và xóa dữ liệu.

## Trạng thái chuẩn bị App Store Connect

Hồ sơ `Flashcard - Kiokoto`, Apple ID `6833736696`, bundle ID `com.ds.FlashcardApp`, đã có URL chính sách, mô tả và danh mục Education. Mục App Privacy lưu bản nháp 11 loại dữ liệu để tiếp tục phân tích, chưa khai xong mục đích, liên kết danh tính và tracking. Các loại trong bản nháp không phải kết luận cuối; rà soát cả ứng dụng, backend và SDK trước khi công bố.

Age rating chưa được lưu. App hiển thị bộ thẻ công khai do người dùng tạo và có quảng cáo; chưa thấy công cụ kiểm soát của cha mẹ hoặc xác minh độ tuổi. Cần xác minh cách Apple phân loại chức năng khám phá/chia sẻ bộ thẻ như social media, nội dung từ backend và UGC, cùng màn Loto dẫn đến trang kết quả xổ số. Kiểm tra cả quy trình lọc nội dung, tiếp nhận báo cáo và chặn tác giả theo App Review 1.2; không suy ra tần suất nội dung nhạy cảm từ mã giao diện.
