# AGENTS.md

Guide for AI agents (and humans) working on **Translator**. Read this first, then `docs/DECISIONS.md`.

## What this is
A personal, open-source native macOS translator inspired by Raycast Translator. The app:
1. runs in the background (no Dock icon) and starts at login,
2. shows a floating Liquid Glass panel on a global hotkey (default **Option+D**),
3. prefills it with the text selected in the front app,
4. translates as you type, side by side, with an explicit language pair (default English → Vietnamese),
5. uses **Google Cloud Translation** (v3, v2 switch) or **DeepL**, and falls back to **Apple's Translation framework** offline,
6. copies the result (Enter) or pastes it back into the previous app (Cmd+Enter).

## Must-read docs
- `docs/DECISIONS.md`: settled product/tech decisions (D1–D32). **Don't re-open these without asking the owner.**
- `docs/ARCHITECTURE.md`: layout, panel lifecycle, engines, storage.
- `docs/ROADMAP.md`: milestones and status. **Update checkboxes when you finish work.**

## Commands
```bash
make gen     # regenerate Translator.xcodeproj from project.yml (XcodeGen)
make build   # generate + build
make test    # generate + run unit tests (Swift Testing)
make run     # build + open the app
make release VERSION=1.2.0  # Release build → build/Translator-1.2.0.zip (self-signed certificate, D16; SIGN_ID=- for ad-hoc)
make install # Release build → /Applications, launch
```
- `Translator.xcodeproj` is **generated and git-ignored**. Change `project.yml`, never the `.xcodeproj`. Adding a Swift file under `Translator/` needs no project change; just run `make gen`.
- CI (`.github/workflows/`): PRs run tests, `main` builds, a `v*` tag publishes a GitHub Release with the Sparkle `appcast.xml` (D1, D21, D25). Release: `git tag v1.2.0 && git push origin v1.2.0`. Secrets: `SPARKLE_PRIVATE_KEY`, `SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`. Set versions in `project.yml`, not `Info.plist`.
- Requirements: macOS 26+, Xcode 27+, `brew install xcodegen`.

## Conventions
- Swift 6 (strict concurrency), SwiftUI for content, AppKit for the panel, focus and activation (D12). `@Observable`. Swift Testing (`import Testing`) for tests.
- **UI text in English.**
- Engines are pluggable: implement `TranslationEngine` and route through `EngineRouter`. Views must not know about specific engines.
- Put logic in `Services/` or `Engines/` as pure, testable functions (request building, response parsing, fallback decisions, fuzzy matching). Keep views thin.
- Launch speed is a feature (D4): build the panel once at startup, never do network or disk work on the hotkey path, never block the main actor.
- Settings, including the Google API key, live in `UserDefaults` via `AppSettings` (D26). **Never commit API keys.** Tests use fake keys and canned JSON.
- Not sandboxed (D17): the app reads the selection via Accessibility and posts keystrokes. Hardened Runtime is on.
- Before changing the Google, DeepL or Apple engine, **read the current API docs**; links are in the engine files.
- Keep it simple. The owner rejects over-engineering; v1 scope is D13.

## Gotchas
- Accessibility (TCC) grants are tied to the code signature. Debug builds are ad-hoc signed and may need re-granting after rebuilds; release builds use the self-signed certificate and keep the grant (D16).
- Apple Translation only works offline for installed language models. `TranslationSession(installedSource:target:)` never downloads; downloads need the SwiftUI `.translationTask` + `prepareTranslation()` path (Settings → Engines).
- A non-activating `NSPanel` must override `canBecomeKey` to receive typing, and must not activate the app, or the previous app loses focus and paste-back targets the wrong app. Keys are routed in `TranslatorPanel.sendEvent` → `PanelModel.handleKey` before SwiftUI sees them.
- The simulated Cmd+C fallback must run before the panel becomes key, or the keystroke lands in the panel.
- `TranslationSession` isn't `Sendable`: create one per call (engine) or box it (Settings download).
- Option+D is captured globally, so "∂" can't be typed while the app runs.

## Commits
Follow [How to Write a Git Commit Message](https://chris.beams.io/git-commit):
1. Separate the subject from the body with a blank line.
2. Limit the subject line to 50 characters.
3. Capitalize the subject line.
4. Don't end the subject line with a period.
5. Use the imperative mood in the subject (`Add Apple engine`, not `Added …`/`Adds …`). It should complete "If applied, this commit will …".
6. Wrap the body at 72 characters.
7. Use the body to explain *what* and *why*, not *how* (the diff shows how). Cite decision IDs, e.g. "(D3)".

Keep one logical change per commit; split unrelated work instead of listing it all in one subject.

Don't add AI attribution: no `Co-Authored-By: Claude …` trailer and no "Generated with Claude Code" line in commits or PRs.

## Definition of done
`make test` passes, new logic has tests, `docs/ROADMAP.md` is updated, and decisions that change are recorded in `docs/DECISIONS.md` with a date.
