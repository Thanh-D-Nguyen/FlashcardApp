# FlashcardApp — Completion & Deduplication Audit (2026-11-26)

- **Baseline:** `main` @ `2c1b2b0` (branch `fix-completion-2026-11-26`)
- **Scope:** Full-app audit of all 5 tabs (`Today`, `Dictionary`, `Card`, `Discover`, `Setting`), all 29 folders in `FlashcardApp/Modules` (covering 35 distinct screen/module surfaces including sub-modules `Shadowing`, `KanjiWriting`, `PictureSearch`, `BulkImport`, `DataExport`, `SharedDeck`, `DailyRadar`, `MagazineArticle`, `ScenarioPlay`), `FlashcardApp/Interactors`, `FlashcardApp/Commons`, and `AppDelegate`/`SceneDelegate`.
- **Verdict summary:** **23 findings** — **10 `FIX`**, **5 `REMOVE`**, **8 `KEEP`**.

---

## 1. Module Coverage Matrix (All 5 Tabs & 29 Module Folders)

| # | Module Folder | Tab / Entry Point | Reachable Screens / Sub-modules | Audit Status |
|---|---|---|---|---|
| 1 | `StartUp` | Launch root (`SceneDelegate.swift:24`) | `StartUpViewController` | Clean & complete |
| 2 | `Main` | Post-startup root | `MainViewController`, `MainTabbarController` (5 tabs) | Clean & complete |
| 3 | `Today` | Tab 1 (root) | `TodayViewController`, `DailyRadarCardViewController`, `TodayLifeHubView`, `TodayScenarioBannerView` | 1 FIX (`F05`), 1 REMOVE (`R04`), overlaps evaluated (`K01`, `K04`, `K05`) |
| 4 | `Home` | Pushed from `Today` & `Discover` | `HomeViewController` (Level list + Level content) | **1 P0 FIX (`F01`)** — alert-as-content (`showMeaning`) |
| 5 | `LessonList` | Pushed from `Home` (Level content) | `LessonListViewController` | Clean & complete |
| 6 | `LessonReader` | Pushed from `LessonList` & `Today` | `LessonReaderViewController`, `ShadowingViewController` | Clean & complete |
| 7 | `LessonPractice` | Pushed from `LessonReader` | `LessonPracticeViewController` | 1 minor FIX (`F10` title wiring) |
| 8 | `LifeLesson` | Pushed from `Today` Life Hub | `LifeLessonViewController` (4-step flow) | Clean & complete |
| 9 | `Scenario` | Pushed from `Today` Scenario Banner | `ScenarioListViewController`, `ScenarioPlayViewController` | Clean & complete |
| 10 | `Dictionary` | Tab 2 (root) | `DictionaryViewController` | Clean & complete |
| 11 | `DictionaryEntry` | Pushed from `Dictionary` & `DictionarySaved` | `DictionaryEntryViewController` (vocab/kanji/grammar/sentence) | Clean & complete (will also link from `F01` + fix cross-tab `showSearch`) |
| 12 | `DictionaryHandwriting` | Presented from `Dictionary` | `DictionaryHandwritingViewController` | Clean & complete |
| 13 | `DictionarySaved` | Pushed from `Dictionary` | `DictionarySavedViewController` | 1 FIX (`F09` stale footer & auth refresh) |
| 14 | `DictionaryScan` | Presented from `Dictionary` | `DictionaryScanViewController` | Clean & complete |
| 15 | `DictionaryVoice` | Presented from `Dictionary` | `DictionaryVoiceViewController` | Clean & complete |
| 16 | `Card` | Tab 3 (root) | `CardViewController`, `NewDeckOptionsViewController` | 1 FIX (`F10` search enablement), 2 REMOVE (`R02` `CardInteractor`, `R04` flow dedup) |
| 17 | `CardReview` | Pushed from `Card` (Review scope) | `CardReviewViewController` | Clean & complete (`K04`) |
| 18 | `CardStudy` | Pushed from `Card`, `Today`, `OftenMissed`, `RemoteDeck`, `LifeLesson`, `MagazineArticle` | `CardStudyViewController`, `KanjiWritingViewController` | 2 FIX (`F04` KanjiWriting, `F07` typed-incorrect summary label) |
| 19 | `CardStyle` | Presented from `CardStudy` | `CardStylePickerViewController` | Clean & complete |
| 20 | `CreateDesk` | Presented from `Card`, `CardStudy`, `Today`, `DeckGenerator` | `CreateDeskViewController`, `BulkImportViewController`, `PictureSearchViewController` | Clean & complete (`K02`, `K08`) |
| 21 | `DeckGenerator` | Presented from `Card` & `Today` | `DeckGeneratorViewController` | Clean & complete (`K02`, `R04`) |
| 22 | `ExampleEditor` | Presented from `CardStudy` | `ExampleEditorViewController` | 1 FIX (`F08` error banner & swipe-dismiss delegate) |
| 23 | `OftenMissed` | Pushed from `Card` | `OftenMissedViewController` | 1 FIX (`F03` pass missed `cardIDs`) |
| 24 | `RemoteDeck` | Pushed from `Card` | `RemoteDeckViewController`, `SharedDeckViewController` | 2 FIX (`F06` duplicate local copy, `F10` stop-sharing icon), 1 REMOVE (`R03` duplicate Save menu item) |
| 25 | `Discover` | Tab 4 (root) | `DiscoverViewController`, `DiscoverHeroView`, `DiscoverFindCard` | 1 FIX (`F02` second tap opens article) |
| 26 | `Magazine` | Pushed from `Discover` | `MagazineViewController`, `MagazineArticleViewController` | Clean & complete |
| 27 | `Loto` | Pushed from `Discover` | `LotoViewController`, `LotoLabView`, `LotoChaosPanelView` | Clean & complete |
| 28 | `Setting` | Tab 5 (root) | `SettingViewController`, `DataExportViewController` | 1 minor FIX (`F10` About chevron), 2 REMOVE (`R01` `SettingsPrototypes.swift`, `R02` `VersionFooterView`) |
| 29 | `MailLogin` | Root from `Setting` / Modal from 8 callers | `MailLoginViewController` | Clean & complete (`K08`) |

