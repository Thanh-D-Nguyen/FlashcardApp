import Foundation

/// Three cards of the production answer of `GET /api/daily-radar/cards` (2026-11-11, public, unchanged): a `workplace_mission`
/// scenario card with string expressions, a seeded `news_bjt` card with object expressions and a `honne_tatemae` card.
enum DailyRadarFixtures {
    static let productionSample = #"""
[
 {
  "id": "eaa0c67a-e364-490b-b68f-172b5e3e303e",
  "slug": "client-follow-up-email-j2",
  "titleVi": "催促メールが来た — Khách hàng hỏi gấp tiến độ",
  "titleJa": null,
  "descriptionVi": "Khách hàng hỏi “tiến độ sao rồi?”. Bạn chọn cách trả lời lịch sự mà không né trách nhiệm.",
  "category": "work",
  "module": {
   "moduleKey": "workplace_mission",
   "titleJa": "今日の仕事シーン",
   "titleVi": "Tình huống công việc"
  },
  "publishedAt": "2026-10-08T04:31:25.479Z",
  "badgeTextVi": "BJT J2",
  "ctaLabelVi": "Xử lý tình huống",
  "estimatedMinutes": 5,
  "levelLabel": "BJT J2",
  "metadata": {
   "seed": true,
   "skills": [
    "business_email",
    "keigo"
   ],
   "comingSoon": false,
   "errorFocus": "responsibility_misread",
   "focusSkill": "business_email",
   "contentGoal": "Luyện phản hồi email催促 đúng chuẩn công sở Nhật.",
   "scenarioType": "client_email",
   "disclaimerRequired": false,
   "japaneseExpression": "進捗はいかがでしょうか",
   "japaneseExpressions": [
    "進捗はいかがでしょうか",
    "ご連絡ありがとうございます"
   ]
  },
  "moduleType": "scenario_link",
  "recommendationReasonVi": "Vì email 催促 là tình huống rất thường gặp khi làm việc với người Nhật.",
  "targetRoute": "/vi/story/arcs",
  "visualTheme": "blue_corporate",
  "title": "催促メールが来た — Khách hàng hỏi gấp tiến độ",
  "summary": "Khách hàng hỏi “tiến độ sao rồi?”. Bạn chọn cách trả lời lịch sự mà không né trách nhiệm.",
  "moduleKey": "workplace_mission"
 },
 {
  "id": "9d9ea283-30f8-471e-89a5-c08fad403bc4",
  "slug": "news-headline-patterns",
  "titleVi": "ニュース見出し — Đọc tiêu đề tin tức",
  "titleJa": "ニュース見出しの読み方",
  "descriptionVi": "6 mẫu tiêu đề tin NHK/Nikkei thường gặp — đọc nhanh hiểu ngay.",
  "category": "news",
  "module": {
   "moduleKey": "news_bjt",
   "titleJa": "ニュースでBJT",
   "titleVi": "News → BJT"
  },
  "publishedAt": "2026-10-26T00:59:58.826315Z",
  "badgeTextVi": null,
  "ctaLabelVi": "Học ngay",
  "estimatedMinutes": 5,
  "levelLabel": "N2-N1",
  "metadata": {
   "seed": true,
   "skills": [
    "news_reading",
    "headline_grammar",
    "formal_written"
   ],
   "usageNote": "Tiêu đề tin Nhật dùng ngữ pháp rút gọn: bỏ trợ từ, dùng thể từ điển, thay です/ます bằng danh từ hóa. Khác hoàn toàn văn nói. BJT Reading kiểm tra kỹ năng này.",
   "contentGoal": "Đọc hiểu 6 mẫu tiêu đề tin tiếng Nhật — ngữ pháp rút gọn đặc biệt.",
   "japaneseExpressions": [
    {
     "word": "〜へ",
     "example": "日経平均、4万円台へ",
     "meaning": "→ (hướng đến, sắp xảy ra)",
     "reading": "〜へ",
     "jlptLevel": "N2",
     "usageNote": "Tiêu đề: ～へ = sắp đạt đến / hướng đến. Không cần động từ.",
     "exampleMeaning": "Nikkei hướng đến mốc 40,000 yên",
     "exampleReading": "にっけいへいきん、よんまんえんだいへ"
    },
    {
     "word": "〜か",
     "example": "利上げ、来月か",
     "meaning": "~ chăng? (đặt câu hỏi/phỏng đoán)",
     "reading": "〜か",
     "jlptLevel": "N3",
     "usageNote": "か ở cuối tiêu đề = chưa chắc chắn, dự đoán. Hay thấy trong tin kinh tế.",
     "exampleMeaning": "Tăng lãi suất, tháng sau chăng?",
     "exampleReading": "りあげ、らいげつか"
    },
    {
     "word": "〜見通し",
     "example": "GDP成長率2%の見通し",
     "meaning": "Triển vọng ~, dự báo ~",
     "reading": "〜みとおし",
     "jlptLevel": "N2",
     "usageNote": "見通し = outlook/forecast. Tin kinh tế dùng CỰC NHIỀU.",
     "exampleMeaning": "Triển vọng tăng trưởng GDP 2%",
     "exampleReading": "GDPせいちょうりつにパーセントのみとおし"
    },
    {
     "word": "〜を受け",
     "example": "円安を受け、輸出企業が最高益",
     "meaning": "Sau khi ~, do ~ (nguyên nhân)",
     "reading": "〜をうけ",
     "jlptLevel": "N2",
     "usageNote": "〜を受け = vì/do (formal written). Dùng trong tin tức + văn bản BJT.",
     "exampleMeaning": "Do yên yếu, doanh nghiệp xuất khẩu lãi kỷ lục",
     "exampleReading": "えんやすをうけ、ゆしゅつきぎょうがさいこうえき"
    },
    {
     "word": "〜相次ぐ",
     "example": "大手企業、賃上げ表明相次ぐ",
     "meaning": "Liên tiếp xảy ra ~",
     "reading": "〜あいつぐ",
     "jlptLevel": "N2",
     "usageNote": "相次ぐ = one after another. Tin tức dùng khi xu hướng lan rộng.",
     "exampleMeaning": "Doanh nghiệp lớn liên tiếp tuyên bố tăng lương",
     "exampleReading": "おおてきぎょう、ちんあげひょうめいあいつぐ"
    },
    {
     "word": "〜初",
     "example": "過去最高を更新、史上初の5万円台",
     "meaning": "Lần đầu tiên ~ (kỷ lục)",
     "reading": "〜はつ/はじめて",
     "jlptLevel": "N3",
     "usageNote": "史上初 (しじょうはつ) = lần đầu trong lịch sử. 過去最高 = cao nhất từ trước đến nay.",
     "exampleMeaning": "Phá kỷ lục, lần đầu trong lịch sử vượt 50,000 yên",
     "exampleReading": "かこさいこうをこうしん、しじょうはつのごまんえんだい"
    }
   ]
  },
  "moduleType": "content",
  "recommendationReasonVi": "BJT Reading Part 1 thường dùng tiêu đề tin kinh tế/xã hội.",
  "targetRoute": null,
  "visualTheme": "amber_news",
  "title": "ニュース見出し — Đọc tiêu đề tin tức",
  "summary": "6 mẫu tiêu đề tin NHK/Nikkei thường gặp — đọc nhanh hiểu ngay.",
  "moduleKey": "news_bjt"
 },
 {
  "id": "a0e8be97-c1b8-4b56-86cc-48476712933f",
  "slug": "kentou-shimasu-real-meaning",
  "titleVi": "「検討します」は đồng ý hay từ chối?",
  "titleJa": null,
  "descriptionVi": "Học cách phân biệt khi nào “sẽ cân nhắc” là thiện chí thật, khi nào là từ chối mềm.",
  "category": "work",
  "module": {
   "moduleKey": "honne_tatemae",
   "titleJa": "本音と建前",
   "titleVi": "Đọc ẩn ý tiếng Nhật"
  },
  "publishedAt": "2026-10-08T04:31:25.498Z",
  "badgeTextVi": "本音建前",
  "ctaLabelVi": "Đọc ẩn ý",
  "estimatedMinutes": 4,
  "levelLabel": "N2+",
  "metadata": {
   "seed": true,
   "skills": [
    "implied_meaning",
    "honne_tatemae"
   ],
   "comingSoon": false,
   "focusSkill": "nuance",
   "contentGoal": "Phân biệt tín hiệu đồng ý thật và từ chối mềm.",
   "scenarioType": "meeting",
   "disclaimerRequired": false,
   "japaneseExpressions": [
    "検討します",
    "前向きに検討します"
   ]
  },
  "moduleType": "content",
  "recommendationReasonVi": "Đây là bẫy 本音・建前 kinh điển trong công ty Nhật.",
  "targetRoute": "/vi/modules/honne_tatemae",
  "visualTheme": "indigo_culture",
  "title": "「検討します」は đồng ý hay từ chối?",
  "summary": "Học cách phân biệt khi nào “sẽ cân nhắc” là thiện chí thật, khi nào là từ chối mềm.",
  "moduleKey": "honne_tatemae"
 }
]
"""#
}
