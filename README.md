# Translator

A native macOS translator you summon with a hotkey, inspired by Raycast Translator.

- ⚡ Instant: lives in the background, Option+D shows a floating panel
- 🪟 Native Liquid Glass panel, side by side source and translation
- ⌨️ Keyboard first: ⌘K actions, ⌘P language picker, ↩ copy, ⌘↩ paste back
- 🌐 Google Cloud Translation or DeepL, with Apple's on-device translation offline
- ✂️ Opens with the text you selected in any app

## Requirements
- macOS 26+ on Apple Silicon, Xcode 27+
- `brew install xcodegen`
- Optional: a Google Cloud Translation API key (plus its project ID for v3) and/or a DeepL API key. Without keys, Apple's on-device translation is used (download language packs in Settings → Engines).

## Getting started
```bash
make run
```
This builds **Translator Dev**, a separate app from the installed Translator (own settings and Accessibility grant, a "d" on the menu bar owl). Press **Option+Shift+D** (Option+D in a release), and open **Settings** (⌘,) to add your Google / DeepL API keys, pick languages, and grant Accessibility (for selected text and paste-back).

In the panel: type to translate, **↩** copies, **⌘↩** pastes into the app you came from, **⌘K** actions, **⌘P** / **⌘⇧P** change languages, **⌘S** swaps, **⌘.** pins, **Esc** closes.

## Install a release
Download the latest zip from [Releases](https://github.com/betty2310/translator/releases), move `Translator.app` to `/Applications`, then run:
```bash
xattr -dr com.apple.quarantine /Applications/Translator.app
```
The app is self-signed, not notarized. Updates arrive in-app via Sparkle.

## Docs
- [AGENTS.md](AGENTS.md): contributor/agent guide
- [docs/DECISIONS.md](docs/DECISIONS.md): product & technical decisions
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how it fits together
- [docs/ROADMAP.md](docs/ROADMAP.md): what's done and what's next

## License
[MIT](LICENSE)