> All 29 module folders are reachable from live navigation starting at `StartUpWireframe` → `MainWireframe`. Zero orphan modules exist; dead code lives inside `Setting/Prototypes/`, `Setting/Views/VersionFooterView.*`, `Interactors/CardInteractor.swift`, and legacy `Commons/` views.

---

## 2. Unfinished Features & Incomplete UX Findings (`FIX`)

### F01 — [P0 · FIX] Level content entries use alert-as-content (`showMeaning`) instead of a detail screen
- **Evidence:**
  - `FlashcardApp/Modules/Home/HomePresenter.swift:135-139`: `selectRow(at:kind:)` calls `wireframe.showMeaning(title: row.title, message: row.detail.isEmpty ? "No meaning available yet." : row.detail)`.
  - `FlashcardApp/Modules/Home/HomeWireframe.swift:5, 35-37`: `showMeaning` calls `BaseWireframe.showAlert(with:message:)`.
  - `FlashcardApp/Modules/Home/Cells/HomeCells.swift:451`: `ContentRowCell` displays `accessoryType = .disclosureIndicator`, signalling push navigation that never happens.
  - `FlashcardApp/Networks/BJTClient/Models/BJTLevelDTO.swift:31-60`: Backend DTOs already carry backend UUID `id`, `headword`/`character`/`pattern`, `reading` or separate `onyomi`/`kunyomi`, `shortMeaningVi`/`meaningVi`, full `senses[].meaningVi` (vocab) and `details[].explanationVi` (grammar). All three IDs are standard UUIDs compatible with `BJTDictionaryAPI` (`/content/lexemes/{id}`, `/kanji/{id}`, `/content/grammar/{id}`).
