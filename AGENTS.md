# FlashcardApp — project instructions

Read this file before changing the app. For Claude Agent in Xcode, `CLAUDE.md`
imports it. Keep project rules here; workflows live in `.claude/skills/`.

## Project map

- iOS 26+, Swift 5, UIKit/storyboards, VIPER-style modules, RxSwift, Alamofire,
  Realm, Swift Package Manager. This is an existing application, not a template.
- `Modules/<Feature>`: view/controller, presenter, wireframe. `Interactors`:
  use cases. `DataManager/Local`: Realm access. `Entities`: presentation models.
- `Networks/BJTClient`: native website session auth, public search and level content.
  Confirm operations against the running backend and selected schemas; older
  Keycloak/Swagger contracts do not describe the current Go login flow.
- `Modules/Dictionary*` (tìm kiếm, `DictionaryEntry` chi tiết từ/kanji/ngữ pháp/câu, `DictionarySaved`, `DictionaryScan`, `DictionaryVoice`, `DictionaryHandwriting`):
  nội dung từ điển đến từ API công khai (`BJTSearchAPI`, `BJTDictionaryAPI`); "Lưu" là bookmark của **tài khoản** (`BJTBookmarkAPI`, toggle
  không idempotent, không tự thử lại); lịch sử chỉ ở `UserDefaults` (`DictionaryHistoryStore`). Thứ tự nét chỉ vẽ khi SHA-256 khớp
  `strokeSvgHash` (`KanjiStrokeDrawing`). Đừng thêm dữ liệu từ điển, tách từ hay furigana tự bịa. Xem `docs/ui-redesign/dictionary/README.md`.
- `Modules/Discover` (tab 5, "Khám phá") + `Modules/Magazine`: hub theo registry `DiscoverFeature` để thêm dần tính năng của website; Magazine đọc API công khai
  `/api/magazine` (`BJTMagazineAPI`), lưu từ vào bộ thẻ "Magazine" (idempotent). Bài Loto **không** nằm trong danh sách Magazine mà có màn riêng `Modules/Loto` (thẻ nổi bật đầu Khám phá): bộ số Loto 6/7 kèm đếm ngược, lý do chọn số và câu "mọi tổ hợp có xác suất như nhau" luôn hiện trước các bộ số; không mua vé, không hứa trúng. Cách thêm tính năng mới và giới hạn: `docs/ui-redesign/magazine/README.md`.
- `Services/AuthSession.swift`: Keychain session lifecycle and stale-response protection. Email and
  Google sign-in share one path; the Google ID token (`Services/GoogleIDTokenProvider.swift`) is exchanged
  once at `POST /auth/google` and never stored. Never link a Google account to a password account by email.
  API results keep backend UUIDs; remote deck/progress synchronization is not implemented.
- `Modules/Card` (tab 3, "Thẻ"): bốn mục như web — **Ôn tập** (`Modules/CardReview`, `GET /reviews/due`, đánh giá `POST /reviews/{id}` **một lần, không tự thử lại**),
  **Của tôi** (bộ trên máy + "Trên tài khoản"), **Công khai**, **Gần đây** (cùng `GET /flashcards/decks`; server xoá `ownerUserId` của bộ không phải của mình) và
  `Modules/RemoteDeck` (xem/lưu về máy/học/lưu trữ). Học vẫn chạy trên bộ cục bộ: "Học" lưu bản sao với id của server. Chi tiết, giới hạn: `docs/ui-redesign/cards/README.md` §8.
- `Services/RealmService.swift`: Realm stays the local store for the learner's own data (decks and
  cards `RDesk`/`RCard`, example-sentence changes `RCardExample`, review history `RReviewAttempt`/`RReviewState`, lesson progress `RLessonProgress`; schema 7) and is where
  future caches live (add models to `storedTypes`).
  **The app bundles no database and keeps no dictionary for now** (the one bundled data file is `Resources/HandwritingTemplates.bin`, KanjiVG stroke *shapes* for the handwriting recognizer — no meanings, readings or examples): words, kanji, grammar, example
  sentences and suggestions come from the API. The user plans a download mechanism for dictionary
  data later; until they ask for it, do not re-add the bundled `flash_card.realm` or dictionary
  tables. Never delete the learner's decks; the schema-2 migration only empties the retired
  dictionary tables of upgraded installs.
- `FlashcardApp.xcodeproj/project.pbxproj` uses explicit file membership. New Swift
  files and resources must be added to the appropriate target and built.

## Working rules

1. Inspect `git status` and the relevant current diff. Never reset, overwrite,
   stage, or commit unrelated work. The audit started with 130 modified files.
2. Trace the real user flow before editing. Prefer CodeGraph for definitions and
   callers when available; otherwise use Xcode symbol tools or native search.
   Do not require an optional MCP server or local CLI for ordinary development.
