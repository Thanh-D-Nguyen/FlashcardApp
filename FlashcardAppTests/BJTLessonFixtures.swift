import Foundation

/// Responses captured from production (`https://kiokoto.com/api`, 2026-11-11), anonymous GET, no secrets. The list keeps
/// three of the 84 J5 rows (a lesson, a weekly review and a checkpoint); the detail is `j5-01-greetings-intro` unchanged.
/// Tests derive variations from these instead of inventing payloads.
enum BJTLessonFixtures {
    static let j5ListJSON = #"""
[
  {
    "activityCount": 5,
    "descriptionJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 おはようございます。",
    "descriptionVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm là Chào buổi sáng.",
    "estimatedDurationMin": 25,
    "grammarCount": 2,
    "id": "bdf97bd4-6318-409c-991b-b076526d6c28",
    "isCompleted": false,
    "kanjiCount": 0,
    "slug": "j5-01-greetings-intro",
    "sortOrder": 1,
    "titleJa": "職場の挨拶：おはようございます。",
    "titleVi": "Chào hỏi tại nơi làm việc: Chào buổi sáng",
    "unitOrder": 1,
    "unitType": "lesson",
    "vocabCount": 6,
    "weekNumber": 1
  },
  {
    "activityCount": 8,
    "descriptionJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 職場の挨拶の内容を総合的に確認します。",
    "descriptionVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm là tổng hợp Chào hỏi tại nơi làm việc.",
    "estimatedDurationMin": 30,
    "grammarCount": 2,
    "id": "14848554-686f-4bd4-b4f0-c22b062f1802",
    "isCompleted": false,
    "kanjiCount": 0,
    "slug": "j5-w01-review",
    "sortOrder": 6,
    "titleJa": "職場の挨拶：週間復習",
    "titleVi": "Chào hỏi tại nơi làm việc: Ôn tập tuần",
    "unitOrder": 6,
    "unitType": "review",
    "vocabCount": 6,
    "weekNumber": 1
  },
  {
    "activityCount": 10,
    "descriptionJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 職場の挨拶の内容を総合的に確認します。",
    "descriptionVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm là tổng hợp Chào hỏi tại nơi làm việc.",
    "estimatedDurationMin": 35,
    "grammarCount": 2,
    "id": "8df79f98-6217-4675-b43d-48744fdd243b",
    "isCompleted": false,
    "kanjiCount": 0,
    "slug": "j5-w01-checkpoint",
    "sortOrder": 7,
    "titleJa": "職場の挨拶：実務チェック",
    "titleVi": "Chào hỏi tại nơi làm việc: Checkpoint thực hành",
    "unitOrder": 7,
    "unitType": "checkpoint",
    "vocabCount": 6,
    "weekNumber": 1
  }
]
"""#

    static let j5Lesson01JSON = #"""
{
  "businessTopics": [
    "workplace-introduction"
  ],
  "canSaveProgress": false,
  "contentVersion": "2026.07.2",
  "contents": [],
  "descriptionJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 おはようございます。",
  "descriptionVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm là Chào buổi sáng.",
  "difficulty": "foundation",
  "estimatedDurationMin": 25,
  "id": "bdf97bd4-6318-409c-991b-b076526d6c28",
  "isCompleted": false,
  "lessonContent": {
    "activities": [
      {
        "answer": "A",
        "audioAssetStatus": "not_required",
        "audioProvider": null,
        "audioScript": null,
        "audioUrl": null,
        "audioVersion": null,
        "audioVoice": null,
        "businessTopic": "workplace-introduction",
        "difficulty": "foundation",
        "explanationJa": "この場面では「おはようございます。」が、相手との関係を保ちながら目的を明確に伝える表現です。",
        "explanationVi": "“おはようございます。” phù hợp nhất vì Dùng khi gặp đồng nghiệp vào buổi sáng; nói rõ và vừa đủ trang trọng.. Các lựa chọn khác không sai trong mọi hoàn cảnh, nhưng lệch vai trò, sắc thái hoặc hành động cần thiết ở đây.",
        "id": "act-j5-w01-u1-01",
        "options": [
          {
            "isCorrect": true,
            "key": "A",
            "rationaleVi": "Đúng vì biểu đạt này thực hiện chính xác mục đích “chào khi bắt đầu ngày làm việc” và phù hợp quan hệ senior-junior.",
            "text": "おはようございます。"
          },
          {
            "isCorrect": false,
            "key": "B",
            "rationaleVi": "Có thể đúng ngữ pháp nhưng lệch mục đích giao tiếp cần đạt trong tình huống.",
            "text": "初めまして、グエンです。"
          },
          {
            "isCorrect": false,
            "key": "C",
            "rationaleVi": "Mức độ lịch sự hoặc phạm vi trách nhiệm không phù hợp với quan hệ giữa hai bên.",
            "text": "ベトナムから来ました。"
          },
          {
            "isCorrect": false,
            "key": "D",
            "rationaleVi": "Phản hồi chưa xử lý vấn đề hiện tại hoặc dễ tạo cách hiểu khác cho đối phương.",
            "text": "今日からよろしくお願いします。"
          }
        ],
        "prompt": "表現の意味と場面を見分ける段階です。「ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。」で、目的を明確に伝えるために最も適切な表現はどれですか。",
        "promptVi": "Đây là bước nhận diện ý nghĩa và tình huống. Trong tình huống “Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu.”, cách nói nào phù hợp nhất để chào khi bắt đầu ngày làm việc?",
        "questionType": "best_expression",
        "relationship": "senior-junior",
        "scenarioJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 表現の意味と場面を見分ける段階として「おはようございます。」の使い方を判断します。",
        "scenarioVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Ở bước nhận diện ý nghĩa và tình huống, câu này yêu cầu xử lý mục đích “chào khi bắt đầu ngày làm việc”.",
        "skillTag": "greeting",
        "stimulusText": "新入社員：おはようございます。\n先輩：はい、わかりました。",
        "stimulusType": "dialogue"
      },
      {
        "answer": "B",
        "audioAssetStatus": "not_required",
        "audioProvider": null,
        "audioScript": null,
        "audioUrl": null,
        "audioVersion": null,
        "audioVoice": null,
        "businessTopic": "workplace-introduction",
        "difficulty": "foundation",
        "explanationJa": "この場面では「初めまして、グエンです。」が、相手との関係を保ちながら目的を明確に伝える表現です。",
        "explanationVi": "“初めまして、グエンです。” phù hợp nhất vì 初めまして chỉ dùng trong lần gặp đầu tiên.. Các lựa chọn khác không sai trong mọi hoàn cảnh, nhưng lệch vai trò, sắc thái hoặc hành động cần thiết ở đây.",
        "id": "act-j5-w01-u1-02",
        "options": [
          {
            "isCorrect": false,
            "key": "A",
            "rationaleVi": "Có thể đúng ngữ pháp nhưng lệch mục đích giao tiếp cần đạt trong tình huống.",
            "text": "ベトナムから来ました。"
          },
          {
            "isCorrect": true,
            "key": "B",
            "rationaleVi": "Đúng vì biểu đạt này thực hiện chính xác mục đích “tự giới thiệu tên lần đầu” và phù hợp quan hệ senior-junior.",
            "text": "初めまして、グエンです。"
          },
          {
            "isCorrect": false,
            "key": "C",
            "rationaleVi": "Mức độ lịch sự hoặc phạm vi trách nhiệm không phù hợp với quan hệ giữa hai bên.",
            "text": "今日からよろしくお願いします。"
          },
          {
            "isCorrect": false,
            "key": "D",
            "rationaleVi": "Phản hồi chưa xử lý vấn đề hiện tại hoặc dễ tạo cách hiểu khác cho đối phương.",
            "text": "お先に失礼します。"
          }
        ],
        "prompt": "表現の意味と場面を見分ける段階です。職場の挨拶の場面で必要な表現を完成させます。「＿＿＿＿」に入る最も自然な表現を選んでください。",
        "promptVi": "Ở bước nhận diện ý nghĩa và tình huống trong Chào hỏi tại nơi làm việc, cần tự giới thiệu tên lần đầu. Hãy chọn biểu đạt tự nhiên nhất cho chỗ trống.",
        "questionType": "fill_phrase",
        "relationship": "senior-junior",
        "scenarioJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 表現の意味と場面を見分ける段階として「初めまして、グエンです。」の使い方を判断します。",
        "scenarioVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Ở bước nhận diện ý nghĩa và tình huống, câu này yêu cầu xử lý mục đích “tự giới thiệu tên lần đầu”.",
        "skillTag": "self-introduction",
        "stimulusText": "新入社員：初めまして、グエンです。\n先輩：はい、わかりました。",
        "stimulusType": "dialogue"
      },
      {
        "answer": "C",
        "audioAssetStatus": "tts_ready",
        "audioProvider": "browser_tts",
        "audioScript": "新入社員：ベトナムから来ました。\n先輩：はい、わかりました。",
        "audioUrl": null,
        "audioVersion": "tts-v1",
        "audioVoice": "ja-JP-default",
        "businessTopic": "workplace-introduction",
        "difficulty": "foundation",
        "explanationJa": "この場面では「ベトナムから来ました。」が、相手との関係を保ちながら目的を明確に伝える表現です。",
        "explanationVi": "“ベトナムから来ました。” phù hợp nhất vì Không cần thêm 私は nếu ngữ cảnh đã rõ.. Các lựa chọn khác không sai trong mọi hoàn cảnh, nhưng lệch vai trò, sắc thái hoặc hành động cần thiết ở đây.",
        "id": "act-j5-w01-u1-03",
        "options": [
          {
            "isCorrect": false,
            "key": "A",
            "rationaleVi": "Có thể đúng ngữ pháp nhưng lệch mục đích giao tiếp cần đạt trong tình huống.",
            "text": "はい、確認します。"
          },
          {
            "isCorrect": false,
            "key": "B",
            "rationaleVi": "Mức độ lịch sự hoặc phạm vi trách nhiệm không phù hợp với quan hệ giữa hai bên.",
            "text": "はい、少し待ってください。"
          },
          {
            "isCorrect": true,
            "key": "C",
            "rationaleVi": "Đúng vì biểu đạt này thực hiện chính xác mục đích “nói ngắn gọn về xuất thân” và phù hợp quan hệ senior-junior.",
            "text": "はい、わかりました。"
          },
          {
            "isCorrect": false,
            "key": "D",
            "rationaleVi": "Phản hồi chưa xử lý vấn đề hiện tại hoặc dễ tạo cách hiểu khác cho đối phương.",
            "text": "すみません、もう一度お願いします。"
          }
        ],
        "prompt": "表現の意味と場面を見分ける段階で、先輩から「ベトナムから来ました。」と言われました。最も適切な応答を選んでください。",
        "promptVi": "Ở bước nhận diện ý nghĩa và tình huống, 先輩 nói “ベトナムから来ました。”. Hãy chọn phản hồi phù hợp nhất với vai trò.",
        "questionType": "role_response",
        "relationship": "senior-junior",
        "scenarioJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 表現の意味と場面を見分ける段階として「ベトナムから来ました。」の使い方を判断します。",
        "scenarioVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Ở bước nhận diện ý nghĩa và tình huống, câu này yêu cầu xử lý mục đích “nói ngắn gọn về xuất thân”.",
        "skillTag": "closing",
        "stimulusText": "新入社員：ベトナムから来ました。\n先輩：はい、わかりました。",
        "stimulusType": "telephone"
      },
      {
        "answer": "D",
        "audioAssetStatus": "not_required",
        "audioProvider": null,
        "audioScript": null,
        "audioUrl": null,
        "audioVersion": null,
        "audioVoice": null,
        "businessTopic": "workplace-introduction",
        "difficulty": "foundation",
        "explanationJa": "この場面では「今日からよろしくお願いします。」が、相手との関係を保ちながら目的を明確に伝える表現です。",
        "explanationVi": "“今日からよろしくお願いします。” phù hợp nhất vì Câu kết tự nhiên cho lời chào ngày đầu.. Các lựa chọn khác không sai trong mọi hoàn cảnh, nhưng lệch vai trò, sắc thái hoặc hành động cần thiết ở đây.",
        "id": "act-j5-w01-u1-04",
        "options": [
          {
            "isCorrect": false,
            "key": "A",
            "rationaleVi": "Có thể đúng ngữ pháp nhưng lệch mục đích giao tiếp cần đạt trong tình huống.",
            "text": "お先に失礼します。"
          },
          {
            "isCorrect": false,
            "key": "B",
            "rationaleVi": "Mức độ lịch sự hoặc phạm vi trách nhiệm không phù hợp với quan hệ giữa hai bên.",
            "text": "おはようございます。"
          },
          {
            "isCorrect": false,
            "key": "C",
            "rationaleVi": "Phản hồi chưa xử lý vấn đề hiện tại hoặc dễ tạo cách hiểu khác cho đối phương.",
            "text": "初めまして、グエンです。"
          },
          {
            "isCorrect": true,
            "key": "D",
            "rationaleVi": "Đúng vì biểu đạt này thực hiện chính xác mục đích “bày tỏ mong muốn hợp tác” và phù hợp quan hệ senior-junior.",
            "text": "今日からよろしくお願いします。"
          }
        ],
        "prompt": "表現の意味と場面を見分ける段階です。相手との立場の違いを踏まえ、失礼にならず意図を明確に伝えられる表現を選んでください。",
        "promptVi": "Ở bước nhận diện ý nghĩa và tình huống với quan hệ senior-junior, chọn cách nói vừa rõ ý vừa không thất lễ khi cần bày tỏ mong muốn hợp tác.",
        "questionType": "politeness_check",
        "relationship": "senior-junior",
        "scenarioJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 表現の意味と場面を見分ける段階として「今日からよろしくお願いします。」の使い方を判断します。",
        "scenarioVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Ở bước nhận diện ý nghĩa và tình huống, câu này yêu cầu xử lý mục đích “bày tỏ mong muốn hợp tác”.",
        "skillTag": "greeting",
        "stimulusText": "新入社員：今日からよろしくお願いします。\n先輩：はい、わかりました。",
        "stimulusType": "dialogue"
      },
      {
        "answer": "A",
        "audioAssetStatus": "not_required",
        "audioProvider": null,
        "audioScript": null,
        "audioUrl": null,
        "audioVersion": null,
        "audioVoice": null,
        "businessTopic": "workplace-introduction",
        "difficulty": "foundation",
        "explanationJa": "この場面では「お先に失礼します。」が、相手との関係を保ちながら目的を明確に伝える表現です。",
        "explanationVi": "“お先に失礼します。” phù hợp nhất vì Nói với người còn ở lại, không dùng như lời chào khi đến.. Các lựa chọn khác không sai trong mọi hoàn cảnh, nhưng lệch vai trò, sắc thái hoặc hành động cần thiết ở đây.",
        "id": "act-j5-w01-u1-05",
        "options": [
          {
            "isCorrect": true,
            "key": "A",
            "rationaleVi": "Đúng vì biểu đạt này thực hiện chính xác mục đích “xin phép rời nơi làm việc” và phù hợp quan hệ senior-junior.",
            "text": "xin phép rời nơi làm việc"
          },
          {
            "isCorrect": false,
            "key": "B",
            "rationaleVi": "Có thể đúng ngữ pháp nhưng lệch mục đích giao tiếp cần đạt trong tình huống.",
            "text": "chào khi bắt đầu ngày làm việc"
          },
          {
            "isCorrect": false,
            "key": "C",
            "rationaleVi": "Mức độ lịch sự hoặc phạm vi trách nhiệm không phù hợp với quan hệ giữa hai bên.",
            "text": "tự giới thiệu tên lần đầu"
          },
          {
            "isCorrect": false,
            "key": "D",
            "rationaleVi": "Phản hồi chưa xử lý vấn đề hiện tại hoặc dễ tạo cách hiểu khác cho đối phương.",
            "text": "nói ngắn gọn về xuất thân"
          }
        ],
        "prompt": "表現の意味と場面を見分ける段階です。発言「お先に失礼します。」で、話し手が最も達成したいことは何ですか。",
        "promptVi": "Ở bước nhận diện ý nghĩa và tình huống, với phát ngôn “お先に失礼します。”, mục đích chính của người nói là gì?",
        "questionType": "mini_case_inference",
        "relationship": "senior-junior",
        "scenarioJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 表現の意味と場面を見分ける段階として「お先に失礼します。」の使い方を判断します。",
        "scenarioVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Ở bước nhận diện ý nghĩa và tình huống, câu này yêu cầu xử lý mục đích “xin phép rời nơi làm việc”.",
        "skillTag": "self-introduction",
        "stimulusText": "新入社員：お先に失礼します。\n先輩：はい、わかりました。",
        "stimulusType": "dialogue"
      }
    ],
    "analytics": {
      "assessmentMode": "guided",
      "expectedMinutes": 25,
      "recommendationTopics": [
        "workplace-introduction",
        "dialogue",
        "senior-junior"
      ],
      "skillTags": [
        "greeting",
        "self-introduction",
        "closing"
      ]
    },
    "businessUsageVi": "Dùng trong Chào hỏi tại nơi làm việc khi người học cần tạo thiện cảm nhưng chưa biết vai trò của từng người. Người học cần nêu hành động hoặc trách nhiệm đủ rõ, đồng thời giữ khoảng cách phù hợp với senior-junior.",
    "examples": [
      {
        "japanese": "新入社員：おはようございます。",
        "noteVi": "Dùng khi gặp đồng nghiệp vào buổi sáng; nói rõ và vừa đủ trang trọng.",
        "vietnamese": "新入社員: Chào buổi sáng."
      },
      {
        "japanese": "先輩：はい、わかりました。",
        "noteVi": "Phản hồi không chỉ xác nhận đã nghe mà còn cho biết hành động tiếp theo.",
        "vietnamese": "先輩: Đã hiểu; sẽ xác nhận và phản hồi theo đúng trách nhiệm."
      },
      {
        "japanese": "職場の挨拶の件、おはようございます。\nよろしくお願いします。",
        "noteVi": "Khi chuyển sang văn viết, cần nêu rõ chủ đề trước rồi mới đưa yêu cầu hoặc kết luận.",
        "vietnamese": "Về việc Chào hỏi tại nơi làm việc: Chào buổi sáng."
      }
    ],
    "grammar": [
      {
        "explanationVi": "Giới thiệu danh tính hoặc thông tin một cách lịch sự.",
        "pattern": "～です"
      },
      {
        "explanationVi": "Nói nơi mình đến từ.",
        "pattern": "～から来ました"
      }
    ],
    "knowledgePoints": [
      "Trọng tâm: おはようございます。 — Chào buổi sáng.",
      "Kênh giao tiếp: dialogue; quan hệ: senior-junior.",
      "Register mục tiêu của J5: câu ngắn, です／ます rõ ràng; xác nhận trực tiếp nhưng mềm."
    ],
    "learningObjectives": [
      "Chào, tự giới thiệu và kết thúc trao đổi ngắn đúng thời điểm.",
      "Nhận biết và sử dụng “おはようございます。” đúng vai trò, kênh giao tiếp và mức độ lịch sự.",
      "Hoàn thành hoạt động lựa chọn, phản hồi, sửa lỗi và suy luận trong một phiên học độc lập."
    ],
    "nuanceNotesVi": [
      "Dùng khi gặp đồng nghiệp vào buổi sáng; nói rõ và vừa đủ trang trọng.",
      "Cùng một câu có thể thay đổi mức độ phù hợp tùy người nghe, thời điểm và trách nhiệm của người nói.",
      "Trong môi trường Nhật, nói giảm nhẹ không đồng nghĩa với né tránh: hành động tiếp theo vẫn phải cụ thể."
    ],
    "politenessHierarchyVi": "Với quan hệ senior-junior, ưu tiên câu ngắn, です／ます rõ ràng; xác nhận trực tiếp nhưng mềm. Tránh dùng kính ngữ hướng sai chủ thể hoặc lịch sự quá mức khiến trách nhiệm trở nên mơ hồ.",
    "schemaVersion": "bjt-lesson-document-v1",
    "summaryVi": [
      "Nắm được mục đích và sắc thái của “おはようございます。”.",
      "Phân biệt lựa chọn phù hợp trong chủ đề Chào hỏi tại nơi làm việc.",
      "Có thể xác nhận trách nhiệm và bước tiếp theo mà không làm mất thể diện của đối phương."
    ],
    "vietnameseLearnerPitfalls": [
      "Dịch từng chữ từ tiếng Việt và đặt chủ ngữ quá nhiều làm câu cứng, thiếu tự nhiên.",
      "Chỉ nói 「はい」 nhưng không xác nhận phạm vi, thời hạn hoặc bước tiếp theo.",
      "Dùng “おはようございます。” ở sai quan hệ quyền lực hoặc sai kênh giao tiếp."
    ],
    "vocabulary": [
      {
        "japanese": "初めまして",
        "meaningVi": "rất hân hạnh",
        "reading": "はじめまして"
      },
      {
        "japanese": "新入社員",
        "meaningVi": "nhân viên mới",
        "reading": "しんにゅうしゃいん"
      },
      {
        "japanese": "部署",
        "meaningVi": "phòng ban",
        "reading": "ぶしょ"
      },
      {
        "japanese": "名前",
        "meaningVi": "tên",
        "reading": "なまえ"
      },
      {
        "japanese": "今日",
        "meaningVi": "hôm nay",
        "reading": "きょう"
      },
      {
        "japanese": "よろしく",
        "meaningVi": "mong được giúp đỡ",
        "reading": "よろしく"
      }
    ],
    "workplaceScenario": {
      "contextJa": "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 本時の焦点は「おはようございます。」です。",
      "contextVi": "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm của đơn vị là “Chào buổi sáng”.",
      "counterpart": "先輩",
      "desiredOutcomeVi": "đối phương hiểu tên, bộ phận và mong muốn hợp tác của người nói.",
      "goalVi": "chào khi bắt đầu ngày làm việc",
      "problemVi": "người học cần tạo thiện cảm nhưng chưa biết vai trò của từng người.",
      "relationship": "senior-junior",
      "who": "新入社員"
    }
  },
  "levelCode": "J5",
  "nextLesson": {
    "slug": "j5-02-office-daily",
    "sortOrder": 2,
    "titleVi": "Chào hỏi tại nơi làm việc: Rất hân hạnh, tôi là Nguyễn"
  },
  "prevLesson": null,
  "skillTags": [
    "greeting",
    "self-introduction",
    "closing"
  ],
  "slug": "j5-01-greetings-intro",
  "sortOrder": 1,
  "titleJa": "職場の挨拶：おはようございます。",
  "titleVi": "Chào hỏi tại nơi làm việc: Chào buổi sáng",
  "unitOrder": 1,
  "unitType": "lesson",
  "weekNumber": 1
}
"""#
}
