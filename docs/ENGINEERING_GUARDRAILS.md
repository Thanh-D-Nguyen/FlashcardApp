# FlashcardApp — engineering and UI verification guardrails

Applies to all human and AI changes in this repository, including P0 UI
modernization and later features. Read alongside `AGENTS.md`; the existing
architecture and data-safety rules there remain authoritative. This document
defines **how to demonstrate compliance**, not a new framework or architecture.

## 1. Preserve the current app

- Keep UIKit/storyboards and the existing VIPER-style module boundaries:
  View/ViewController renders UI and forwards events; Presenter owns presentation
  state and coordination; Interactor handles use cases; existing service/repository
  owns API and Realm access; Wireframe owns navigation and module assembly.
- Do not add MVVM, a new DI container, a network/persistence layer, another UI
  framework, or a dependency without an explicit, separately scoped requirement.
  SwiftUI is allowed for existing isolated previews, not as an implicit rewrite.
- Preserve navigation destinations, storyboard outlets/actions, existing
  accessibility identifiers, and Xcode target membership. New source/resources
  must be added explicitly to the correct target and verified by a build.
- Keep API DTOs and UUIDs, authentication and Keychain lifecycle, Realm schema,
  saved decks unchanged for UI-only work (the app bundles no dictionary database; dictionary data comes from the API). Any necessary
  behavior/data change requires its own justification and regression coverage.
- Keep UIKit work on the main thread. Preserve request cancellation, error
  propagation, validation, Realm thread ownership, and login/logout race safety.

## 2. Scope and working-tree protection

Before editing, inspect `git status`, relevant diffs, the actual user flow,
callers, tests, assets and storyboard connections. For structural questions use
CodeGraph when available; otherwise use Xcode symbols/native search.

Make the smallest complete change. Reuse existing views, color assets, UIKit
semantic colors and conventions. Do not introduce abstract components until
at least two actual call sites benefit. Do not expand a visual task into backend,
sync, gamification, SRS, analytics or settings behavior.

The workspace may be shared with another running agent. Treat every unrelated
modified, staged or untracked file as work in progress: do not reset, clean,
overwrite, stage or commit it. Recheck the target file/diff before each edit.
If an overlapping active edit cannot be reconciled safely, leave it untouched,
record the collision, and continue on independent work.

## 3. Risk-based testing rules

| Change | Required evidence |
| --- | --- |
| Behavior, validation, state transition or bug fix | Write a regression test that fails before the fix (RED), implement the smallest fix (GREEN), then refactor with the test passing. |
| Presenter / Interactor / service logic | Focused XCTest with success, failure and cancellation/edge cases as applicable; integration checks when crossing API/Realm boundaries. |
| Navigation, storyboard connections or essential user journeys | Relevant XCUITest (new or existing) plus an actual Simulator interaction when available. |
| Pure spacing, colors, typography or token wiring | Build and inspect real rendered UI in Simulator/Preview; no artificial unit tests or snapshots just to satisfy TDD. |
| Auth, API, Realm IDs/schema or persistence | Tests covering boundary behavior and regression of saved user state; schema changes require old-store migration fixtures. Not part of UI P0. |

Aim for at least 80% **meaningful coverage of changed domain logic** where
measurable; report actual targets and scope. Never claim 80% app-wide coverage
from a focused suite. Never weaken tests, delete data, or use hardcoded fake
metrics to achieve a passing result.

## 4. UI and learning-science quality bar

- Follow current Apple HIG and UIKit platform behavior on the deployment target
  (iOS 26+). Prefer native navigation/tab controls and system accessibility
  behaviors over custom lookalikes.
- Prioritize Japanese headwords/readings and Vietnamese meanings, clear actions,
  adequate contrast, Dynamic Type, VoiceOver and Reduce Motion. Verify compact
  widths, long Japanese strings and multiline Vietnamese content.
- Use semantic color roles in light/dark appearances; avoid unmotivated gradients,
  decorative cards, excessive shadows, and animation that obscures reading.
- Design for clear action recognition and low extraneous cognitive load.
  Retrieval practice is a learning-flow principle, not permission to fabricate
  SRS, streaks, review counts, synced progress or performance claims.
- Do not assume a screen is usable because it looks polished. Judge core user
  tasks and visible states: initial, loading, empty, error/retry, large text,
  light/dark, and relevant keyboard/navigation behavior.

## 5. Completion gates and reporting

Before declaring a task complete:

1. Inspect the final diff, including added files and project membership. Explain
   each affected module and confirm architecture boundaries still hold.
2. Build the relevant scheme/target; run focused XCTest and XCUITest checks
   appropriate to the change. Do not claim a test ran from source inspection.
3. For UI changes, inspect Simulator or Preview output; record which device,
   appearance and text size were actually checked. Screenshots are evidence
   only if captured from the rendered app, not mockups.
4. Verify preservation of main routes and, where relevant, API/auth and Realm
   behavior; identify any untested environment-dependent paths.
5. Report modified files, commands/tool actions actually run, observed outcomes,
   failures, and remaining risks in Vietnamese. Use **NOT VERIFIED** for any gate
   blocked by unavailable tools, runtime, backend or device. Do not report PASS
   if a required gate remains unverified.

Do not push, publish, upload builds, change credentials or modify remote data
without authorization. Do not install another AI workflow/framework merely to
enforce these checks. Independent review is useful for substantial changes,
but an agent review cannot substitute for compilation or observed UI behavior.

## 6. P0-only boundaries

P0 UI foundation is limited to minimal semantic tokens, Japanese/Vietnamese
typography and spacing, native navigation consistency, essential repeated UI
elements, and **one representative Home/Levels screen**. Changes to tab bars
and appearance plumbing must preserve all four existing tab routes.

For P0, a valid completion report includes source/build/test evidence and real
UI checks where possible. Move whole-screen redesigns, new learning modes,
progress tracking and server sync to separately approved follow-up work.
