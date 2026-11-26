# FlashcardApp — Completion & Deduplication Audit (2026-11-26)

- **Baseline:** `main` @ `2c1b2b0` (branch `fix-completion-2026-11-26`)
- **Scope:** Full-app audit of all 5 tabs (`Today`, `Dictionary`, `Card`, `Discover`, `Setting`), all 29 folders in `FlashcardApp/Modules` (covering 35 distinct screen/module surfaces including sub-modules `Shadowing`, `KanjiWriting`, `PictureSearch`, `BulkImport`, `DataExport`, `SharedDeck`, `DailyRadar`, `MagazineArticle`, `ScenarioPlay`), `FlashcardApp/Interactors`, `FlashcardApp/Commons`, and `AppDelegate`/`SceneDelegate`.
- **Verdict summary:** **23 findings** — **10 `FIX`** (all completed), **5 `REMOVE`** (all completed), **8 `KEEP`** (verified boundary/intentional).

---

## 1. Module Coverage Matrix (All 5 Tabs & 29 Module Folders)

| # | Module Folder | Tab / Entry Point | Reachable Screens / Sub-modules | Audit Status |
|---|---|---|---|---|
| 1 | `StartUp` | Launch root (`SceneDelegate.swift:24`) | `StartUpViewController` | Clean & complete |
| 2 | `Main` | Post-startup root | `MainViewController`, `MainTabbarController` (5 tabs) | Clean & complete |
| 3 | `Today` | Tab 1 (root) | `TodayViewController`, `DailyRadarCardViewController`, `TodayLifeHubView`, `TodayScenarioBannerView` | Fixed (`F05`), Deduped (`R04`), overlaps kept (`K01`, `K04`, `K05`) |
| 4 | `Home` | Pushed from `Today` & `Discover` | `HomeViewController` (Level list + Level content) | **P0 Fixed (`F01`)** — replaced `showMeaning` alert with `LevelEntryDetail` |
| 5 | `LevelEntryDetail` *(new)* | Pushed from `Home` (Level content) | `LevelEntryDetailViewController` (Vocab / Kanji / Grammar) | Added in `7d3465c` |
| 6 | `LessonList` | Pushed from `Home` & `LevelEntryDetail` | `LessonListViewController` | Clean & complete |
| 7 | `LessonReader` | Pushed from `LessonList` & `Today` | `LessonReaderViewController`, `ShadowingViewController` | Clean & complete |
| 8 | `LessonPractice` | Pushed from `LessonReader` | `LessonPracticeViewController` | Fixed (`F10` title wiring) |
| 9 | `LifeLesson` | Pushed from `Today` Life Hub | `LifeLessonViewController` (4-step flow) | Clean & complete |
| 10 | `Scenario` | Pushed from `Today` Scenario Banner | `ScenarioListViewController`, `ScenarioPlayViewController` | Clean & complete |
| 11 | `Dictionary` | Tab 2 (root) | `DictionaryViewController` | Clean & complete |
| 12 | `DictionaryEntry` | Pushed from `Dictionary`, `DictionarySaved`, `LevelEntryDetail` | `DictionaryEntryViewController` (vocab/kanji/grammar/sentence) | Clean & complete (cross-tab `showSearch` fixed in `7d3465c`) |
| 13 | `DictionaryHandwriting` | Presented from `Dictionary` | `DictionaryHandwritingViewController` | Clean & complete |
| 14 | `DictionarySaved` | Pushed from `Dictionary` | `DictionarySavedViewController` | Fixed (`F09` stale footer & auth refresh) |
| 15 | `DictionaryScan` | Presented from `Dictionary` | `DictionaryScanViewController` | Clean & complete |
| 16 | `DictionaryVoice` | Presented from `Dictionary` | `DictionaryVoiceViewController` | Clean & complete |
| 17 | `Card` | Tab 3 (root) | `CardViewController`, `NewDeckOptionsViewController` | Fixed (`F10` search enablement), Cleaned (`R02` `CardInteractor`, `R04` flow dedup) |
| 18 | `CardReview` | Pushed from `Card` (Review scope) | `CardReviewViewController` | Clean & complete (`K04`) |
| 19 | `CardStudy` | Pushed from `Card`, `Today`, `OftenMissed`, `RemoteDeck`, `LifeLesson`, `MagazineArticle` | `CardStudyViewController`, `KanjiWritingViewController` | Fixed (`F04` KanjiWriting, `F07` typed-incorrect summary label) |
| 20 | `CardStyle` | Presented from `CardStudy` | `CardStylePickerViewController` | Clean & complete |
| 21 | `CreateDesk` | Presented from `Card`, `CardStudy`, `Today`, `DeckGenerator` | `CreateDeskViewController`, `BulkImportViewController`, `PictureSearchViewController` | Clean & complete (`K02`, `K08`) |
| 22 | `DeckGenerator` | Presented from `Card` & `Today` | `DeckGeneratorViewController` | Clean & complete (`K02`, `R04`) |
| 23 | `ExampleEditor` | Presented from `CardStudy` | `ExampleEditorViewController` | Fixed (`F08` error banner & swipe-dismiss delegate) |
| 24 | `OftenMissed` | Pushed from `Card` | `OftenMissedViewController` | Fixed (`F03` pass targeted missed `cardIDs`) |
| 25 | `RemoteDeck` | Pushed from `Card` | `RemoteDeckViewController`, `SharedDeckViewController` | Fixed (`F06` duplicate local copy, `F10` stop-sharing icon), Removed (`R03` duplicate Save menu item) |
| 26 | `Discover` | Tab 4 (root) | `DiscoverViewController`, `DiscoverHeroView`, `DiscoverFindCard` | Fixed (`F02` second tap opens article) |
| 27 | `Magazine` | Pushed from `Discover` | `MagazineViewController`, `MagazineArticleViewController` | Clean & complete |
| 28 | `Loto` | Pushed from `Discover` | `LotoViewController`, `LotoLabView`, `LotoChaosPanelView` | Clean & complete |
| 29 | `Setting` | Tab 5 (root) | `SettingViewController`, `DataExportViewController` | Fixed (`F10` About chevron), Removed (`R01` `SettingsPrototypes.swift`, `R02` `VersionFooterView`) |
| 30 | `MailLogin` | Root from `Setting` / Modal from 8 callers | `MailLoginViewController` | Clean & complete (`K08`) |

