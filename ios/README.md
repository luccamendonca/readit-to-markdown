# Readit iOS

iOS share-extension companion to the Go `readit-to-markdown` CLI. Share any URL → fetch, extract, convert to Markdown → write into a user-picked vault folder, using the same frontmatter contract as the CLI (`title`, `summary`, `date`, `url`, `read_time`).

> **Status:** scaffolding only. The pure-data layer (`Slug`, `Filename`, `ReadTime`, `Frontmatter`, `URLParse`) is a direct port of the Go CLI with mirrored tests. The HTML pipeline is a stub — see [Open work](#open-work) below.

## Layout

```
ios/
├── project.yml                    # XcodeGen — generates Readit.xcodeproj
├── Packages/
│   └── ReaditCore/                # Shared SPM package (App + ShareExtension)
│       ├── Sources/ReaditCore/
│       │   ├── Slug.swift           ✅ ported + tested
│       │   ├── Filename.swift       ✅ ported
│       │   ├── ReadTime.swift       ✅ ported + tested
│       │   ├── Frontmatter.swift    ✅ ported + tested
│       │   ├── URLParse.swift       ✅ ported
│       │   ├── Fetcher.swift        🟡 written, not yet exercised on device
│       │   ├── Pipeline.swift       🟡 dispatch ported; HTML mode is a stub
│       │   └── VaultBookmark.swift  🟡 written, not yet exercised on device
│       └── Tests/ReaditCoreTests/
├── App/                           # SwiftUI host app (settings + folder picker)
└── ShareExtension/                # Action target invoked from the iOS share sheet
```

## Setup

### Prerequisites

- macOS with **Xcode 16+**
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated, not committed
- An Apple ID for signing (free works for personal device install; paid Developer Program needed for TestFlight / App Store)

### Generate and open the project

```sh
cd ios
xcodegen generate
open Readit.xcodeproj
```

### One-time signing setup in Xcode

1. Select the `Readit` target → **Signing & Capabilities** → set **Team** to your Apple ID.
2. Repeat for the `ReaditShare` target.
3. Both targets already have the **App Groups** capability enabled in the entitlements files — verify the group ID matches `group.com.luccamendonca.readit` (or rename consistently across `project.yml`, both `.entitlements` files, `App/AppConfig.swift`, and `ShareExtension/ShareViewController.swift`).

### Run on device

1. Plug in iPhone, trust the Mac, select it as the run destination.
2. Build & run (⌘R).
3. On the device: Settings → General → VPN & Device Management → trust the developer cert.
4. Open **Readit** once → tap **Pick folder…** → select the Obsidian vault folder (typically inside `iCloud Drive › Obsidian › <YourVault>`).
5. In Safari → Share → **Readit**. The article saves into the picked folder.

### Run package tests (without Xcode)

The `ReaditCore` package builds and tests on macOS or any Linux with a Swift 5.9+ toolchain:

```sh
cd ios/Packages/ReaditCore
swift test
```

## Open work

### 1. HTML readability + Markdown conversion

`Pipeline.processHTML` currently falls back to a stub. Two viable paths, ranked:

1. **Reuse Mozilla's `Readability.js` in a hidden `WKWebView`.** Most desktop read-later apps do this and it tracks upstream improvements automatically. Cost: one `WKWebView`, ~150 lines of glue. Cleanest output quality.
2. **Pure-Swift Readability port.** Several exist on GitHub — needs verification of which is currently maintained and license-compatible (GPLv3 in this repo, so MIT/Apache/BSD ports are fine).

Pair with a tiny HTML→Markdown converter built on [**SwiftSoup**](https://github.com/scinfu/SwiftSoup) (~200 lines: `<h1>`–`<h6>`, `<p>`, `<a>`, `<ul>`/`<ol>`, `<code>`/`<pre>`, `<img>`, `<blockquote>`, inline `<em>`/`<strong>`).

### 2. Multi-URL ingestion

Per the agreed plan: accept a `.txt` file shared from the Files app, split on newlines, keep `http(s)` URLs, drop the rest silently — then run the pipeline once per URL. The CLI gets the same `--file` flag; the spec change lives in `openspec/specs/clipboard-capture/` (or a new `multi-url-input/` capability) and is the single source of truth for both clients.

### 3. Confirmation UI

`ShareViewController.finish(...)` currently dismisses silently. A 0.5–1s success toast or a small banner with the saved filename would match the desktop notification UX.

### 4. CI

A GitHub Actions job that runs `swift test` on the `ReaditCore` package would catch regressions in the shared pure-data layer before they reach the iOS build.

## Distribution options

| Path | Cost | Refresh cadence | Setup effort |
|------|------|-----------------|--------------|
| Personal sideload (free Apple ID) | $0 | Every 7 days via Xcode | Lowest |
| TestFlight (Developer Program) | $99/yr | 90-day builds | Medium |
| App Store | $99/yr + review | n/a | Highest |
| AltStore / Sideloadly | $0 | Varies | Medium |

For a personal tool, sideloading or TestFlight (so the family/friends can grab it) are the realistic options.