- **Verdict:** **FIX**
- **Action:** Replace `showMeaning` with a pushed VIPER module `Modules/LevelEntryDetail` (DesignSystem tokens, `StateView` for empty details, scrollable full explanation/senses/readings, Japanese TTS button, Light/Dark + Dynamic Type AX support, and an action to open the existing `DictionaryEntry` screen when the entry has a valid backend UUID—plus safe cross-tab `DictionaryEntryWireframe.showSearch(for:)` routing). Remove `showMeaning` entirely and update `HomePresenterTests` + add `LevelEntryDetailPresenterTests`.
- **Resolution:** _Pending (Phase B)_

### F02 — [P1 · FIX] Discover "Today's find" sealed card does nothing on second tap
- **Evidence:**
  - `FlashcardApp/Modules/Discover/DiscoverHeroViews.swift:58`: Doc comment promises *"tap to break the seal, it turns over and shows today's word; tap again to read the article."*
  - `FlashcardApp/Modules/Discover/DiscoverHeroViews.swift:225-238`: `tapped()` only calls `reveal()`, which exits early when `isRevealed == true`, and sets `accessibilityTraits = .staticText`.
  - `FlashcardApp/Modules/Discover/DiscoverPresenter.swift:11-14, 78-85`: `DiscoverFind` only stores `word` and `articleJapanese`, discarding `item.slug` and `item.day` already present on `MagazineSummary`.
- **Verdict:** **FIX**
- **Action:** Add `slug` and `day` to `DiscoverFind`, wire second tap on `DiscoverFindCard` to `DiscoverPresenter.openFind()` → `DiscoverWireframe.showMagazineArticle(slug:day:)` → pushes `MagazineArticleWireframe`, show a subtle `"Read article"` affordance + chevron on the open face, keep `.button` accessibility trait, and add unit tests in `DiscoverPresenterTests`.
- **Resolution:** _Pending (Phase B)_

### F03 — [P1 · FIX] `OftenMissed` opens the entire deck instead of targeting missed cards
- **Evidence:**
  - `FlashcardApp/Modules/OftenMissed/OftenMissedPresenter.swift:53-56` & `OftenMissedWireframe.swift:15-17`: `selectRow(at:)` calls `showStudy(deckId: rows[index].deckID)`, pushing `CardStudyWireframe(deckId:)` with `cardIDs: nil` even though `CardStudyWireframe` already accepts `cardIDs: [String]?` (`CardStudyWireframe.swift:22`). Tapping a specific missed card drops the user onto card 1 of the entire deck.
- **Verdict:** **FIX**
- **Action:** Pass the often-missed `cardIDs` belonging to `row.deckID` (with the tapped `row.cardID` ordered first) into `CardStudyWireframe(deckId:cardIDs:)`, and add a regression test in `OftenMissedTests`.
- **Resolution:** _Pending (Phase B)_

### F04 — [P1 · FIX] `KanjiWriting` dead-end finish screen & broken reversed-direction decks
- **Evidence:**
  - `FlashcardApp/Modules/CardStudy/Views/KanjiWritingViewController.swift:163-168`: `.finished` phase renders `StateView.empty(title:message:)` with no action button (no "Practise again"), stranding the user on an empty screen.
  - `FlashcardApp/Modules/CardStudy/KanjiWritingPresenter.swift:24-35`: `KanjiWritingQuestions.make(from:canCheck:)` only scans `card.front`, so Vietnamese→Japanese decks (kanji on `card.back`) always show `"This deck has no kanji the app can check yet."`
- **Verdict:** **FIX**
- **Action:** Add `restart()` to `KanjiWritingPresenter` and present a `StateView.call(...)` with `"Practise again"` on `.finished`; update `KanjiWritingQuestions.make` to fall back to `card.back` (with `card.front` as meaning cue) when `card.front` has no kanji; add unit tests in `KanjiWritingTests`.
- **Resolution:** _Pending (Phase B)_