> All 30 module folders (29 original + new `LevelEntryDetail`) are reachable from live navigation starting at `StartUpWireframe` → `MainWireframe`. Zero orphan modules remain.

---

## 2. Unfinished Features & Incomplete UX Findings (`FIX`)

### F01 — [P0 · FIX] Level content entries use alert-as-content (`showMeaning`) instead of a detail screen
- **Evidence:**
  - `FlashcardApp/Modules/Home/HomePresenter.swift:135-139`: `selectRow(at:kind:)` called `wireframe.showMeaning(title:message:)`.
  - `FlashcardApp/Modules/Home/HomeWireframe.swift:5, 35-37`: `showMeaning` called `BaseWireframe.showAlert(with:message:)`.
  - `FlashcardApp/Modules/Home/Cells/HomeCells.swift:451`: `ContentRowCell` displayed `accessoryType = .disclosureIndicator`.
  - `FlashcardApp/Networks/BJTClient/Models/BJTLevelDTO.swift:31-60`: Backend DTOs already carry backend UUID `id`, `headword`/`character`/`pattern`, `reading` or separate `onyomi`/`kunyomi`, `shortMeaningVi`/`meaningVi`, full `senses[].meaningVi` (vocab) and `details[].explanationVi` (grammar). All three IDs resolve HTTP 200 on `BJTDictionaryAPI` (`/content/lexemes/{id}`, `/kanji/{id}`, `/content/grammar/{id}`).
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `7d3465c` (`feat(home): replace showMeaning alert with LevelEntryDetail screen`). Added VIPER module `Modules/LevelEntryDetail/` (`LevelEntryDetailPresenter`, `LevelEntryDetailViewController`, `LevelEntryDetailWireframe`) using `DesignSystem` tokens, `StateView` for empty meanings, scrollable senses/explanations, separate Kanji On'yomi/Kun'yomi card, Japanese TTS `"Listen"`, Copy/Share menu, `"Open full dictionary entry"` action (plus safe cross-tab `DictionaryEntryWireframe.showSearch(for:)`), and `"Lessons for <level>"` link. Removed `showMeaning` completely, added 4 vi/en/ja keys to `Localizable.xcstrings`, added 6 tests in `LevelEntryDetailPresenterTests`, updated `HomePresenterTests` & `FlashcardAppUITests`. Verified with before/after screenshots (`shots/`) and live push into `DictionaryEntry`.

