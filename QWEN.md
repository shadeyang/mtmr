# QWEN.md — MTMR (My TouchBar. My Rules.)

Instructional context for AI agents working in this repository.

---

## Project Overview

**MTMR** is a macOS menu-bar app that fully replaces the MacBook Pro TouchBar with a user-defined
layout. It is a JSON-configured TouchBar customization platform — essentially an open-source
alternative to BetterTouchTool.

- **Language:** Swift 5.0 (`SWIFT_VERSION = 5.0`)
- **Platform:** macOS, `MACOSX_DEPLOYMENT_TARGET = 11.0`
- **Architecture:** Universal binary — `ARCHS="arm64 x86_64"` (Intel + Apple Silicon)
- **Bundle ID:** `Toxblh.MTMR` · **Team:** `D6D8BR2QNB` · **Code signing:** Manual
- **App type:** `LSUIElement = true` — menu-bar-only agent, no Dock icon, no main window
- **Auto-update:** Sparkle, vendored at `Sparkle.framework/` (not SPM)
- **Dependencies:** Sparkle.framework only. No SPM, CocoaPods, Carthage, or Makefile.
- **Upstream:** https://github.com/Toxblh/MTMR

The TouchBar is presented as a *system modal* bar via private API, which is why the app lives in
`CBridge/` and calls `DFRElementSetControlStripPresenceForIdentifier` and
`presentSystemModalTouchBar`. This private-API dependency is inherent to the product — there is no
public alternative for a third-party app to own the whole TouchBar.

---

## Architecture

The data flow is: **JSON preset → `BarItemDefinition` → `NSTouchBarItem` → TouchBar.**

```
items.json
   │
   ▼  Data.barItemDefinitions()                    [ItemsParsing.swift]
BarItemDefinition (Decodable)
   │      └── SupportedTypesHolder.lookup(by:actions:)
   │            ├── static table (built-in keys: escape, volumeUp, cpu, …)
   │            └── runtime registrations (TouchBarController.init: exitTouchbar, close)
   ▼
ItemType enum  +  GeneralParameter dict  +  [Action]
   │
   ▼  TouchBarController.createAndUpdatePreset / loadItemDefinitions
[BarItemDefinition] bucketed into left / center / right
   │
   ▼  Identifiers built as identifierBase + timestamp + UUID
NSTouchBarItem / NSViewController (Widgets/)
```

### Directory map

| Path | Role |
|---|---|
| `MTMR/AppDelegate.swift` | `@NSApplicationMain`. Sparkle setup, Accessibility prompt, status-bar menu, live config-file watcher. |
| `MTMR/TouchBarController.swift` | **Singleton** (`TouchBarController.shared`), `NSTouchBarDelegate`. Owns the whole pipeline: parse → lay out left/center/right → build items → present/dismiss. Also registers runtime item types. |
| `MTMR/ItemsParsing.swift` | 821-line heart of config parsing. `BarItemDefinition`, `ItemType`, `Action`, `GeneralParameter`, `Source`, `SupportedTypesHolder`. |
| `MTMR/Widgets/` | 19 native widgets (battery, cpu, currency, dock, music, network, pomodoro, weather, upnext, …), each conforming to `Widget`. |
| `MTMR/CBridge/` | Objective-C private-API bridge: `TouchBarPrivateApi`, `LaunchAtLoginController`, `AMR_ANSIEscapeHelper` (ANSI color parsing for script output), `CBBlueLightClient`, `DeprecatedCarbonAPI`. |
| `MTMR/AppleScripts/*.scpt` | Bundled `.scpt` scripts users can reference by path in presets. |
| `MTMR/defaultPreset.json` | Seed preset copied to the user's Application Support dir on first launch. |
| `MTMR/CustomButtonTouchBarItem.swift` | Base class most widgets subclass. |
| `MTMR/CustomSlider.swift`, `ScrollViewItem.swift`, `SwipeItem.swift`, `BasicView.swift` | Sliders, scroll views, multi-finger swipe capture, center basic view. |
| `MTMR/AppSettings.swift` | `@UserDefault` property wrapper; keys prefixed `com.toxblh.mtmr.*`. |
| `MTMRTests/` | XCTest bundle — decoding-level unit tests only. |
| `Resources/` | README images, community preset examples (`*.json`), logo, Sketch file. |
| `Sparkle.framework/` | Vendored binary. Do not replace casually — PR #441 updated it for M1 local builds. |

### Configuration model

