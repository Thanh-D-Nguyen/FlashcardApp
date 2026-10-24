//
//  SampleLifeContent.swift
//
//  Example lessons for the topics the server does not provide yet. They are written by hand, shown with a "Sample" tag, and say
//  "example content · not live data yet": they teach real Japanese but they are not facts about today. The day the server sends
//  its own `/api/life/feed`, these are no longer shown (see `TodayLifeHubLoader`). The money and lottery samples are explainers
//  only: no rates, no predictions, no betting links.
//

import Foundation

enum SampleLifeContent {
    private typealias S = LifeLessonDraft.Sentence
    private typealias W = LifeLessonDraft.Word

    static let topics: [LifeTopic] = [.transit, .shopping, .news, .food, .culture, .money, .lottery]

    static func lessons(now: Date, calendar: Calendar = .current) -> [LifeLesson] {
        let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        return topics.compactMap { draft(for: $0) }.map { $0.build(now: now, expiresAt: dayEnd) }
    }

    private static func draft(for topic: LifeTopic) -> LifeLessonDraft? {
        let provider = NSLocalizedString("Example content", comment: "Source of a sample lesson")
        switch topic {
        case .transit:
            return LifeLessonDraft(
                id: "sample:transit", topic: .transit, provenance: .sample,
                titleJapanese: "電車が遅れています", titleReading: "でんしゃがおくれています", titleVi: "Tàu đang bị trễ", titleEn: "The train is delayed",
                providerName: provider,
                chips: [LifeChip(symbol: "tram.fill", text: "山手線 · 約15分遅れ"), LifeChip(symbol: "arrow.triangle.swap", text: "振替輸送あり")],
                scene: .transit,
                sentences: [
                    S(id: "late", japanese: "電車が遅れています。", reading: "でんしゃがおくれています。", vi: "Tàu đang bị trễ.", en: "The train is running late.",
                      explanationVi: "遅れる là “trễ”; 〜ています diễn tả trạng thái đang diễn ra.", explanationEn: "遅れる means “to be late”; 〜ています is the ongoing state."),
                    S(id: "line", japanese: "山手線は約十五分遅れています。", reading: "やまのてせんはやくじゅうごふんおくれています。", vi: "Tàu Yamanote trễ khoảng 15 phút.", en: "The Yamanote Line is about 15 minutes late.",
                      explanationVi: "約 là “khoảng”; 15 phút đọc là じゅうごふん.", explanationEn: "約 means “about”; 15 minutes is じゅうごふん."),
                    S(id: "transfer", japanese: "振替輸送をご利用ください。", reading: "ふりかえゆそうをごりようください。", vi: "Xin hãy sử dụng dịch vụ vận chuyển thay thế.", en: "Please use the substitute transport service.",
                      explanationVi: "Câu thường nghe trong thông báo ở ga; ご〜ください là cách nhờ lịch sự.", explanationEn: "A common station announcement; ご〜ください is a polite request.")
                ],
                words: [
                    W(id: "sample:transit:late", japanese: "遅れる", reading: "おくれる", vi: "trễ, chậm", en: "to be late", example: "電車が遅れています。"),
                    W(id: "sample:transit:delay", japanese: "遅延", reading: "ちえん", vi: "sự chậm trễ", en: "delay", example: "電車が遅れています。"),
                    W(id: "sample:transit:substitute", japanese: "振替輸送", reading: "ふりかえゆそう", vi: "vận chuyển thay thế", en: "substitute transport", example: "振替輸送をご利用ください。"),
                    W(id: "sample:transit:suspended", japanese: "運転見合わせ", reading: "うんてんみあわせ", vi: "tạm dừng chạy tàu", en: "service suspended", example: "運転見合わせになりました。")
                ],
                recall: .init(promptJapanese: "電車が＿＿います。", cueVi: "Gõ động từ “trễ” ở dạng て (nối với います).", cueEn: "Type the verb “to be late” in its て-form (before います).",
                              accepted: ["遅れて", "おくれて"], explanationVi: "Đáp án: 遅れて (おくれて) — đang trễ.", explanationEn: "Answer: 遅れて (おくれて) — is late."),
                choice: .init(promptJapanese: "遅延", promptVi: "“遅延” đọc là gì?", promptEn: "How do you read “遅延”?", options: ["ちいん", "ちえん", "ちえい"], correct: 1,
                              explanationVi: "遅延 đọc là ちえん (chậm trễ).", explanationEn: "遅延 is read ちえん (delay)."), level: "N3")
        case .shopping:
            return LifeLessonDraft(
                id: "sample:shopping", topic: .shopping, provenance: .sample,
                titleJapanese: "レジで支払い", titleReading: "れじでしはらい", titleVi: "Thanh toán ở quầy", titleEn: "Paying at the register",
                providerName: provider,
                chips: [LifeChip(symbol: "yensign", text: "税込 1,080円"), LifeChip(symbol: "tag.fill", text: "10%割引")],
                scene: .shopping,
                sentences: [
                    S(id: "total", japanese: "税込1,080円です。", reading: "ぜいこみせんはちじゅうえんです。", vi: "Tổng cộng 1.080 yên, đã gồm thuế.", en: "That is 1,080 yen, tax included.",
                      explanationVi: "税込 là “đã gồm thuế”; 1.080 đọc là せんはちじゅう.", explanationEn: "税込 means “tax included”; 1,080 is read せんはちじゅう."),
                    S(id: "card", japanese: "ポイントカードはお持ちですか。", reading: "ポイントカードはおもちですか。", vi: "Bạn có thẻ tích điểm không?", en: "Do you have a points card?",
                      explanationVi: "お持ちですか là cách hỏi lịch sự “bạn có (mang theo)… không?”.", explanationEn: "お持ちですか is the polite “do you have (with you)…?”."),
                    S(id: "bag", japanese: "袋は要りますか。", reading: "ふくろはいりますか。", vi: "Bạn có cần túi không?", en: "Do you need a bag?",
                      explanationVi: "要る là “cần”; trả lời: はい、お願いします / 大丈夫です.", explanationEn: "要る means “to need”; answer はい、お願いします or 大丈夫です.")
                ],
                words: [
                    W(id: "sample:shopping:taxin", japanese: "税込", reading: "ぜいこみ", vi: "đã gồm thuế", en: "tax included", example: "税込1,080円です。"),
                    W(id: "sample:shopping:discount", japanese: "割引", reading: "わりびき", vi: "giảm giá", en: "discount", example: "十パーセント割引です。"),
                    W(id: "sample:shopping:bag", japanese: "袋", reading: "ふくろ", vi: "túi", en: "bag", example: "袋は要りますか。"),
                    W(id: "sample:shopping:checkout", japanese: "会計", reading: "かいけい", vi: "thanh toán", en: "checkout, bill", example: "会計をお願いします。")
                ],
                recall: .init(promptJapanese: "＿＿1,080円です。", cueVi: "Gõ từ nghĩa là “đã gồm thuế”.", cueEn: "Type the word for “tax included”.",
                              accepted: ["税込", "ぜいこみ", "税込み"], explanationVi: "Đáp án: 税込 (ぜいこみ).", explanationEn: "Answer: 税込 (ぜいこみ)."),
                choice: .init(promptJapanese: "1,080円", promptVi: "“1,080円” đọc là gì?", promptEn: "How do you read “1,080円”?",
                              options: ["ひゃくはちじゅうえん", "せんはっじゅうえん", "せんはちじゅうえん"], correct: 2,
                              explanationVi: "1.080 = せん (1000) + はちじゅう (80) → せんはちじゅうえん.", explanationEn: "1,080 = せん (1000) + はちじゅう (80) → せんはちじゅうえん."), level: "N4")
        case .news:
            return LifeLessonDraft(
                id: "sample:news", topic: .news, provenance: .sample,
                titleJapanese: "台風が近づいています", titleReading: "たいふうがちかづいています", titleVi: "Bão đang đến gần", titleEn: "A typhoon is approaching",
                providerName: provider,
                chips: [LifeChip(symbol: "exclamationmark.triangle.fill", text: "警報・注意報"), LifeChip(symbol: "antenna.radiowaves.left.and.right", text: "ニュース")],
                scene: .news,
                sentences: [
                    S(id: "typhoon", japanese: "台風が近づいています。", reading: "たいふうがちかづいています。", vi: "Bão đang đến gần.", en: "A typhoon is approaching.",
                      explanationVi: "近づく là “tiến lại gần”; 〜ています: đang.", explanationEn: "近づく means “to approach”; 〜ています: ongoing."),
                    S(id: "wind", japanese: "強い風に注意してください。", reading: "つよいかぜにちゅういしてください。", vi: "Hãy chú ý gió mạnh.", en: "Please watch out for strong winds.",
                      explanationVi: "〜に注意してください: “hãy chú ý tới…”.", explanationEn: "〜に注意してください: “please be careful of …”."),
                    S(id: "out", japanese: "不要な外出は控えてください。", reading: "ふようながいしゅつはひかえてください。", vi: "Hãy hạn chế ra ngoài không cần thiết.", en: "Please refrain from unnecessary outings.",
                      explanationVi: "控える là “hạn chế, kiềm chế” — rất hay gặp trong bản tin.", explanationEn: "控える means “to refrain” — very common in news.")
                ],
                words: [
                    W(id: "sample:news:typhoon", japanese: "台風", reading: "たいふう", vi: "bão", en: "typhoon", example: "台風が近づいています。"),
                    W(id: "sample:news:warning", japanese: "警報", reading: "けいほう", vi: "cảnh báo", en: "warning", example: "大雨警報が出ています。"),
                    W(id: "sample:news:evacuate", japanese: "避難", reading: "ひなん", vi: "sơ tán", en: "evacuation", example: "避難してください。"),
                    W(id: "sample:news:caution", japanese: "注意", reading: "ちゅうい", vi: "chú ý", en: "caution", example: "強い風に注意してください。")
                ],
                recall: .init(promptJapanese: "＿＿が近づいています。", cueVi: "Gõ từ tiếng Nhật chỉ “bão”.", cueEn: "Type the Japanese word for “typhoon”.",
                              accepted: ["台風", "たいふう"], explanationVi: "Đáp án: 台風 (たいふう) — bão.", explanationEn: "Answer: 台風 (たいふう) — typhoon."),
                choice: .init(promptJapanese: "警報", promptVi: "“警報” đọc là gì?", promptEn: "How do you read “警報”?", options: ["けいぼう", "きょうほう", "けいほう"], correct: 2,
                              explanationVi: "警報 đọc là けいほう (cảnh báo).", explanationEn: "警報 is read けいほう (warning)."), level: "N3")
        case .food:
            return LifeLessonDraft(
                id: "sample:food", topic: .food, provenance: .sample,
                titleJapanese: "ラーメンを注文する", titleReading: "ラーメンをちゅうもんする", titleVi: "Gọi mì ramen", titleEn: "Ordering ramen",
                providerName: provider,
                chips: [LifeChip(symbol: "fork.knife", text: "ラーメン 900円"), LifeChip(symbol: "plus.circle.fill", text: "大盛り +100円")],
                scene: .food,
                sentences: [
                    S(id: "order", japanese: "ラーメンを一つください。", reading: "ラーメンをひとつください。", vi: "Cho tôi một bát ramen.", en: "One ramen, please.",
                      explanationVi: "〜をください: “cho tôi…”; 一つ (ひとつ) là “một cái”.", explanationEn: "〜をください: “please give me …”; 一つ (ひとつ) is “one (thing)”."),
                    S(id: "large", japanese: "大盛りでお願いします。", reading: "おおもりでおねがいします。", vi: "Cho tôi suất lớn.", en: "A large portion, please.",
                      explanationVi: "大盛り là suất nhiều hơn bình thường.", explanationEn: "大盛り is a bigger-than-normal portion."),
                    S(id: "water", japanese: "お水はセルフです。", reading: "おみずはセルフです。", vi: "Nước uống thì tự phục vụ.", en: "Water is self-service.",
                      explanationVi: "セルフ (self) là “tự phục vụ”.", explanationEn: "セルフ (self) means self-service.")
                ],
                words: [
                    W(id: "sample:food:order", japanese: "注文", reading: "ちゅうもん", vi: "gọi món", en: "order", example: "ラーメンを注文します。"),
                    W(id: "sample:food:large", japanese: "大盛り", reading: "おおもり", vi: "suất lớn", en: "large portion", example: "大盛りでお願いします。"),
                    W(id: "sample:food:one", japanese: "一つ", reading: "ひとつ", vi: "một cái", en: "one (thing)", example: "ラーメンを一つください。"),
                    W(id: "sample:food:water", japanese: "お水", reading: "おみず", vi: "nước", en: "water", example: "お水はセルフです。")
                ],
                recall: .init(promptJapanese: "ラーメンを＿＿ください。", cueVi: "Gõ “một cái” (cách đếm đồ vật).", cueEn: "Type “one (thing)” in the general counting form.",
                              accepted: ["一つ", "ひとつ", "1つ"], explanationVi: "Đáp án: 一つ (ひとつ).", explanationEn: "Answer: 一つ (ひとつ)."),
                choice: .init(promptJapanese: "大盛り", promptVi: "“大盛り” đọc là gì?", promptEn: "How do you read “大盛り”?", options: ["だいもり", "おおもり", "おおぼり"], correct: 1,
                              explanationVi: "大盛り đọc là おおもり (suất lớn).", explanationEn: "大盛り is read おおもり (large portion)."), level: "N4")
        case .culture:
            return LifeLessonDraft(
                id: "sample:culture", topic: .culture, provenance: .sample,
                titleJapanese: "紅葉がきれいです", titleReading: "こうようがきれいです", titleVi: "Lá đỏ thật đẹp", titleEn: "The autumn leaves are beautiful",
                providerName: provider,
                chips: [LifeChip(symbol: "leaf.fill", text: "紅葉"), LifeChip(symbol: "calendar", text: "十一月が見ごろ")],
                scene: .culture,
                sentences: [
                    S(id: "leaves", japanese: "紅葉がきれいです。", reading: "こうようがきれいです。", vi: "Lá đỏ thật đẹp.", en: "The autumn leaves are beautiful.",
                      explanationVi: "紅葉 còn đọc là もみじ khi nói về lá phong.", explanationEn: "紅葉 can also be read もみじ for maple leaves."),
                    S(id: "season", japanese: "秋は紅葉の季節です。", reading: "あきはこうようのきせつです。", vi: "Mùa thu là mùa lá đỏ.", en: "Autumn is the season for red leaves.",
                      explanationVi: "A の B: B của A — ở đây “mùa của lá đỏ”.", explanationEn: "A の B: B of A — here “the season of red leaves”."),
                    S(id: "trip", japanese: "週末に京都へ行きましょう。", reading: "しゅうまつにきょうとへいきましょう。", vi: "Cuối tuần mình cùng đi Kyoto nhé.", en: "Let's go to Kyoto this weekend.",
                      explanationVi: "〜ましょう: rủ “cùng… nhé”.", explanationEn: "〜ましょう: “let's …”.", isAdvice: true)
                ],
                words: [
                    W(id: "sample:culture:leaves", japanese: "紅葉", reading: "こうよう", vi: "lá đỏ mùa thu", en: "autumn leaves", example: "紅葉がきれいです。"),
                    W(id: "sample:culture:season", japanese: "季節", reading: "きせつ", vi: "mùa", en: "season", example: "秋は紅葉の季節です。"),
                    W(id: "sample:culture:weekend", japanese: "週末", reading: "しゅうまつ", vi: "cuối tuần", en: "weekend", example: "週末に京都へ行きましょう。"),
                    W(id: "sample:culture:peak", japanese: "見ごろ", reading: "みごろ", vi: "thời điểm đẹp nhất để ngắm", en: "the best time to see", example: "今が見ごろです。")
                ],
                recall: .init(promptJapanese: "＿＿がきれいです。", cueVi: "Gõ từ chỉ “lá đỏ mùa thu”.", cueEn: "Type the word for “autumn leaves”.",
                              accepted: ["紅葉", "こうよう", "もみじ"], explanationVi: "Đáp án: 紅葉 (こうよう / もみじ).", explanationEn: "Answer: 紅葉 (こうよう / もみじ)."),
                choice: .init(promptJapanese: "季節", promptVi: "“季節” đọc là gì?", promptEn: "How do you read “季節”?", options: ["きぜつ", "きせい", "きせつ"], correct: 2,
                              explanationVi: "季節 đọc là きせつ (mùa).", explanationEn: "季節 is read きせつ (season)."), level: "N4")
        case .money:
            return LifeLessonDraft(
                id: "sample:money", topic: .money, provenance: .sample,
                titleJapanese: "円高と円安", titleReading: "えんだかとえんやす", titleVi: "Yên mạnh và yên yếu (giải thích)", titleEn: "Strong and weak yen (explainer)",
                providerName: provider,
                chips: [LifeChip(symbol: "book.fill", text: NSLocalizedString("Explainer · not market data", comment: "")),
                        LifeChip(symbol: "hand.raised.fill", text: NSLocalizedString("Not investment advice", comment: ""))],
                scene: .money,
                sentences: [
                    S(id: "weak", japanese: "円安は円の価値が下がることです。", reading: "えんやすはえんのかちがさがることです。", vi: "Yên yếu (円安) nghĩa là giá trị đồng yên giảm.", en: "円安 (weak yen) means the value of the yen falls.",
                      explanationVi: "〜ことです: định nghĩa “việc…”.", explanationEn: "〜ことです: defines “the fact that …”."),
                    S(id: "strong", japanese: "円高は円の価値が上がることです。", reading: "えんだかはえんのかちがあがることです。", vi: "Yên mạnh (円高) nghĩa là giá trị đồng yên tăng.", en: "円高 (strong yen) means the value of the yen rises.",
                      explanationVi: "安 (やす) = rẻ/yếu, 高 (だか) = cao/mạnh.", explanationEn: "安 (やす) = cheap/weak, 高 (だか) = high/strong."),
                    S(id: "change", japanese: "為替は毎日変わります。", reading: "かわせはまいにちかわります。", vi: "Tỷ giá thay đổi mỗi ngày.", en: "Exchange rates change every day.",
                      explanationVi: "為替 là hối đoái/tỷ giá; 毎日 là mỗi ngày.", explanationEn: "為替 is exchange; 毎日 is every day.")
                ],
                words: [
                    W(id: "sample:money:exchange", japanese: "為替", reading: "かわせ", vi: "hối đoái, tỷ giá", en: "exchange rate", example: "為替は毎日変わります。"),
                    W(id: "sample:money:weakyen", japanese: "円安", reading: "えんやす", vi: "yên yếu", en: "weak yen", example: "円安は円の価値が下がることです。"),
                    W(id: "sample:money:strongyen", japanese: "円高", reading: "えんだか", vi: "yên mạnh", en: "strong yen", example: "円高は円の価値が上がることです。"),
                    W(id: "sample:money:value", japanese: "価値", reading: "かち", vi: "giá trị", en: "value", example: "円の価値が下がります。")
                ],
                recall: .init(promptJapanese: "＿＿は円の価値が下がることです。", cueVi: "Gõ từ nghĩa là “yên yếu”.", cueEn: "Type the word for “weak yen”.",
                              accepted: ["円安", "えんやす"], explanationVi: "Đáp án: 円安 (えんやす).", explanationEn: "Answer: 円安 (えんやす)."),
                choice: .init(promptJapanese: "円高", promptVi: "“円高” đọc là gì?", promptEn: "How do you read “円高”?", options: ["えんこう", "えんたか", "えんだか"], correct: 2,
                              explanationVi: "円高 đọc là えんだか (yên mạnh).", explanationEn: "円高 is read えんだか (strong yen)."), level: "N3")
        case .lottery:
            return LifeLessonDraft(
                id: "sample:lottery", topic: .lottery, provenance: .sample,
                titleJapanese: "当選番号を確認する", titleReading: "とうせんばんごうをかくにんする", titleVi: "Kiểm tra số trúng thưởng (giải thích)", titleEn: "Checking winning numbers (explainer)",
                providerName: provider,
                chips: [LifeChip(symbol: "book.fill", text: NSLocalizedString("Explainer · no predictions", comment: "")),
                        LifeChip(symbol: "hand.raised.fill", text: NSLocalizedString("Never a betting link", comment: ""))],
                scene: .lottery,
                sentences: [
                    S(id: "check", japanese: "当選番号を確認します。", reading: "とうせんばんごうをかくにんします。", vi: "Tôi kiểm tra số trúng thưởng.", en: "I check the winning numbers.",
                      explanationVi: "確認します: “xác nhận/kiểm tra”.", explanationEn: "確認します: “to check, to confirm”."),
                    S(id: "weekly", japanese: "抽選は毎週あります。", reading: "ちゅうせんはまいしゅうあります。", vi: "Việc bốc thăm diễn ra hàng tuần.", en: "The draw takes place every week.",
                      explanationVi: "毎週 là “mỗi tuần”.", explanationEn: "毎週 means “every week”."),
                    S(id: "chance", japanese: "番号は偶然で決まります。", reading: "ばんごうはぐうぜんできまります。", vi: "Con số được quyết định bởi ngẫu nhiên.", en: "The numbers are decided by chance.",
                      explanationVi: "Vì do ngẫu nhiên nên không thể dự đoán — ứng dụng không đưa ra dự đoán.", explanationEn: "Because it is chance, it cannot be predicted — this app makes no predictions.")
                ],
                words: [
                    W(id: "sample:lottery:win", japanese: "当選", reading: "とうせん", vi: "trúng thưởng", en: "winning (a draw)", example: "当選番号を確認します。"),
                    W(id: "sample:lottery:draw", japanese: "抽選", reading: "ちゅうせん", vi: "bốc thăm", en: "drawing, lottery", example: "抽選は毎週あります。"),
                    W(id: "sample:lottery:number", japanese: "番号", reading: "ばんごう", vi: "con số, số hiệu", en: "number", example: "当選番号を確認します。"),
                    W(id: "sample:lottery:chance", japanese: "偶然", reading: "ぐうぜん", vi: "ngẫu nhiên", en: "chance, coincidence", example: "番号は偶然で決まります。")
                ],
                recall: .init(promptJapanese: "＿＿番号を確認します。", cueVi: "Gõ từ nghĩa là “trúng thưởng”.", cueEn: "Type the word for “winning”.",
                              accepted: ["当選", "とうせん"], explanationVi: "Đáp án: 当選 (とうせん).", explanationEn: "Answer: 当選 (とうせん)."),
                choice: .init(promptJapanese: "抽選", promptVi: "“抽選” đọc là gì?", promptEn: "How do you read “抽選”?", options: ["ちょうせん", "ちゅうぜん", "ちゅうせん"], correct: 2,
                              explanationVi: "抽選 đọc là ちゅうせん (bốc thăm).", explanationEn: "抽選 is read ちゅうせん (drawing)."), level: "N3")
        default:
            return nil
        }
    }
}