### F02 — [P1 · FIX] Discover "Today's find" sealed card does nothing on second tap
- **Evidence:**
  - `FlashcardApp/Modules/Discover/DiscoverHeroViews.swift:58, 225-238`: Doc comment promised *"tap again to read the article"*, but `tapped()` ignored taps once `isRevealed == true` and switched `accessibilityTraits` to `.staticText`.
  - `FlashcardApp/Modules/Discover/DiscoverPresenter.swift:11-14, 78-85`: `DiscoverFind` discarded `item.slug` and `item.day`.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `d717754` (`fix(discover): open Magazine article on second tap of Today's find card`). Preserved `slug` & `day` in `DiscoverFind`, added `DiscoverPresenter.openFind()` → `DiscoverWireframe.showMagazineArticle(slug:day:)`, added `"Read article"` + chevron affordance & `.button` trait on revealed face, and added unit test in `DiscoverPresenterTests`.

### F03 — [P1 · FIX] `OftenMissed` opens the entire deck instead of targeting missed cards
- **Evidence:**
  - `FlashcardApp/Modules/OftenMissed/OftenMissedPresenter.swift:53-56` & `OftenMissedWireframe.swift:15-17`: `selectRow(at:)` called `CardStudyWireframe(deckId:)` with `cardIDs: nil` even though `CardStudyWireframe` supports `cardIDs: [String]?`.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `28548f0` (`fix(often-missed): study targeted missed cards starting from the tapped card`). Passes the deck's often-missed `cardIDs` with the tapped card ordered first into `CardStudyWireframe(deckId:cardIDs:)`, verified by updated `OftenMissedPresenterTests`.

### F04 — [P1 · FIX] `KanjiWriting` dead-end finish screen & broken reversed-direction decks
- **Evidence:**
  - `FlashcardApp/Modules/CardStudy/Views/KanjiWritingViewController.swift:163-168`: `.finished` rendered bare `StateView.empty` with no action button.
  - `FlashcardApp/Modules/CardStudy/KanjiWritingPresenter.swift:24-35`: `KanjiWritingQuestions.make` only scanned `card.front`, failing on Vietnamese→Japanese decks.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `af13e45` (`fix(kanji-writing): support reversed decks and add Practise again action on finish`). Added `restart()` + `StateView.call` (`"Practise again"`) on `.finished`, added fallback to `card.back` when `card.front` has no kanji, and added regression tests in `KanjiWritingTests`.

### F05 — [P1 · FIX] `TodayScenarioBannerView` horizontal chip scroll is blocked by parent view
- **Evidence:**
  - `FlashcardApp/Modules/Today/TodayScenarioBanner.swift:16, 63-77, 86`: `column.isUserInteractionEnabled = false` blocked all scrolling on `chipScroll`.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `a9e0168` (`fix(today): allow horizontal scrolling on TodayScenarioBannerView category chips`). Kept `header`/`detail`/`cta` non-interactive while routing `hitTest` inside `chipScroll` to `chipScroll` with a tap recognizer forwarding taps to `.touchUpInside`.

### F06 — [P2 · FIX] Opening an uploaded deck on account and tapping "Study" duplicates the local deck
- **Evidence:**
  - `FlashcardApp/Interactors/CardLibraryServerInteractor.swift:118-136`: `hasDeviceCopy` checked `DeckAccountLinks`, but `saveToDevice(_:)` ignored it and imported a duplicate local copy.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `44f4049` (`fix(remote-deck): reuse linked local deck in saveToDevice instead of duplicating`). Reuses `links.deviceDeckId(forAccount:)` when still present in `repository`, verified by new regression test in `CardLibraryServerInteractorTests`.

### F07 — [P2 · FIX] `StudySummaryView` mislabels typed-incorrect cards as `"Self-rating"`
- **Evidence:**
  - `FlashcardApp/Modules/CardStudy/Views/StudyReviewViews.swift:256-257`: Checked `card.result == .incorrect` only, omitting `.typedIncorrect`.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `015f9aa` (`fix(card-study): label typed-incorrect cards as Incorrect in StudySummaryView`).

### F08 — [P2 · FIX] `ExampleEditorViewController` error display & swipe-dismiss guard bugs
- **Evidence:**
  - `FlashcardApp/Modules/ExampleEditor/Views/ExampleEditorViewController.swift:37, 105-106`: Set `problemLabel.text` instead of `problemLabel.show(_:)` and attached `presentationController?.delegate` in `viewDidLoad` instead of `viewDidAppear`.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `c5e94d4` (`fix(example-editor): render error icon via show(_:) and attach dismiss delegate in viewDidAppear`).

