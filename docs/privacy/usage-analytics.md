# Usage analytics (K-11) — what the app sends, and what a human must approve

**State:** implemented, **off by default**; not released. Code: `FlashcardApp/Services/AnalyticsService.swift`,
Settings → General → "Share anonymous usage data".

## What is sent, and only when the learner turned the switch on

`POST /api/analytics/events` (public route, no bearer, no cookie, so an event is never tied to the account). Body: a JSON array of
1…100 `{eventName, source, payload}`; `source` is always `ios-app`. Payload values are strings from fixed sets:

| eventName | when | payload (every key that can appear) |
| --- | --- | --- |
| `ios_session_started` | the app comes to the foreground | `schemaVersion` (`1`), `platform` (`ios`), `appVersion` |
| `ios_lesson_completed` | a lesson is finished on the device | the three above + `level` (`J5`…`J1` only) |
| `ios_review_session_finished` | an account review session ends | the three above + `ratedBucket` (`0`, `1-9`, `10-49`, `50+`) |

Never sent: account or user id, device id/IDFA/IDFV, IP-derived data added by the app, tokens, words looked up, deck/card/lesson text,
lesson slugs, free text. Events wait in memory only (max 100), are sent as one batch at 20 events or when the app leaves the foreground,
and a failed batch is dropped (not resent, so nothing is counted twice). Turning the switch off drops what is waiting.

Verified 2026-11-11: production accepted the batch shape (`200 {"accepted":true}`) from `LiveProductionContractTests`
(one event `ios_contract_check`, source `ios-contract-test`) and from the contract probe (one `ios_contract_check`).

## MetricKit

`LocalMetricsCollector` subscribes to MetricKit and keeps only counts (reports, crashes, hangs, last report end) in
`Application Support/Metrics/summary.json` on the device. Nothing is uploaded. MetricKit delivers on real devices only, about daily:
**NOT VERIFIED** on the Simulator.

## Needs a human decision before release (not done by the app team)

1. **Privacy policy text** (kiokoto.com): add optional, consent-based anonymous usage counts and what they contain (table above).
2. **App Store Connect → App Privacy:** if the switch ships, declare *Usage Data → Product Interaction*, **not linked** to identity,
   **not used for tracking**; collection is optional. The server still sees the request IP (server logs): legal must confirm whether
   that changes the declaration. MetricKit stays on device, so no Diagnostics entry is needed for it.
3. **Retention** of `analytics.analytics_event` rows on the backend (no prune job exists) and who can read them (admin analytics).
4. Whether the consent copy (vi/en/ja) satisfies the applicable laws (Vietnam PDPD Decree 13/2023, Japan APPI) — legal review.
