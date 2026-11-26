# Today Engagement Pass Report (2026-11-26)

- **Branch:** `today-engagement-2026-11-26` (base `main` @ `2c1b2b0`)
- **Scope:** Today tab only (VIPER + UIKit, existing `DesignSystem` tokens, no Realm schema/DTO/API changes, no new dependencies, no ads changes, 5-tab structure and Home/other modules untouched).
- **Simulator verified:** iPhone 17 (`68B4C594-5534-41F6-B227-351A2D98FCF3`, iOS 27.2, Vietnamese locale) — Light, Dark, and Accessibility XXL (`accessibility-extra-extra-large`).

---

## 1. What Was Built & Real Data Sources

| # | Feature | Real Data Sources Used | Dropped / Hidden When No Real Signal |
|---|---|---|---|
| **1** | **"Nhiệm vụ hôm nay" (Today's Quest) + progress ring** (`TodayQuest.swift`, `TodayQuestView.swift`, `TodayLessonSlot.swift`) | • **Review due item:** `TodayPlan` (`kind` `.due`/`.returning` → real `dueCount` + `estimatedMinutes`; `.doneToday` → real `progress.saved` marked done; `.practice` → real `sessionCardIDs.count` + `estimatedMinutes`).<br>• **Lesson slot item:** `TodayLessonSlotProvider.slot(ownerKey:)` + `completedToday(ownerKey:now:calendar:)` checking real `RLessonProgress.completedAt` on the learner's local calendar day.<br>• **Daily Radar item:** `TodayRadarLoader.item` (`DailyRadarItem` with server `estimatedMinutes`); completion persisted in date-stamped `UserDefaults` (`UserDefaultsTodayQuestCompletionStore`, keyed by `ownerKey` + local `yyyy-MM-dd` + `slug`, marked done when the learner opens/studies the radar card).<br>• **Completion state:** Circular `CAShapeLayer` progress ring + `"Xong hôm nay"` badge + subtle spring check animation (respects Reduce Motion) + `.success` haptic when transitioning to all-done. | • Review item is omitted for `.noDeck`, `.chooseDeck`, and `.nothingDue` (never invents due counts).<br>• Radar item is omitted when `radar?.item == nil` (offline/loading/no usable card).<br>• Entire Quest card is hidden if 0 real items exist. |
| **2** | **Streak strip under the "Hôm nay" header** (`TodayStreak.swift`, `TodayInteractor.swift`, `TodayPresenter.swift`) | • **Flame icon, streak count, and today status:** `TodayStreakLoader.streak` (`AccountStreak` from `GET /api/gamification/streaks`, `activityType == "any"`) → real `days` count + `"Hôm nay đã học"` / `"Hôm nay chưa học"` (`countsToday`).<br>• **7-day week dots (Mon–Sun):** `TodayInteractor.studiedDaysInCurrentWeek(ownerKey:now:)` querying real `RReviewAttempt.answeredAt` (via `RealmReviewHistoryStore`) and real `RLessonProgress.completedAt` (via `RealmLessonProgressStore`) within the learner's current calendar week. | • `BJTStreakDTO` does not return per-day history from the server; when this device has no recorded activity in the current week (`studiedDaysInWeek.isEmpty`), `weekDots` is `nil` and the strip renders only flame + real streak count + `"Hôm nay đã học / chưa học"` — **never fake dots**.<br>• For guests (signed out) or broken/zero streaks, `AccountStreak` is `nil` by existing contract (`AccountStreak.swift`), so the strip is hidden rather than inventing a local streak count. |
| **3** | **Interactive Radar & Life cards** (`DailyRadar.swift`, `TodayRadarCardView.swift`, `DailyRadarCardViewController.swift`, `TodayLifeHubView.swift`, `TodayPresenter.swift`, `TodayWireframe.swift`) | • **Visual header (no empty placeholder):** `DailyRadarItem.visualScene(on:calendar:)` maps real `moduleKey` (`weather_japanese`, `japan_today`, `news_bjt`, `market_watch`, `workplace_mission`, `life_hack`, `honne_tatemae`) to the existing `LifeSceneView` illustrations. On `LifeTopicCardView`, replaced the empty bottom whitespace on ready cards with an interactive action row.<br>• **Nghe (Listen):** Reuses `SystemSpeechService.shared.speak(..., languageCode: "ja-JP")`.<br>• **Lưu vào deck (Save to deck):** Reuses `LessonWordSaver` (for Daily Radar expressions) and `LifeLessonInteractor.saveVocabulary` (for Life card vocabulary) with native deck-chooser action sheet + `NoticeToastView` feedback.<br>• **Học ngay (Study now):** Maps real `moduleType == "scenario_link"` / `targetRoute` (`"/story/arcs"`, `"/lessons"`, `"/levels"`) to existing in-app routes (`ScenarioListWireframe` / `HomeWireframe`); otherwise opens `DailyRadarCardViewController` (or `LifeLessonWireframe` for Life cards). | • Website-only `targetRoute` values that have no native screen (e.g. `"/vi/modules/honne_tatemae"`) return `deepLink == nil` and fall back honestly to reading the in-app `DailyRadarCardViewController`.<br>• `Lưu vào deck` is hidden on any card without expressions/vocabulary. |
| **4** | **Pinned Resume card ("Học tiếp")** (`TodayResumeCardView.swift`, `TodayPresenter.swift`, `TodayViewController.swift`) | • Derived from real `TodayLessonSlot.continueLesson(slug, title, levelCode, answered, total)` (`RLessonProgress` on device where `!isCompletedLocally && !answers.isEmpty && total > 0`).<br>• Displays real progress bar, real percentage (`round(answered / total * 100)` formatted with `AppLanguage.current.locale`), real answered count, and level badge; tapping resumes the exact lesson via `LessonReaderWireframe(slug:title:)`. | • **In-progress level % dropped:** The app does not store total lesson counts per level on-device, so level-level % is never invented.<br>• When `slot` is `.start`, `.next`, or `.finishedOpened`, `resumeCard` is `nil` and the view is hidden (no placeholder). |

---

## 2. Verification & Screenshots

### Screenshots (iPhone 17, iOS 27.2, Vietnamese)
- **Before:**
  - `docs/plans/today-engagement-2026-11-26/shots/before/today_light.png`
  - `docs/plans/today-engagement-2026-11-26/shots/before/today_dark.png`
  - `docs/plans/today-engagement-2026-11-26/shots/before/today_ax.png`
- **After:**
  - `docs/plans/today-engagement-2026-11-26/shots/after/today_light.png`
  - `docs/plans/today-engagement-2026-11-26/shots/after/today_dark.png`
  - `docs/plans/today-engagement-2026-11-26/shots/after/today_ax.png`

Visual check caught and fixed before final commit:
- Fixed `0/2` wrapping inside the 48×48 progress ring at AX-XXL by capping the ring numeral font scale (`maximumPointSize: 16`, `numberOfLines = 1`) and sizing the ring to 52×52.
- Fixed chip wrapping (`Lưu vào deck`) on Life & Radar cards by using `.fillProportionally` in standard text sizes and `.vertical` stack in AX sizes.
- Fixed async `TodayLifeHubLoader` callback racing with unit tests that clear `RealmService.shared.realm` by caching Realm-backed lesson/week snapshots in `TodayPresenter.reload()` and restoring previous Realm instances in new tests.

### Unit Tests & Localization
- Full `FlashcardAppTests` on `FlashcardApp-Local` (iPhone 17 Simulator): **1552 passed, 13 skipped (environment/backend dependent), 0 failed (1565 executed)**.
- Includes:
  - `TodayQuestTests` (7/7 passed)
  - `TodayStreakStripTests` (4/4 passed)
  - `TodayPresenterTests` (39/39 passed), `TodayPresenterRadarTests` (2/2 passed), `TodayPresenterStreakTests` (1/1 passed)
  - `DailyRadarPickerTests` (4/4 passed)
  - `LocalizationTests` (10/10 passed — all new keys present in `en`, `vi`, `ja` with valid placeholders and scripts)

### 3-Scheme Simulator Builds
- `FlashcardApp`: **BUILD SUCCEEDED**
- `FlashcardApp-Local`: **BUILD SUCCEEDED**
- `FlashcardApp-Production`: **BUILD SUCCEEDED**
