# Lesson content gate — sample of J5…J1 (2026-11-11)

**Method:** read-only `GET https://kiokoto.com/api/levels/{J5…J1}/lessons` (84 lessons each, 420 total) and
`GET /levels/lessons/{slug}` for **20 evenly spaced lessons per level = 100 lessons, 605 activities, 2,420 options**.
Mechanical checks (script kept outside the repo; the public JSON of the 100 lessons was kept with it for re-checks):
exactly one option marked correct; `answer` equals that option; every option has `rationaleVi`; no duplicate option text;
non-empty prompt; vocabulary has Japanese + Vietnamese meaning and a kana reading; Japanese fields contain Japanese;
placeholders (`TODO`, `{{`, `undefined`, `null`…); machine tokens (`word-word`, `snake_case`) in text the learner reads.

This is **not** an editorial review: grammar accuracy, naturalness of the Japanese, workplace register and the quality of the
Vietnamese still need a qualified human reviewer (content gate stays **OPEN**).

## Results

| Check | Result |
| --- | --- |
| Answer key / single correct option / rationale present / duplicate options / empty prompt | **0 problems** in 605 activities |
| Vocabulary fields, kana readings, Japanese fields without Japanese, placeholders | **0 problems** |
| Machine tokens in learner-visible Vietnamese text | **1,094 occurrences, in all 100 sampled lessons** (J5 218, J4 212, J3 228, J2 224, J1 212) |
| English words inside Vietnamese explanations | 184 (mostly `email` 77, `customer` 39, `deadline` 34, `report` 24, `meeting` 10) — many acceptable loanwords, needs an editor's call |

### Machine tokens (learner-visible fields only)

Fields: `activities[].options[].rationaleVi` 610, `activities[].promptVi` 153, `knowledgePoints[]` 112, `businessUsageVi` 100,
`politenessHierarchyVi` 100, `activities[].scenarioVi` 5, option text 4, `workplaceScenario.*Vi` 5, `explanationVi` 3.

| Token | Count | Proposed Vietnamese (for an editor to confirm) |
| --- | --- | --- |
| `manager-staff` | 364 | cấp trên – nhân viên |
| `senior-junior` | 282 | tiền bối – hậu bối (đàn anh – đàn em) |
| `company-partner` | 189 | công ty – đối tác |
| `executive-stakeholder` | 96 | lãnh đạo – bên liên quan |
| `colleague-colleague` | 54 | đồng nghiệp với nhau |
| `employee-customer` | 45 | nhân viên – khách hàng |
| `internal_chat` | 36 | tin nhắn nội bộ |
| `trade-off` | 21 | sự đánh đổi |
| `no-go` | 7 | không triển khai |

Examples (verbatim from production):

- `j5-01-greetings-intro` `activities[0].options[0].rationaleVi`: «Đúng vì biểu đạt này thực hiện chính xác mục đích “chào khi bắt đầu ngày làm việc” và phù hợp quan hệ **senior-junior**.»
- `j5-w03-l04` `activities[2].promptVi`: «… sau khi thấy “入力は終わりました。” trong **internal_chat**, hãy chọn hành động phù hợp nhất.»
- `j3-w11-l01` `activities[0].options[2].rationaleVi`: «… mục đích “nêu **trade-off** cùng phương án” và phù hợp quan hệ **company-partner**.»

### Quality observation (needs a human)

Rationales follow one template («Đúng vì biểu đạt này thực hiện chính xác mục đích “…” và phù hợp quan hệ …»). They are
consistent with the answer key, but they do not explain *why* the Japanese works (keigo level, word choice), which is what a
learner needs. Recommend an editorial pass on rationales before promoting all 420 lessons.

## What was changed

- **iOS:** nothing: the reader shows server text verbatim (no client-side rewriting of content).
- **Backend:** the lesson seed source is not in the repository (only the `curriculum.bjt_lesson.lesson_content` column), so the
  glossary above is a proposal. A replacement must touch only learner-visible `*Vi` strings (the same tokens are enum values in
  `relationship`, `stimulusType`, `analytics.*`, which code reads), bump `content_version`/`content_hash`, and be approved by the
  content owner. See the status file for whether a migration was prepared.

## Reproduce

Run the gate script against production (public GETs, ~105 requests, 0.4 s apart) and compare `findings.json`.