### F05 — [P1 · FIX] `TodayScenarioBannerView` horizontal chip scroll is blocked by parent view
- **Evidence:**
  - `FlashcardApp/Modules/Today/TodayScenarioBanner.swift:16, 63-77, 86`: `chipScroll` is configured as a horizontal `UIScrollView` (`alwaysBounceHorizontal = true`) holding 10 category chips, but its enclosing `column` sets `column.isUserInteractionEnabled = false` (`line 86`), disabling scrolling completely and clipping off-screen chips with no way to scroll them.
- **Verdict:** **FIX**
- **Action:** Keep non-interactive elements (`header`, `detail`, `cta`) `isUserInteractionEnabled = false` while leaving `column` and `chipScroll` interactive so users can scroll the category pills horizontally, and attach a tap gesture on `chipScroll` forwarding taps to `sendActions(for: .touchUpInside)` so tapping any chip still opens Situations.
- **Resolution:** _Pending (Phase B)_

### F06 — [P2 · FIX] Opening an uploaded deck on account and tapping "Study" duplicates the local deck
- **Evidence:**
  - `FlashcardApp/Interactors/CardLibraryServerInteractor.swift:118-136`: `hasDeviceCopy(deckId:)` checks both `repository.desk(withId: deckId)` and `DeckAccountLinks.deviceDeckId(forAccount: deckId)`, so `RemoteDeckViewController` hides `"Save to this device"`. However, `saveToDevice(_:)` only checks `repository.desk(withId: detail.deck.id)` and ignores `DeckAccountLinks`, so tapping `"Study"` imports a second local Realm deck alongside the original uploaded deck.
- **Verdict:** **FIX**
- **Action:** In `CardLibraryServerInteractor.saveToDevice(_:)`, check `DeckAccountLinks.deviceDeckId(forAccount: detail.deck.id)` and reuse that existing local deck if it still exists in `repository`, preventing duplicate local copies. Add regression test in `CardLibraryServerInteractorTests`.
- **Resolution:** _Pending (Phase B)_

### F07 — [P2 · FIX] `StudySummaryView` mislabels typed-incorrect cards as `"Self-rating"`
- **Evidence:**
  - `FlashcardApp/Modules/CardStudy/Views/StudyReviewViews.swift:256-257`: `card.result == .incorrect ? NSLocalizedString("Incorrect", ...) : NSLocalizedString("Self-rating", ...)` omits `.typedIncorrect`, which `CardStudyPresenter.swift:303` explicitly includes in the review list.
- **Verdict:** **FIX**
- **Action:** Treat both `.incorrect` and `.typedIncorrect` as `"Incorrect"` in `StudySummaryView` (and test in `CardStudyPresenterTests` / `StudySessionTests`).
- **Resolution:** _Pending (Phase B)_

### F08 — [P2 · FIX] `ExampleEditorViewController` error display & swipe-dismiss guard bugs
- **Evidence:**
  - `FlashcardApp/Modules/ExampleEditor/Views/ExampleEditorViewController.swift:105-106`: sets `problemLabel.text = state.problem` directly instead of calling `problemLabel.show(state.problem)`, bypassing the warning icon and VoiceOver accessibility formatting of `FormErrorLabel`.
  - `FlashcardApp/Modules/ExampleEditor/Views/ExampleEditorViewController.swift:37`: assigns `navigationController?.presentationController?.delegate = self` in `viewDidLoad()` where `presentationController` may still be nil (unlike `CreateDeskViewController.swift:60` which sets it in `viewDidAppear(_:)`).
- **Verdict:** **FIX**
- **Action:** Call `problemLabel.show(state.problem)` and move presentationController delegate assignment to `viewDidAppear(_:)`.
- **Resolution:** _Pending (Phase B)_

