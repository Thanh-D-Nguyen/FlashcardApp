# Splash / startup redesign

Skills read and used: `ui-ux-pro-max` (contrast, motion, accessibility checklist), `apple-skills:design`
(HIG launch behavior, Dynamic Type, text roles), `liquid-glass:liquid-glass` (decision tree: no glass on
launch or content surfaces; system chrome only). HIG won every conflict.

## Verified startup flow (before)

`LaunchScreen.storyboard` (white `systemBackground`) → `SceneDelegate.willConnectTo` builds the window
(applies saved appearance) → `StartUpViewController` (old blue/white splash, "Preparing Data...(0.0/100.0)")
→ `RealmService.configuration` (copy bundled 126 MB store if missing, open Realm on the main thread)
→ animated slide to `MainWireframe` (tab bar). Auth is **not** on the launch path: `AuthSession` is only
used by Settings/login interactors. No network call, `sleep` or `asyncAfter` in startup. One scene, one run
of `willConnectTo`; the stale `UISceneStoryboardFile=Main` does not instantiate a second `MainViewController`
(checked with a temporary log).

## Problems found

1. Splash used a fixed white background and a blue palette: white in dark mode and a third color between
   launch screen and Home.
2. The "percent" was fake: the copy reports only 0 then 100.
3. The slide push into Main cost 610–620 ms on every launch, including warm ones.
4. Realm failure was a dead end (endless spinner behind an OK alert, no retry).
5. The presenter called `RealmService` directly (interactor empty) and re-ran the bootstrap on every
   `viewWillAppear`.

## Direction

Concepts: A editorial (mark + type), B native (empty surface continuing into the real UI), C learning identity
(logo/kanji). Chosen: **B, with the editorial identity carried by Home**. A launch screen cannot be localized
or know the saved appearance, so any mark or text would flash and then jump; HIG also says not to brand it. The
existing logo (blue gradient tile) clashes with the indigo/washi system and was not reused.

- Launch screen: empty view, `LaunchBackground` asset = `Design.Color.background` (`#F6F3ED` / `#0F0F10`).
- `StartUp`: same surface, nothing drawn. After 0.4 s of real pending work it fades in the shared `StateView`
  loading state ("Preparing your offline lessons…", vi/ja translated, no percentage). Failure shows the
  localized reason with Retry. Hand-off is an invisible cut, or a 0.3 s cross-fade away from a visible
  loading state. Reduce Motion: no fades. No Liquid Glass here; the glass tab bar of Home is the only chrome.

## Evidence

| File | What |
| --- | --- |
| `before_splash_light.png` | Old splash (fresh install, iPhone 17e) |
| `after_loading_{light,dark}_iphone17e.png` | Loading state (6 s delay injected in a scratch copy, never committed) |
| `after_failure_{light,dark}_iphone17e.png` | Real failure path: corrupted store in the simulator sandbox |
| `after_retry_recovered_home_iphone17e.png` | Store restored, Retry reopens it and enters Home |
| `after_home_{light,dark}_{iphone17,iphone17e}.png` | First usable screen after a warm launch |

Frame analysis of simulator video (warm launch, light and dark): no white frame between launch and Home; the
slow path went loading → 3 intermediate frames → Home with brightness steady (238).

## Measurements

Scene connect → Home visible, debug build, iPhone 17 simulator (iOS 27.0), 5 warm launches, `os_log` timestamps:

| | mean | range |
| --- | --- | --- |
| before | 842 ms | 805–881 |
| after | 294 ms | 281–306 |

Realm open stays on the main thread (Realm objects are thread-confined); ~125–140 ms warm.

## Not verified / limits

- The system launch screen as an image: `simctl launch` shows a black placeholder before the first app frame
  (the old build too). The storyboard is verified structurally (`LaunchScreenStoryboardTests`: empty view, color
  equals `Design.Color.background` in both appearances) and by the asset test.
- Physical device, iOS 26.x runtime, Reduce Motion and VoiceOver were not run. Timings are simulator/debug.
- The launch screen follows the system appearance, the app follows the saved in-app choice: a user who forces
  dark in-app on a light system still sees the light launch surface first. iOS offers no fix.
- Loading text uses `secondaryLabel` from the shared `StateView` (about 3.2:1 on the light surface, passes as
  large text); left unchanged to avoid restyling Home.
