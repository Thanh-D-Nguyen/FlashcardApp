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
- `Services/AuthSession.swift`: Keychain session lifecycle and stale-response protection.
  API results keep backend UUIDs; remote deck/progress synchronization is not implemented.
- `Services/RealmService.swift`: Realm stays the local store for the learner's own data (decks and
  cards `RDesk`/`RCard`, and their own changes to example sentences `RCardExample`; schema 3) and is where
  future caches live (add models to `storedTypes`).
  **The app bundles no database and keeps no dictionary for now**: words, kanji, grammar, example
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
8. Local and production use distinct bundle IDs and app sandboxes.
   Remote URLs are currently unprovisioned. Never substitute localhost or a made-up
   host for missing remote configuration, and never relax ATS globally.
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