### F09 — [P2 · FIX] `DictionarySaved` stale footer across category switches & missed sign-out refresh
- **Evidence:**
  - `FlashcardApp/Modules/DictionarySaved/DictionarySavedViewController.swift:66-99`: `render(_:)` sets `tableView.tableFooterView = footer(for: loaded)` in `.loaded`, but never clears `tableView.tableFooterView = nil` in `.signedOut`, `.loading`, `.empty`, or `.error`.
  - `FlashcardApp/Modules/DictionarySaved/DictionarySavedPresenter.swift:59-65`: `viewWillAppear()` only reloads if `!hasLoaded || needsRefresh`, ignoring auth state transitions (sign-out/sign-in in Settings tab) unlike `DictionaryEntryPresenter.swift:123-126`.
- **Verdict:** **FIX**
- **Action:** Reset `tableView.tableFooterView = nil` on non-loaded states in `DictionarySavedViewController`, track `signedInWhenLoaded` in `DictionarySavedPresenter` so returning after sign-out/sign-in reloads cleanly, and add a regression test in `DictionarySavedTests`.
- **Resolution:** _Pending (Phase B)_

### F10 — [P2 · FIX] Small interactive/UI polish bugs across `Card`, `RemoteDeck`, `LessonPractice`, and `Setting`
- **Evidence:**
  - `FlashcardApp/Modules/Card/Views/CardViewController.swift:209`: disables search bar when `state.scope == .mine && state.deckCount == 0`, even when `"On your account"` decks are displayed and filterable (`CardPresenter.swift:355-357`).
  - `FlashcardApp/Modules/RemoteDeck/Views/RemoteDeckViewController.swift:175`: uses `"link.badge.plus"` SF Symbol for `"Stop sharing"` (contradictory icon).
  - `FlashcardApp/Modules/LessonPractice/LessonPracticePresenter.swift:62, 120` & `LessonPracticeViewController.swift`: `presenter.title` is set on `viewDidLoad()` to the lesson's title, but `LessonPracticeViewController` never applies it to `title`.
  - `FlashcardApp/Modules/Setting/SettingPresenter.swift:583-588`: `"About Flashcard"` row uses `disclosure: true` (default) even though tapping shows a version alert rather than pushing a screen.
- **Verdict:** **FIX**
- **Action:** Enable search in `.mine` whenever `state.deckCount > 0 || !state.accountSection.decks.isEmpty`; use `"link"` / `"xmark.circle"` (`"slash.circle"` or `"link"` with destructive style / `"nosign"`) for `"Stop sharing"`; bind `navigationItem.title = presenter.title` in `LessonPracticeViewController`; set `disclosure: false` on `"About Flashcard"` in `SettingPresenter`.
- **Resolution:** _Pending (Phase B)_

---

## 3. Dead / Prototype Code & Redundant UI Entry Points (`REMOVE`)

### R01 — [REMOVE] Unreferenced SwiftUI prototype file compiled into Release target
- **Evidence:** `FlashcardApp/Modules/Setting/Prototypes/SettingsPrototypes.swift:1-682` — 682 lines of SwiftUI comparison prototypes (`SettingsDirectionA/B/C`) with empty `Button(action: {})`, `EmptyView()`, and fake hardcoded metrics (`"12"` day streak, `"847"` cards reviewed). Zero references anywhere in the app or tests, NOT `#if DEBUG`-guarded, compiled into the Release app target (`project.pbxproj` `B7D044161C7EB7E739C30D8C`).
- **Verdict:** **REMOVE**
- **Action:** Delete `SettingsPrototypes.swift` and remove its file reference & build-phase entry from `FlashcardApp.xcodeproj/project.pbxproj`.
- **Resolution:** _Pending (Phase B)_

### R02 — [REMOVE] Dead `VersionFooterView` + empty `CardInteractor` stub
- **Evidence:**
  - `FlashcardApp/Modules/Setting/Views/VersionFooterView.swift:1-27` & `VersionFooterView.xib:1-52`: hardcoded `"Flashcard App"` / `"Version 1.0.0"`, zero callers in code, storyboards, or tests, yet compiled in `Sources` and bundled in `Resources`.
  - `FlashcardApp/Interactors/CardInteractor.swift:1-21`: completely empty protocol and class stored in `CardPresenter.swift:171` and never called.
