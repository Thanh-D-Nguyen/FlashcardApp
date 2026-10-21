---
name: flashcard-release
description: Configure or verify FlashcardApp local, staging and production builds, signing prerequisites and release blockers.
---

Read `AGENTS.md`, `docs/DEVELOPMENT.md` . Inspect actual
resolved Xcode settings, not just xcconfig text: target settings override project
settings. Use FlashcardApp-Local for routine development and
FlashcardApp-Production only for release verification.

Remote endpoints are not provisioned yet. Keep missing remote URL builds blocked.
Check distinct bundle IDs, app names, ATS policy, configuration inheritance,
native website authentication and Keychain session behavior. Runtime
secrets cannot be protected by embedding them in an xcconfig or application bundle.
Never upload an archive or alter remote credentials without authorization.

Run the environment validator tests, build with the pinned package graph and run
the affected XCTest/UI tests. For persistence changes, test upgrading an existing
database as well as a clean install. Test auth success/failure, logout during an
in-flight request, offline/retry, card creation/edit/delete, and relaunch persistence
before a release. Document measured coverage and manual checks honestly.

Provide a concrete release decision with evidence and unresolved blockers.
Dependency compatibility, privacy manifests, signing, server availability and
backend contract smoke tests are independent gates; a scheme or a simulator build
does not certify them. Keep build artifacts and machine-local overrides untracked.
