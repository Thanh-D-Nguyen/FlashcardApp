---
name: flashcard-api-contract
description: Implement or audit FlashcardApp BJT/Keycloak API integration and DTO-to-Realm mapping against the checked-in OpenAPI contract.
---

Read `AGENTS.md` and `docs/DEVELOPMENT.md`. Current API clients live in
`FlashcardApp/Networks/BJTClient`. The former local OpenAPI path and Keycloak
login assumptions are obsolete. Confirm each operation using the running backend
source and redacted local responses; if an OpenAPI file is available, parse JSON
and select only the operations and referenced schemas you need.

The website currently uses POST `/api/auth/login` with email/password and an
opaque session token, GET `/api/auth/me` and POST `/api/auth/logout`. Authentication
is owned by `AuthSession` and `NativeAuthAPI`; do not restore social SDKs or a
parallel bearer-header store. Public search and level APIs need no login.

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
fallback key in persisted models. An actual sync integration needs tested identity mapping/migration and preserved favorites.
Do not discard unknown backend fields by guessing their legacy equivalent.

Add fixture decoding and URLProtocol/request-capture tests for the affected
operation, including error and cancellation behavior. Compile the real DTOs with
the real Realm model definitions; stand-in models alone cannot detect field drift.
Report what is verified against spec, against backend, and still unknown.