- **Verdict:** **REMOVE**
- **Action:** Remove `VersionFooterView.swift`, `VersionFooterView.xib`, and `CardInteractor.swift` from disk and `project.pbxproj`; simplify `CardPresenter` / `CardWireframe` / tests to drop the empty dependency.
- **Resolution:** _Pending (Phase B)_

### R03 — [REMOVE] Redundant `"Save to this device"` action in `RemoteDeckViewController` `•••` menu
- **Evidence:**
  - Path A (more complete): `FlashcardApp/Modules/RemoteDeck/Views/RemoteDeckViewController.swift:60-65, 144-147` — pinned bottom `saveButton` (`"Save to this device"`), always visible when `!state.isOnDevice`, with inline `showsActivityIndicator` progress feedback and explanatory footnote.
  - Path B (redundant): `FlashcardApp/Modules/RemoteDeck/Views/RemoteDeckViewController.swift:157-161` — identical `"Save to this device"` item duplicated inside the top-right `•••` menu.
- **Verdict:** **REMOVE**
- **Action:** Remove the duplicate `"Save to this device"` item from `makeMenu(for:)` and hide `navigationItem.rightBarButtonItem` when the resulting menu has no items (e.g., private/non-owned edge case with no actions).
- **Resolution:** _Pending (Phase B)_

### R04 — [REMOVE] Duplicated new-deck creation orchestration between `TodayWireframe` and `CardWireframe`
- **Evidence:**
  - Path A (more complete): `FlashcardApp/Modules/Card/CardWireframe.swift:57-79` + `CardPresenter.swift:493-508` — presents `NewDeckOptionsViewController` sheet (`.medium()/.large()`), routes `.manual` → `CreateDeskWireframe` and `.automatic` → `DeckGeneratorWireframe` → `CreateDeskWireframe(deckId:)`.
  - Path B (duplicated wireframe code): `FlashcardApp/Modules/Today/TodayWireframe.swift:44-73` — copy-pastes the exact same sheet presentation, detents, generator presentation, and editor handoff.