- User config: `~/Library/Application Support/MTMR/items.json`
- Seeded from bundled `MTMR/defaultPreset.json` on first run (`TouchBarController.reloadStandardConfig`)
- **Hot-reloaded** — `AppDelegate.reloadOnDefaultConfigChanged()` watches the file with a
  `DispatchSource` and calls `reloadPreset` on write. Edits to `items.json` take effect immediately
  while the app runs.
- `README.md` is the authoritative **user-facing config reference** (all item types, actions,
  triggers, general parameters). Any new item type or parameter must be documented there.

### Adding a new widget

1. Create `MTMR/Widgets/YourWidgetBarItem.swift`.
2. Subclass `CustomButtonTouchBarItem` (or `NSViewController` for custom-drawn ones) and conform
   to `Widget`, providing `static var name`, `static var identifier`, and
   `static var decoder: ParametersDecoder`.
3. Add a case to the `ItemType` enum in `ItemsParsing.swift`.
4. Add a branch to `ItemType.identifierBase` in `TouchBarController.swift` — **this is easy to
   forget**, and a missing branch will not compile-fail loudly elsewhere.
5. Wire the item construction in `TouchBarController` (`makeBarItem(_:)`).
6. Document the JSON shape in `README.md`.
7. Add a decoding test in `MTMRTests/`.

Types that need runtime closures (`exitTouchbar`, `close`) are registered in
`TouchBarController.init` via `SupportedTypesHolder.sharedInstance.register(typename:)` instead of
the static table.

---

## Build, Test, Run

### Prerequisites

```bash
sudo gem install xcpretty      # both build scripts pipe xcodebuild through it
npm i -g create-dmg            # only for build.sh / test.sh DMG packaging
```

Building requires **macOS with Xcode** — TouchBar APIs only exist on real MacBook Pro hardware, so
there is no simulator path for manual verification. `SPARKLE` signing (`~/Sparkle/bin/sign_update`)
and the `scp` to the release host in `build.sh` only run for the maintainer.

### Run tests

```bash
xcodebuild test -project MTMR.xcodeproj -scheme 'UnitTests' | xcpretty -c
```

Use the **`UnitTests`** scheme (targets `MTMRTests`), *not* the `MTMR` scheme. This is exactly what
CI runs.

### Local build and launch

```bash
./test.sh     # archive → export .app → create-dmg → open the app
```

Note: despite the name, `test.sh` **does not run tests** — it does a release archive and opens the
built app. Its architecture step does not override `ARCHS`, so it builds for the host arch only.

### Release build (maintainer only)

```bash
./build.sh    # universal archive → DMG → appcast.xml → Sparkle sign → scp to do:/var/www/mtmr
```

`build.sh` ends with `scp` to a private host and will fail without maintainer credentials. Use the
CI equivalent instead for verification:

```bash
xcodebuild archive -project MTMR.xcodeproj -scheme MTMR \
  -archivePath Release/App.xcarchive \
  DEVELOPMENT_TEAM="" CODE_SIGN_IDENTITY="" ARCHS="arm64 x86_64" | xcpretty -c
lipo -info Release/App.xcarchive/Products/Applications/MTMR.app/Contents/MacOS/MTMR
```

The empty `DEVELOPMENT_TEAM` / `CODE_SIGN_IDENTITY` overrides are how CI builds unsigned. Adopt them
locally unless you hold the real certificate.

### CI (`.github/workflows/`)

- `build-test.yml` — on every push/PR: runs `UnitTests`, builds the universal archive, verifies with
  `lipo`. **Both must pass.**
- `publish.yml` — on `master` push or `v*` tag: builds DMG and creates a GitHub Release.

### Versioning

`MTMR/Info.plist` is edited **directly by hand**. `CFBundleVersion` (build) and
`CFBundleShortVersionString` (version) are literal values. A pre-build Run Script phase
auto-increments `CFBundleVersion` via `PlistBuddy`, so local builds dirty `Info.plist` — this is
expected, and the bump is normally reverted or committed deliberately at release time.

---

## Development Conventions

### Code style

- 4-space indentation, Swift standard naming, standard library types preferred.
- Files begin with a header block; follow it for new files:
  ```swift
  //
  //  YourFile.swift
  //  MTMR
  //
  //  Created by Author on dd.MM.yyyy.
  //  Copyright © 2018 Anton Palgunov. All rights reserved.
  //
  ```
  (Newer files, especially in `MTMRTests/`, omit the header — both are present in the repo.)
- **No linter or formatter is configured** (no SwiftLint, SwiftFormat, or `.editorconfig`). Match
  surrounding style by hand. Recent commits do include a few drive-by grammar/formatting fixes, so
  keep unrelated reformatting out of feature commits.