### F09 — [P2 · FIX] `DictionarySaved` stale footer across category switches & missed sign-out refresh
- **Evidence:**
  - `FlashcardApp/Modules/DictionarySaved/DictionarySavedViewController.swift:66-99`: Did not clear `tableView.tableFooterView` on non-loaded states.
  - `FlashcardApp/Modules/DictionarySaved/DictionarySavedPresenter.swift:59-65`: Ignored auth changes occurring off-screen.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `4a0ffdd` (`fix(dictionary-saved): clear stale footer on state change and refresh on auth transitions`). Cleared `tableFooterView` on non-loaded states, tracked `signedInWhenLoaded` to reload on auth transitions, and added regression test in `DictionarySavedTests`.

### F10 — [P2 · FIX] Small interactive/UI polish bugs across `Card`, `RemoteDeck`, `LessonPractice`, and `Setting`
- **Evidence:**
  - `CardViewController.swift:209`: Disabled search when `deckCount == 0` even when `"On your account"` decks existed.
  - `RemoteDeckViewController.swift:175`: Used `"link.badge.plus"` for `"Stop sharing"`.
  - `LessonPracticeViewController.swift:58`: Never applied `presenter.title`.
  - `SettingPresenter.swift:583-588`: `"About Flashcard"` had `disclosure: true` despite presenting an alert.
- **Verdict:** **FIX**
- **Resolution:** **DONE** — Commit `c2154de` (`fix(ui): enable account-deck search, set practice title, fix stop-sharing icon and About chevron`).

---

## 3. Dead / Prototype Code & Redundant UI Entry Points (`REMOVE`)

### R01 — [REMOVE] Unreferenced SwiftUI prototype file compiled into Release target
- **Evidence:** `FlashcardApp/Modules/Setting/Prototypes/SettingsPrototypes.swift:1-682` (unreferenced SwiftUI prototypes with empty actions and hardcoded fake metrics, compiled into Release binary).
- **Verdict:** **REMOVE**
- **Resolution:** **DONE** — Commit `883a60e` (`chore(setting): remove dead SettingsPrototypes.swift from Release target`). Deleted file/folder and removed from `project.pbxproj`.

### R02 — [REMOVE] Dead `VersionFooterView` + empty `CardInteractor` stub
- **Evidence:** `Setting/Views/VersionFooterView.swift` + `.xib` (hardcoded `"Version 1.0.0"`, 0 callers) and `Interactors/CardInteractor.swift` (empty protocol/class).
- **Verdict:** **REMOVE**
- **Resolution:** **DONE** — Commit `6de9253` (`chore(cleanup): remove dead VersionFooterView and empty CardInteractor stub`). Removed all 3 files from disk and `project.pbxproj`, simplified `CardPresenter`, `CardWireframe`, and 3 test suites.

### R03 — [REMOVE] Redundant `"Save to this device"` action in `RemoteDeckViewController` `•••` menu
- **Evidence:** `RemoteDeckViewController.swift:157-161` duplicated the pinned bottom `saveButton` (`lines 60-65`, which has inline spinner feedback and explanatory footnote).
- **Verdict:** **REMOVE**
- **Resolution:** **DONE** — Commit `7d06f02` (`refactor(remote-deck): remove redundant Save to this device action from overflow menu`). Removed duplicate menu action and hid `rightBarButtonItem` when the overflow menu has no items.

