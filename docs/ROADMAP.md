# Roadmap

Status: `[ ]` todo, `[~]` in progress / stubbed, `[x]` done. Update this file as you work.

## M0: Bootstrap
- [x] Design interview, decisions (`docs/DECISIONS.md`)
- [x] XcodeGen project, Makefile, app shell that builds and tests (D14, D20)
- [x] README, MIT license, `.gitignore`, `AGENTS.md`
- [x] CI: tests on PRs, build on `main` (D25)

## M1: Panel
- [x] Background agent: `LSUIElement`, no Dock icon, panel built once at launch (D4)
- [x] Global hotkey Option+D toggles the panel (`KeyboardShortcuts`, D11, D23)
- [x] Raycast-style `NSPanel`: floating, non-activating, centered on the cursor's screen, Liquid Glass (D5, D12)
- [x] Esc / click outside dismisses; previous app keeps focus
- [x] Side-by-side layout with language bar; size remembered (D6, D23)
- [x] Pin mode (Cmd+.): stays open, draggable, always on top (D5, D7)

## M2: Engines
- [x] `TranslationEngine` protocol + `EngineRouter` (D3)
- [x] `AppleEngine` (installed models, `TranslationSession`)
- [x] `GoogleCloudEngine` (v3 default, v2 switch; API key header; request/response parsing tested with canned JSON) (D30)
- [x] `DeepLEngine` (free/pro host, code mapping, parsing tested) (D31)
- [x] Auto mode: Google → DeepL → Apple on offline / error / 1.5 s timeout; no key → next engine (D32, D18)
- [x] Translate as you type: 250 ms debounce, cancel in-flight (D10)
- [x] Engine badge and error states (not configured, pack not downloaded, unsupported pair) (D3, D19)

## M3: Keyboard UX
- [x] Language catalog (Google list, Apple-offline marks) (D19)
- [x] Cmd+P target / Cmd+Shift+P source picker with fuzzy search and 5 recents (D7, D19)
- [x] Cmd+K action panel: copy, paste, swap, speak, pin, open in Google Translate, change engine (D7)
- [x] Enter copies & closes; Cmd+S swaps the pair (D7, D19)
- [x] Speak source / translation (`AVSpeechSynthesizer`) (D13)
- [x] Remember the last pair; default English → Vietnamese (D9, D19)

## M4: System integration
- [x] Accessibility permission check + prompt (D8)
- [x] Prefill with the selected text (AX, fallback simulated Cmd+C + clipboard restore) (D8, D23)
- [x] Cmd+Enter paste-back into the previous app + clipboard restore (D7, D23)

## M5: Settings & delivery
- [x] Settings window: General / Engines / Updates & About (D28)
- [x] Hotkey recorder, launch at login (`SMAppService`), layout option, menu bar toggle (D4, D6, D22)
- [x] Engines tab: mode, Google API key + version + project + Test, DeepL key + Test, Apple language pack download (D30, D31, D18)
- [x] Menu bar icon: Open, Settings, Check for Updates, Quit (D22)
- [x] Sparkle updates from `releases/latest/download/appcast.xml` (D21)
- [x] `release.yml`: self-signed certificate, zip, appcast, GitHub Release (D16, D25)
- [x] App icon
- [ ] First release `v0.1.0` (needs the GitHub repo + secrets `SPARKLE_PRIVATE_KEY`, `SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`)

## Later / out of scope for v1
- Translation history and favorites
- OCR (translate text in screenshots)
- More engines (LLMs, Google Translation LLM model)
- Alternative translations / dictionary
- Responsive layout switch (side by side ↔ stacked by width)