3. Keep View → Presenter → Interactor → existing data/API service boundaries.
   Keep navigation in wireframes. Reuse existing types; do not introduce another
   architecture, dependency injection framework, network stack, or persistence
   layer for a small feature. UIKit UI updates belong on the main thread.
4. Use value types for DTOs and immutable values where practical. Realm objects
   are intentionally mutable inside transactions; never transfer live objects
   across threads or silently delete a store to make a migration pass.
5. Validate API input and HTTP status; propagate decoding and persistence errors.
   Rx disposal must cancel owned network work. Do not retry mutations such as
   review submissions without server-supported idempotency.
6. Authentication state must clear tokens and headers together on logout.
   In-flight responses must not restore a logged-out session. Keep credentials
   out of source, plist, logs and fixtures. Persistent tokens belong in Keychain;
   public mobile client identifiers are not server secrets.
7. Keep backend UUIDs intact. Swift `hashValue` is not a persistent identifier.
   Realm key/schema changes require a migration and upgrade-fixture test, including
   saved decks, card references and favorites. Never invent a DTO from an endpoint
   name; confirm payloads against the contract and a redacted local response.
8. Local and production use distinct bundle IDs and app sandboxes. Production
   talks to `https://kiokoto.com/api` (`ReleaseConfig.xcconfig`); local to
   `http://localhost:18081/api`. Never substitute localhost or a made-up host for missing
   remote configuration, and never relax ATS globally. Google sign-in needs one iOS OAuth
   client **per bundle ID** plus the shared Web client (`docs/DEVELOPMENT.md` ▸ Google).
9. Add a regression test before a behavior fix. Run relevant XCTest, integration
   and UI checks for the affected flow. Aim for ≥80% meaningful coverage of new
   domain logic; report measured scope, never assert whole-app coverage from a
   small suite. Do not add snapshot/string-matching tests just to inflate coverage.
10. Verify target membership, build, and the behavior changed. Use Xcode's available
    build/test/diagnostic tools in the IDE; CLI commands are in `docs/DEVELOPMENT.md`.
    Record infrastructure failures separately from source failures. Never claim
    tests passed when only source parsing or mocks ran. For routine UI development,
    use the single-Simulator fast loop in `docs/ENGINEERING_GUARDRAILS.md` §3;
    do not run multi-device, large-text, or appearance/language matrices by default.
11. Read-only inspection and local fixes are within normal development scope.
    Ask before publishing, pushing, merging, uploading builds, modifying remote
    data, or changing credentials, unless the user already authorized that action.

12. The UI ships in Vietnamese, English and Japanese. Never hard-code user-visible text:
    use `NSLocalizedString` with the English text as key and add vi/en/ja values to
    `FlashcardApp/Resources/Localizable.xcstrings` (`LocalizationTests` fails otherwise).
    Format numbers with `AppLanguage.current.locale`; backend text that exists in several
    languages must follow `AppLanguage.current`. See `docs/UI_REDESIGN_BLUEPRINT.md` §11.

## Workflow routing

- **All implementation tasks:** follow `docs/ENGINEERING_GUARDRAILS.md` for
  architecture boundaries, risk-based testing, visual verification, and evidence
  required before reporting completion. These rules also apply to work already
  in progress when the agent next reads project instructions.
- Feature/bug: `.claude/skills/flashcard-feature/SKILL.md`.
- Feature planning and delivery of a planned story: start with
  `.claude/skills/flashcard-delivery/SKILL.md` (BMAD-inspired planning + existing
  XCTest TDD), then the feature/API/release skill as needed. Codex discovers the
  same skill through `.agents/skills/flashcard-delivery`. Method choice and usage:
  `docs/AI_WORKFLOW.md`. Load only the relevant story from `docs/plans/`; a roadmap
  is not authorization to implement all its stories. Trivial edits stay lightweight.
- Backend integration/DTO/auth: `.claude/skills/flashcard-api-contract/SKILL.md`.
- Environment, build or release verification:
  `.claude/skills/flashcard-release/SKILL.md`.
- Complex cross-layer design: `flashcard-architect` agent, scoped plan first.
- Behavior/security review: `flashcard-reviewer` agent after a substantial change.
- Build/test diagnosis: `flashcard-verifier` agent.

Use a subagent only for an independent bounded task. Assign file ownership for
edits, remind agents that others share the repo, and integrate their evidence.
If Xcode does not expose subagents, perform the same workflow in the main agent.
Small changes do not need an agent team. Do not force a model or install tools.

Explain results in Vietnamese unless the user asks otherwise. Report what changed,
what actually ran, and unresolved release blockers. See `docs/DEVELOPMENT.md`.
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.
