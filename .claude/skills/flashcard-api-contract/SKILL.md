---
name: flashcard-api-contract
description: Implement or audit FlashcardApp BJT/Keycloak API integration and DTO-to-Realm mapping against the checked-in OpenAPI contract.
---

Read `AGENTS.md` and `docs/AUDIT-2026-09-06.md`. The contract is at
`FlashcardApp/FlashcardApp/Networks/BJTClient/openapi.json`. Parse JSON and select
the operation plus referenced schemas; do not print the entire one-line file.

Trace the actual interactor caller. The legacy Swagger client and the new BJT
client coexist: changing a base URL does not migrate route names, authentication,
pagination or response envelopes. Do not regenerate over manually edited legacy
files without a reviewed diff and reproducible generation command.

For each operation check method/path, security, path/query parameters, request
required fields, nullability, response envelope and error status. Some checked-in
response schemas are empty: use a redacted local fixture or backend source before
claiming those DTOs are verified. Do not log or save bearer tokens. Do not perform
mutating API calls unless the user's task authorizes them.

Use the configured environment only. Validate status before decoding, propagate
errors, and cancel the Alamofire request when its Rx subscription is disposed.
Resolve session headers at subscription time and reject stale auth completions.
Do not automatically retry a submitted review without an idempotency contract.

Preserve backend UUID identity. Never use `hashValue`, truncated UUIDs or a constant
fallback key in persisted models. Existing Realm models use integer IDs; an actual
sync integration needs a tested identity mapping/migration and preserved favorites.
Do not discard unknown backend fields by guessing their legacy equivalent.

Add fixture decoding and URLProtocol/request-capture tests for the affected
operation, including error and cancellation behavior. Compile the real DTOs with
the real Realm model definitions; stand-in models alone cannot detect field drift.
Report what is verified against spec, against backend, and still unknown.