### R04 — [REMOVE] Duplicated new-deck creation orchestration between `TodayWireframe` and `CardWireframe`
- **Evidence:** `TodayWireframe.swift:44-73` duplicated the sheet/generator/editor presentation logic of `CardWireframe.swift:57-79`.
- **Verdict:** **REMOVE** (deduplicated orchestration while keeping Today's empty-state CTA)
- **Resolution:** **DONE** — Commit `872340d` (`refactor(deck-creation): deduplicate NewDeckFlow presentation across CardWireframe and TodayWireframe`). Extracted shared `NewDeckFlow` helper reused by both wireframes.

### R05 — [REMOVE] Dead legacy `Commons/` UI components compiled into Release target
- **Evidence:** Zero callers in Swift, storyboards, XIBs, or tests: `PlaceholderView.swift`, `RoundCornerButton.swift`, `RoundCornerView.swift`, `RoundedImageView.swift`, `AppColor.swift`, `Extensions/Color.swift`.
- **Verdict:** **REMOVE**
- **Resolution:** **DONE** — Commit `e3da636` (`chore(commons): remove unreferenced legacy UI views and AppColors shim`). Deleted all 6 files and removed from `project.pbxproj`.

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

## 5. Phase B Execution Log & Verification Evidence

### Commit History (`main..HEAD`)

| Finding | Commit | Summary |
|---|---|---|
| Phase A | `d2e0267` | `docs(audit): add whole-app completion and dedup audit report` |
| `F01` | `7d3465c` | `feat(home): replace showMeaning alert with LevelEntryDetail screen` |
| `F02` | `d717754` | `fix(discover): open Magazine article on second tap of Today's find card` |
| `F03` | `28548f0` | `fix(often-missed): study targeted missed cards starting from the tapped card` |
| `F04` | `af13e45` | `fix(kanji-writing): support reversed decks and add Practise again action on finish` |
| `F05` | `a9e0168` | `fix(today): allow horizontal scrolling on TodayScenarioBannerView category chips` |
| `F06` | `44f4049` | `fix(remote-deck): reuse linked local deck in saveToDevice instead of duplicating` |
| `F07` | `015f9aa` | `fix(card-study): label typed-incorrect cards as Incorrect in StudySummaryView` |
| `F08` | `c5e94d4` | `fix(example-editor): render error icon via show(_:) and attach dismiss delegate in viewDidAppear` |
| `F09` | `4a0ffdd` | `fix(dictionary-saved): clear stale footer on state change and refresh on auth transitions` |
| `F10` | `c2154de` | `fix(ui): enable account-deck search, set practice title, fix stop-sharing icon and About chevron` |
| `R01` | `883a60e` | `chore(setting): remove dead SettingsPrototypes.swift from Release target` |
| `R02` | `6de9253` | `chore(cleanup): remove dead VersionFooterView and empty CardInteractor stub` |
| `R03` | `7d06f02` | `refactor(remote-deck): remove redundant Save to this device action from overflow menu` |
| `R04` | `872340d` | `refactor(deck-creation): deduplicate NewDeckFlow presentation across CardWireframe and TodayWireframe` |
| `R05` | `e3da636` | `chore(commons): remove unreferenced legacy UI views and AppColors shim` |

### Visual Evidence (`docs/plans/completion-2026-11-26/shots/`)
Captured on iPhone 17 Simulator (`AAEE78CE-966D-4502-B637-C4A5C83CDC36`, iOS 27.2) running `FlashcardApp-Production` against live `https://kiokoto.com/api` (`J4 — Sơ trung cấp`):
- **Before (alert-as-content):** `shots/before_level_entry_light.png`, `shots/before_level_entry_dark.png`
- **After (`LevelEntryDetail`):**
  - Vocabulary (`あっ`): `shots/after_level_entry_light.png`, `shots/after_level_entry_dark.png`, `shots/after_level_entry_ax.png` (AX-XXL, zero clipping, adaptive button corners)
  - Kanji (`会` + live verified push to `DictionaryEntry`): `shots/after_level_entry_kanji_light.png`
  - Grammar (`… いぜん`): `shots/after_level_entry_grammar_light.png`

### Build & Test Verification
- **Environment validation (`sh scripts/tests/environment-validation.sh`):** **26/26 passed**
- **iOS Simulator Scheme Builds (`CODE_SIGNING_ALLOWED=NO`):**
  - `FlashcardApp`: **BUILD SUCCEEDED**
  - `FlashcardApp-Local`: **BUILD SUCCEEDED**
  - `FlashcardApp-Production`: **BUILD SUCCEEDED**
- **Full `FlashcardAppTests` suite (including `LocalizationTests`):**
  - **Executed:** `1561` tests
  - **Passed:** `1548` tests (`0 failures`, `0 unexpected`)
  - **Skipped:** `13` tests (baseline opt-in/unsigned skips: 5 `KeychainAuthTokenManagerTests`, 7 `LiveProductionContractTests`, 1 `LocalBackendReviewSyncTests`)
  - **`LocalizationTests`:** `10/10` passed
  - **`LevelEntryDetailPresenterTests`:** `6/6` passed
  - **`HomePresenterTests`:** `17/17` passed
  - **`DiscoverPresenterTests`:** `9/9` passed
  - **`OftenMissedPresenterTests`:** `6/6` passed
  - **`KanjiWritingPresenterTests` + `KanjiWritingQuestionsTests`:** `5/5` passed
  - **`CardLibraryServerInteractorTests`:** `18/18` passed
  - **`DictionarySavedPresenterTests`:** `12/12` passed