- **Verdict:** **REMOVE** (remove duplicated orchestration code; keep Today's empty-state `"Create your first deck"` onboarding button)
- **Action:** Extract a single shared `NewDeckFlow` helper (`Modules/Card/Views/NewDeckOptionsViewController.swift`) and call it from both `TodayWireframe` and `CardWireframe`, eliminating duplicated presentation/handoff code.
- **Resolution:** _Pending (Phase B)_

### R05 — [REMOVE] Dead legacy `Commons/` UI components compiled into Release target
- **Evidence:** Zero callers in Swift, storyboards, XIBs, or tests across the entire repository:
  - `FlashcardApp/Commons/Views/PlaceholderView.swift` (superseded by `StateView`)
  - `FlashcardApp/Commons/Views/RoundCornerButton.swift`
  - `FlashcardApp/Commons/Views/RoundCornerView.swift`
  - `FlashcardApp/Commons/Views/RoundedImageView.swift`
  - `FlashcardApp/Commons/Utils/AppColor.swift` (legacy `AppColors` shim superseded by `Design.Color`)
  - `FlashcardApp/Commons/Extensions/Color.swift` (only referenced by dead `RoundCornerButton.swift:16, 22`)
- **Verdict:** **REMOVE**
- **Action:** Delete these 6 provably unreferenced files and remove them from `FlashcardApp.xcodeproj/project.pbxproj`.
- **Resolution:** _Pending (Phase B)_

---

## 4. Duplicate & Overlap Candidates Evaluated as `KEEP` (False Alarms / Boundary Constraints)

| ID | Feature Pair / Surface | Evidence | Verdict | Reason to KEEP |
|---|---|---|---|---|
| **K01** | BJT Levels entry in `Today` (`today_levels_row` / `TodayLessonSlotView`) vs `Discover` (`discover_levels`) | `TodayWireframe.swift:98-100`, `DiscoverWireframe.swift:24`, `FlashcardAppUITests.swift:21,1157`, `DiscoverUITests.swift:26` | **KEEP** | Both push the single `HomeWireframe` (zero duplicated module code). Today provides a daily-study shortcut while Discover mirrors the website's Explore catalog; both are established tab navigation routes covered by UI tests. |
| **K02** | Deck creation: `CreateDesk` (manual) vs `DeckGenerator` (JLPT auto) vs `BulkImportViewController` (TSV paste) | `NewDeckOptionsViewController.swift:37-46`, `CreateDeskViewController.swift:303` | **KEEP** | Complementary workflows (offline manual entry, server JLPT auto-generation that hands off to `CreateDesk`, and bulk paste inside `CreateDesk`), not duplicates. Wireframe code duplication is removed in `R04`. |
| **K03** | Deck sharing/import: `SharedDeckViewController` vs `RemoteDeckViewController` vs `DeckPublishInteractor` | `RemoteDeckWireframe.swift:90-118`, `CardViewController.swift:384-393` | **KEEP** | Distinct sequential stages (anonymous token preview+clone → account deck viewer/download → local-to-account upload). Actual overlaps/bugs are resolved in `R03` and `F06`. |
| **K04** | Server SRS Review (`CardReview`) vs Local Study (`CardStudy` + `Today` hero) | `CardWireframe.swift:81-91`, `TodayWireframe.swift:40-42`, `MainViewController.swift:39-49` | **KEEP** | Backed by separate data sources (server `/reviews/due` + account streak vs offline Realm FSRS). Removing either would touch API/data contracts and navigation roots (out of scope per hard constraints). |
| **K05** | Learning feeds: `LifeLesson` (Today real-time context) vs `Scenario` (any-day situations) vs `LessonReader` (BJT curriculum) vs `DailyRadar` vs `Magazine` vs `Loto` | `TodayViewController.swift:126-134`, `DiscoverFeature.swift:6-10`, `SampleLifeContent.swift:12-208` | **KEEP** | Distinct content domains and backend endpoints. `SampleLifeContent` cards are explicitly badged `"SAMPLE"` as a graceful fallback when `GET /api/life/feed` returns 404. |
| **K06** | Search entry points: `Dictionary` tab vs `ScenarioList` search bar vs `Card` library search bar | `DictionaryViewController.swift:84`, `ScenarioListViewController.swift:36`, `CardViewController.swift:86` | **KEEP** | Each filters a completely different domain (dictionary API corpus vs in-memory scenarios vs user's deck library). Only one dictionary search screen exists. |
| **K07** | Settings `"Report an ad"` vs `"Contact Support"` and `"About Flashcard"` alert | `SettingPresenter.swift:418-421, 560-588`, `SettingWireframe.swift:136-160`, `SettingPresenterTests.swift:225` | **KEEP** | `"Report an ad"` is intentional ad-compliance discoverability (explicitly tested); version-only About alert is standard iOS convention (misleading disclosure chevron removed in `F10`). |
| **K08** | Backend/platform-gated paths: `PictureSearch` (503 fallback), `ReviewSync` (capability-gated), `DailyRadarCardViewController` (read-only), `Setting` root login (`navigateToWelcome`), Universal Links for shared decks | `PictureSearchPresenter.swift:77`, `BJTReviewSyncAPI.swift:5-6`, `DailyRadarCardViewController.swift:5-106`, `SettingWireframe.swift:162-167`, `SceneDelegate.swift:31-35` | **KEEP** | Properly degrade when server endpoints/entitlements are absent, or touch navigation root / entitlements outside UI-only scope. |

---

## 5. Execution Log (Phase B)

_Will be updated with exact commit hashes as each fix and removal is implemented, tested, and pushed._
