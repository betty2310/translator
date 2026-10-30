# Product & Technical Decisions

Settled during the initial design interview (2026-10-18). Change these only with the owner's agreement; record changes here with a date.

## Context

- Single user (the owner), open-sourced on GitHub (`betty2310`).
- Inspired by Raycast Translator (a Pro-only feature): a native, instant, keyboard-driven translator summoned by a global hotkey.
- Main use: English → Vietnamese, often on text selected in another app.

## Glossary

- **Panel**: the borderless, floating, non-activating `NSPanel` shown on hotkey. Created once, reused.
- **Pinned panel**: a panel that stays open, draggable and always on top, not dismissed by clicking outside.
- **Engine**: a `TranslationEngine` implementation (`GoogleCloudEngine`, `DeepLEngine`, `AppleEngine`).
- **Engine mode**: user setting `Auto` | `Google` | `DeepL` | `Apple`.
- **Language pair**: explicit source → target. No auto-detection.
- **Action panel**: the Cmd+K menu of actions on the current translation.
- **Language picker**: Cmd+P (target) / Cmd+Shift+P (source) fuzzy language search.
- **Previous app**: the frontmost app before the panel appeared; the target for paste-back.

## Decisions

| # | Topic | Decision |
|---|---|---|
| D1 | Audience & distribution (2026-10-18) | Personal use, open-source on GitHub. Releases built by GitHub Actions on `v*` tags; auto-update via Sparkle. Not the Mac App Store. |
| D2 | Google engine (2026-10-18) | Official Google Cloud Translation REST API with an API key. No unofficial endpoint. *Superseded by D30 (2026-10-18): v3 by default, v2 as a switch.* |
| D3 | Engine selection (2026-10-18) | Setting `Auto` / `Google` / `Apple`. Auto = Google, falling back to Apple Translation when offline, on error, or on timeout (~1.5 s). The result shows an engine badge. Settings can pre-download Apple language packs. *Extended by D31/D32 (2026-10-18): DeepL joins the chain.* |
| D4 | Launch model (2026-10-18) | Resident background agent (`LSUIElement`, no Dock icon), launch at login via `SMAppService`, panel pre-built; the hotkey only shows it. Target: visible in < 50 ms. |
| D5 | Window (2026-10-18) | Raycast-style `NSPanel`: floating, non-activating, centered on the cursor's screen (a dragged position is remembered since D37, 2026-10-30); click outside dismisses; Esc clears the input first, then dismisses (2026-10-18). Pin mode keeps it floating. |
| D6 | Layout (2026-10-18) | Side by side (source left, translation right) with a language bar on top. Stacked layout as a Settings option. |
| D7 | Shortcuts (2026-10-18) | Cmd+K action panel · Cmd+P target-language picker · Cmd+Shift+P source-language picker · Cmd+. pin · Cmd+D swap (was Cmd+S, 2026-10-18) · Enter copy & close · Cmd+Enter paste into the previous app. Copy and paste show a "Copied" HUD. |
| D8 | Initial input (2026-10-18) | Prefill with the front app's selected text (AX API; fallback: simulated Cmd+C with clipboard restore), else empty. Requires the Accessibility permission. |
| D9 | Languages (2026-10-18) | Explicit source & target, no auto-detect. Default English → Vietnamese. |
| D10 | Translate trigger (2026-10-18) | Translate as you type with a ~250 ms debounce; cancel in-flight requests. |
| D11 | Hotkey & dependencies (2026-10-18) | Default global hotkey Option+D (Carbon hotkey, no permission needed). Minimal third-party deps: `KeyboardShortcuts`, `Sparkle`. Otherwise Apple frameworks only. |
| D12 | Platform & stack (2026-10-18) | macOS 26+. AppKit owns the panel, focus and activation; SwiftUI renders the content (`NSHostingView`). Liquid Glass. Swift 6 strict concurrency. |
| D13 | v1 scope (2026-10-18) | Core loop (hotkey → panel → translate → copy/paste), Settings, Apple fallback, TTS (`AVSpeechSynthesizer`). Alternative translations dropped (not offered by the official API). Later: history, OCR, more engines. *DeepL pulled into v1 by D31 (2026-10-18). Dictionary entries pulled in by D35 (2026-10-18).* |
| D14 | Conventions (2026-10-18) | Follow `project-record` conventions: XcodeGen + Makefile, `AGENTS.md` (+ `CLAUDE.md` → `@AGENTS.md`), this decisions table, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, Chris Beams–style commits citing decision IDs, no AI attribution, Swift Testing. Not its project structure. |
| D15 | Identity (2026-10-18) | Bundle ID `com.betty.translator`. Repo `github.com/betty2310/translator`. |
| D16 | Signing (2026-10-18) | No Apple Developer account. Self-signed certificate stored as a CI secret (stable identity, so the Accessibility grant survives updates). Not notarized; release notes include the `xattr -dr com.apple.quarantine` step. |
| D17 | Sandbox (2026-10-18) | App Sandbox off (AX selection, simulated keystrokes, paste-back). Hardened Runtime on, with `com.apple.security.cs.disable-library-validation` (2026-10-18): a self-signed certificate has no Team ID, so library validation refused the embedded Sparkle.framework and v0.1.0 crashed at launch. |
| D18 | Google API details (2026-10-18) | API key typed in Settings and stored as plain config (D26, no Keychain). Without credentials, `Auto` behaves as `Apple` and `Google` is disabled with a "Set up" link. |
| D19 | Languages UX (2026-10-18) | Picker lists Google's languages; Apple-offline-capable ones are marked. Auto + offline + unsupported pair → clear error. Cmd+D swaps the pair and moves the translation into the input. Remember the last pair; 5 recent languages on top. |
| D20 | Project generation (2026-10-18) | XcodeGen `project.yml` committed, `.xcodeproj` git-ignored. |
| D21 | Appcast (2026-10-18) | `appcast.xml` attached to each GitHub Release; feed URL `releases/latest/download/appcast.xml`. |
| D22 | Menu bar (2026-10-18) | Menu bar icon shown by default (Open, Settings, Check for Updates, Quit), with a "Hide menu bar icon" toggle. Cmd+, in the panel always opens Settings. |
| D23 | Panel behavior (2026-10-18) | Hotkey toggles the panel. ~780×420, resizable, size remembered. Reopen keeps the last text, selected; fresh selected text overrides it. Paste-back: hide, activate the previous app, simulate Cmd+V; the translation stays on the clipboard (no restore since 2026-10-18, so Cmd+Enter also copies). |
| D24 | License (2026-10-18) | MIT. |
| D25 | CI (2026-10-18) | Same three workflows as `project-record` (`test.yml` on PRs, `build.yml` on `main`, `release.yml` on `v*` tags), on the `xcode-27` runner image (GitHub has no `macos-27` label; the Xcode 27 image runs macOS 27). |
| D26 | Config storage (2026-10-18) | All settings, including the Google API key, in `UserDefaults` (`@AppStorage`). Never in the repo. |
| D27 | Product name (2026-10-18) | "Translator" everywhere: menu bar, About, `Translator.app`, release titles ("Translator 0.1.0"). |
| D28 | Settings window (2026-10-18) | Three tabs. General: hotkey recorder, launch at login, menu bar icon, layout, Accessibility status + Grant. Engines: engine mode, Google API key + Test, Apple language packs. Updates/About: auto-check, Check now, version, GitHub link. |
| D29 | Milestones (2026-10-18) | M0 Bootstrap · M1 Panel · M2 Engines · M3 Keyboard UX · M4 System integration · M5 Settings & delivery (first release `v0.1.0`). Details in `docs/ROADMAP.md`. |
| D30 | Google API version (2026-10-18) | The owner wants **v3 (Advanced)** with the API key created in the Cloud console, so v3 is the default: `POST /v3/projects/{project}:translateText`, key in the `x-goog-api-key` header, Project ID typed in Settings. Google's docs still say only **Basic (v2)** accepts API keys, so Settings has an API version switch (v3 / v2, same key) and a Test button; if v3 rejects the key, switch to v2. Replaces D2. |
| D31 | DeepL engine (2026-10-18) | `DeepLEngine`: `POST {api,api-free}.deepl.com/v2/translate`, `Authorization: DeepL-Auth-Key`, JSON body. Free keys (suffix `:fx`) use the free host. Google codes are mapped to DeepL codes (`en` → `EN-US` target, `zh-CN` → `ZH-HANS`, …); unsupported languages fail before the network. Moved from "Later" into v1. |
| D32 | Auto chain (2026-10-18) | Engine mode is `Auto` / `Google` / `DeepL` / `Apple`. Auto tries Google, then DeepL (each only when it has a key), then Apple; a cloud engine is skipped after any error, when offline, or after the 1.5 s timeout. Explicit modes never fall back, so a missing key shows the "Set up" error (D18). |
| D33 | Dev flavor (2026-10-18) | Debug builds are **Translator Dev** (`com.betty.translator.dev`), a separate app that runs next to the installed one: own settings, API keys, Accessibility grant, login item, and hotkey (default Option+Shift+D). Marked by a "d" on the menu bar owl and a DEV tag (panel footer, Settings → Updates, window title). Sparkle only checks when asked. Release builds are unchanged (D15, D27). |
| D34 | Menu bar icon (2026-10-18) | A monochrome template image in the style of other menu bar icons, replacing the 🦉 emoji: a whole owl (egg-shaped body, small flared tufts, belly feathers) in big round glasses, so it reads as an owl rather than a cat. Sources in `design/menubar-icon*.svg`, compiled to vector PDFs in `Assets.xcassets`. |
| D35 | Dictionary entries (2026-10-18) | For a word or short phrase (≤ 4 words, ≤ 40 characters, one line), the result pane shows Dictionary.app entries under the engine's translation, which still runs. Sources: the dictionaries enabled in Dictionary.app, in its order, including the user's own in `~/Library/Dictionaries`. Bilingual dictionaries for the pair answer first (languages read from names like "Anh-Việt" / "French – English", else the bundle's primary language); if none has the term, monolingual ones in the source language. Per-dictionary lookup uses private Dictionary Services calls resolved with `dlsym` (allowed: not sandboxed, not the App Store, D1, D17), falling back to the public `DCSCopyTextDefinition`. Records are read as HTML and rendered natively, not in a web view (2026-10-18): headword + pronunciation, colored part-of-speech badges (Vietnamese abbreviations mapped to English: "dt." → noun), numbered senses, examples with their translation on a quote bar; specialized terms, encyclopedia notes and origins only after "Show More". Plain text when a record's HTML can't be read. A few ms per lookup (up to ~35 ms for huge entries), off the main actor, next to the engine, warmed at launch (D4). Toggle in Settings → Engines, on by default. |
| D36 | Click a word (2026-10-30) | When the input is longer than a term (a sentence or paragraph), clicking a word in the source text shows its Dictionary.app entries under the translation, with the same sources and rendering as D35; a double-click or drag on a word or short phrase looks up the selection. Only mouse clicks trigger it: typing and keyboard caret moves don't. The clicked word is highlighted in the source text (accent color, cleared when the text changes) and the result pane scrolls to the entries. "Open in Dictionary" opens the term shown. Uses the D35 toggle. |
| D37 | Panel position (2026-10-30) | Dragging the panel by its background moves it, and the position is remembered, like the size (D23). It's stored as the offset of the panel's top-center from the default spot (D5), so it follows the cursor's screen, survives resizing, and is clamped to the screen. While dragging, dashed guides mark the edges of the default spot: two vertical lines at its left and right edges and one horizontal line at its top edge (2026-10-30, replacing a single center line), so a drag left, right or up still shows where the panel lines up; guides are gray, and within 12 pt the panel snaps onto them and they turn blue (system blue, whatever the accent color), like Raycast; they go gray again once the panel moves off. The app moves the panel itself (not `isMovableByWindowBackground`), so macOS window tiling never resizes it on drop. "Reset" in Settings → General → Panel and "Reset Window Position" in Cmd+K (shown only when moved) go back to the default. |

## Open questions

None.