### Testing

- Tests are **decode-level unit tests**: build a JSON fixture string, run it through
  `JSONDecoder().decode([BarItemDefinition].self, from:)`, and assert on the resulting enum cases.
  They never instantiate `NSTouchBarItem` or touch real hardware.
- Fixture style is an inline multi-line string literal:
  ```swift
  let fixture = """
      [  { "type": "staticButton",  "title": "Pew" } ]
  """.data(using: .utf8)!
  ```
- Assertion style is `guard case .some(...) ? = ... else { XCTFail(); return }` — match this rather
  than switching to `XCTUnwrap`.
- Current coverage: `ParseConfigTests` (item types, actions, legacy actions, general parameters),
  `AppleScriptDefinitionTests` (inline/path/base64 sources, `~` expansion, `refreshInterval`),
  `BackgroundColorTests` (hex color + alpha).
- **`TECHNICAL_DEBT.md` explicitly lists** "extract bar items creating from TouchBarController to
  separate class, cover with tests" as a goal. New logic in `TouchBarController` should be pushed
  into a testable unit where practical.

### Rules to respect

- **README.md is a user contract.** It documents every item type, action, trigger, and parameter.
  Adding or changing a config key means updating README.md in the same change.
- **Legacy compatibility is load-bearing.** `LegacyActionType` / `LegacyLongActionType` parse the
  old single-`action` form alongside the modern `actions` array. Do not remove them; presets in the
  wild still use them.
- **Never `try!`/`force unwrap` newly introduced parsing paths.** `Data.barItemDefinitions()`
  uses `try!`, but that is pre-existing. Unknown item types must degrade to
  `.staticButton(title: "unknown")`, not throw.
- **Private API is expected here.** `CBridge/` uses undocumented symbols. Check all
  OS-version-conditional declarations before use; the header carries version comments
  (e.g. "macOS 10.14" vs "macOS 10.13").
- **Item identifiers must be unique per load.** They are composed as
  `identifierBase + timestamp + UUID`; never assume stability across reloads.

### Commit style

Conventional-ish, referencing PR numbers where applicable:

```
Add arm64 (Apple Silicon) support with universal binary (#476)
Add PLN and UAH signs to CurrencyBarItem.swift (#463)
fix: discord broken logo url (#466)
YandexWeatherBarItem: fixes in parsing (#454)
```

Short, present-tense, describes the user-visible effect. Match this.

---

## Gotchas

- **Xcode 27 rejects `MACOSX_DEPLOYMENT_TARGET = 11.0`.** The supported range is now `12.0`–`27.0.x`,
  so a stock build fails with *"The macOS deployment target 'MACOSX_DEPLOYMENT_TARGET' is set to
  11.0, but the range of supported deployment target versions is 12.0 to 27.0.x"*. Override on the
  command line rather than editing the project — the target bump is a maintainer decision:
  `xcodebuild ... MACOSX_DEPLOYMENT_TARGET=12.0`.
- **Building for Apple Silicon needs no Sparkle work.** `Sparkle.framework/Versions/B/Sparkle` is
  already a fat `x86_64 arm64` binary (PR #441), so `ARCHS=arm64` links natively.
- **`test.sh` does not run tests.** Use the `UnitTests` scheme for verification.
- **`xcpretty` and `create-dmg` may be absent.** Both shell scripts hard-require them; invoke
  `xcodebuild` directly instead of installing gems just to pipe output.
- **Ad-hoc signing for local deployment:** `CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual
  DEVELOPMENT_TEAM="" ENABLE_HARDENED_RUNTIME=NO` produces a launchable bundle without a Developer ID
  (verified `valid on disk` / `satisfies its Designated Requirement`). Sparkle auto-update will not
  work under an ad-hoc signature.
- **Adding an `ItemType` case without updating `ItemType.identifierBase`** in
  `TouchBarController.swift` leaves the widget unreachable.
- **The app needs Accessibility permission.** Without it, `hidKey` actions (Esc, volume,
  brightness) and gestures silently do nothing. Cannot be tested headlessly.
- **Config is hot-reloaded** — an unexpected visual change is often just a stray edit to the live
  `~/Library/Application Support/MTMR/items.json`.
- **macOS 11.0+ deployment target** — TouchBar Macs running older macOS are out of scope; the
  README badge claiming 10.12.2 is stale.
- **Sparkle.framework is checked into git.** Treat framework updates as deliberate, isolated changes.
- **New architecture (Apple Silicon) Macs without a TouchBar** cannot display this app's output —
  verification requires TouchBar hardware.