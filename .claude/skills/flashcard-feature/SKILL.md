---
name: flashcard-feature
description: Implement or fix a FlashcardApp UIKit feature through its presenter, interactor and data layer with regression checks.
---

Read `AGENTS.md` from the repository root. Inspect the current diff and trace the
affected screen, including storyboard outlets/identifiers and wireframe assembly.
Use CodeGraph if present; otherwise use Xcode symbol/search tools.

For a planned story or a feature needing scope/acceptance decisions, first use
`../flashcard-delivery/SKILL.md`. Reuse its scope and test evidence instead of
creating a second plan. For a small fix, keep the acceptance example and evidence
in the task; no separate planning document is required.

Reuse the nearest complete module as the pattern. UI rendering belongs in the
controller, state/interaction in the presenter, use cases in the interactor and
storage/network work in the existing service. Avoid forcing a rewrite to SwiftUI,
async/await or a new dependency container into an isolated fix.

Write a failing regression test for changed behavior, using the existing XCTest
targets. Include failure/empty/cancel states as appropriate. Keep Realm access on
its owning thread and pass values across queues. Dispose subscriptions with the
feature lifecycle and observe on the main scheduler before touching UIKit.

Implement the smallest complete change. Register every new file in the explicit
Xcode target, then run build and focused tests relevant to the change. Use the
single-Simulator default verification loop in `docs/ENGINEERING_GUARDRAILS.md` §3.
If interaction behavior changes, verify the affected user journey and its relevant
states on that Simulator. Do not routinely run large-text, VoiceOver, appearance,
language or multi-device matrices; expand only for relevant risks or release.
Continue to implement accessible and localized UI. For API work also load
`flashcard-api-contract`.

Report the observed result and any remaining blocker. Do not equate an added file
with an integrated feature or a launch-only UI test with a tested user journey.
