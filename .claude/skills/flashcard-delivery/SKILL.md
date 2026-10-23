---
name: flashcard-delivery
description: Plan and deliver FlashcardApp features in reviewable slices using a BMAD-inspired workflow and XCTest TDD. Use for feature planning, cross-layer changes, and implementing a planned story.
---

# Flashcard delivery

This is a repository-specific adaptation of BMAD's planning/build/review loop,
not the upstream BMAD distribution. Method choice and invocation examples:
[`docs/AI_WORKFLOW.md`](../../../docs/AI_WORKFLOW.md). Do not require BMAD commands,
install its runtime, create a new chat, or add another project architecture.

## Establish the requested scope

Read root `AGENTS.md` and `docs/ENGINEERING_GUARDRAILS.md`. Resolve paths from the
repository root; when this skill is reached through `.agents/skills`, follow the
symlink to this canonical `.claude/skills` copy for relative reference links.
Inspect status/diff before editing and again before committing. Distinguish
pre-existing edits, the requested change and other agents' active work.

Classify the request:
- Advice or planning only: produce the requested decision/spec; do not implement
  all stories merely because a roadmap exists.
- Trivial docs or visual adjustment: direct edit and checks appropriate to the
  change. No epic, artificial unit test or agent team.
- Behavior fix or bounded feature: one short spec in the existing task/story,
  then the implementation loop below.
- Multi-session/cross-layer feature: plan dependencies and independently reviewable
  stories first. Reuse `docs/plans/` for durable plans; use `flashcard-architect`
  for a bounded design review when it adds independent evidence.

## Make one slice executable

For the selected slice record only what is needed:
- User outcome and what is outside this slice.
- Current flow and exact files/callers/tests/fixtures/localizations/target membership
  it reaches. Use CodeGraph for structure when available, with the project fallback.
- Acceptance examples (Given/When/Then), including relevant errors and data loss risks.
- Existing data/API contracts; mark unverified payloads and product hypotheses.
- Verification commands or IDE actions, expected observations, and commit boundary.

For identity, schema, auth or shared-state changes, settle ownership, migration,
cancellation and recovery before implementation. Obtain real redacted contract
evidence for API integration through `flashcard-api-contract`. A backend blocker
does not block an independent local-only story. Ask only for material missing
requirements or external actions lacking authorization; existing authorization stands.

## Implement, review, verify

Use `.claude/skills/flashcard-feature/SKILL.md` for implementation, and the existing
API/release skills only when relevant. Keep the current UIKit/VIPER boundaries.

For changed behavior:
1. Write the smallest regression test and run it. Record the actual RED assertion
   and cause. A package, simulator or compile infrastructure failure is not behavioral RED.
2. Implement until it passes; preserve validation, cancellation and error handling.
3. Refactor only within the slice, rerun affected tests, and record GREEN evidence.

For Realm, include a real old-schema store upgrade and reopen check. For UI, follow
the one-Simulator fast loop. For pure documentation/visual changes, do not manufacture
behavior tests. Use ≥80% meaningful changed-domain coverage when measurable; explicitly
state unmeasured scope rather than claiming whole-app coverage.

After a substantial change, assign a read-only `flashcard-reviewer` pass on the
specific diff and acceptance criteria. Use `flashcard-verifier` for build/test
diagnosis. Delegate only independent bounded work with disjoint file ownership;
one integrator owns shared project/catalog/migration files. If agents are unavailable,
perform the same roles locally and state that review was not independent.

Fix blocking findings; rerun checks affected by fixes. Distinguish product defects
from infrastructure failures and report missing required evidence as **NOT VERIFIED**.
Reviewer confidence is not a substitute for a test run or rendered UI inspection.

## Commit and hand off

When committing is authorized, stage explicit paths/hunks for this slice, inspect
the staged diff for secrets and unrelated work, and make a conventional commit.
Feature commits include passing tests and implementation together; RED evidence
does not require a broken commit. A requested checkpoint may preserve known issues
when clearly recorded; never describe it as release-ready.

Update the existing story with actual checks/results, review findings, remaining
limits and commit ID. PLANNED means no implementation; IMPLEMENTING means in progress;
VERIFIED means required checks passed; DONE includes the requested handoff/commit.
Do not mark a feature DONE from a spec or mocked integration alone. A changed story
must be reverified for the affected behavior. Report results in Vietnamese.

Local commits do not authorize pushing, publishing, remote writes, purchases or
credential changes. Finish all already authorized local work without asking again.
