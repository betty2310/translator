import KeyboardShortcuts
import SwiftUI
import Translation

// Three tabs (D28): General, Engines, Updates & About. `SettingsWindowController` hosts them as toolbar tabs.

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var accessibilityGranted = SelectionReader.isTrusted

    var body: some View {
        Form {
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Show Translator", name: .togglePanel)
                Text("Press the hotkey anywhere to toggle the panel. It opens with the text selected in the front app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LoginItem.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                if !settings.showMenuBarIcon {
                    Text("Without the icon, open Settings with ⌘, inside the panel.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Panel") {
                Picker("Layout", selection: $settings.layout) {
                    ForEach(PanelLayout.allCases) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Size") {
                    HStack {
                        Text("\(Int(settings.panelSize.width)) × \(Int(settings.panelSize.height))")
                            .foregroundStyle(.secondary)
                        Button("Reset") { settings.panelSize = AppSettings.defaultPanelSize }
                            .disabled(settings.panelSize == AppSettings.defaultPanelSize)
                    }
                }
                Text("Drag the panel's edges to resize it; the size is remembered.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Accessibility") {
                LabeledContent("Permission") {
                    HStack {
                        Label(accessibilityGranted ? "Granted" : "Not granted",
                              systemImage: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(accessibilityGranted ? .green : .secondary)
                        if accessibilityGranted {
                            Button("Open System Settings") { SelectionReader.openSystemSettings() }
                        } else {
                            Button("Grant…") {
                                SelectionReader.requestTrust()
                                SelectionReader.openSystemSettings()
                            }
                        }
                    }
                }
                Text("Needed to read the selected text and to paste the translation back (⌘↩). Debug builds may need re-granting after a rebuild.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                accessibilityGranted = SelectionReader.isTrusted
                launchAtLogin = LoginItem.isEnabled
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct EnginesSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Engine") {
                Picker("Mode", selection: $settings.engineMode) {
                    ForEach(EngineMode.allCases) { Text($0.displayName).tag($0) }
                }
                Text("Auto tries Google, then DeepL (each only when it has a key), and falls back to Apple's on-device translation when offline, on an error, or after 1.5 s.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Google Cloud Translation") {
                SecureField("API key", text: $settings.googleAPIKey)
                Picker("API", selection: $settings.googleAPIVersion) {
                    ForEach(GoogleCloudEngine.APIVersion.allCases) { Text($0.displayName).tag($0) }
                }
                if settings.googleAPIVersion == .v3 {
                    TextField("Project ID", text: $settings.googleProjectID, prompt: Text("my-project-123"))
                    Text("v3 needs the Google Cloud project the key belongs to. Google documents API keys for v2 only; if the test fails with 401/403, switch to v2 (same key).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                EngineTestRow(engine: settings.makeGoogleEngine(), isConfigured: settings.isGoogleConfigured)
            }
            Section("DeepL") {
                SecureField("API key", text: $settings.deepLAPIKey)
                Text("Free keys end in “:fx” and use api-free.deepl.com; Pro keys use api.deepl.com.")
                    .font(.caption).foregroundStyle(.secondary)
                EngineTestRow(engine: settings.makeDeepLEngine(), isConfigured: settings.isDeepLConfigured)
            }
            Section("Apple Translation (offline)") {
                AppleLanguagePackView(source: settings.source, target: settings.target)
                Text("Language packs download through macOS. Only installed pairs translate offline.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// "Test" translates a sample sentence with the engine as configured right now.
struct EngineTestRow: View {
    let engine: any TranslationEngine
    let isConfigured: Bool
    @State private var running = false
    @State private var result: Result<String, TranslationError>?

    var body: some View {
        LabeledContent("Connection") {
            HStack {
                Button(running ? "Testing…" : "Test") { test() }
                    .disabled(running || !isConfigured)
                switch result {
                case .success(let text):
                    Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green).lineLimit(1)
                case .failure(let error):
                    Label(error.errorDescription ?? "Failed", systemImage: "xmark.circle")
                        .foregroundStyle(.red).lineLimit(2)
                case nil:
                    if !isConfigured { Text("Add a key first").foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func test() {
        running = true
        result = nil
        let engine = engine
        Task {
            do {
                let text = try await engine.translate("Hello, how are you?", from: LanguageCatalog.english, to: LanguageCatalog.vietnamese)
                result = .success(text)
            } catch {
                result = .failure(TranslationError.from(error, engine: engine.id))
            }
            running = false
        }
    }
}

/// Status of Apple's language pack for a pair, with a Download button (the only path that downloads:
/// `.translationTask` + `prepareTranslation()`).
struct AppleLanguagePackView: View {
    let source: Language
    let target: Language
    @State private var status: LanguageAvailability.Status?
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        LabeledContent("\(source.name) → \(target.name)") {
            HStack {
                switch status {
                case .installed: Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .supported:
                    Text("Not downloaded").foregroundStyle(.secondary)
                    Button("Download…") {
                        configuration = TranslationSession.Configuration(source: AppleEngine.language(for: source.code),
                                                                         target: AppleEngine.language(for: target.code))
                    }
                case .unsupported: Label("Unsupported pair", systemImage: "xmark.circle").foregroundStyle(.secondary)
                case nil: ProgressView().controlSize(.small)
                @unknown default: Text("Unknown").foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(source.code)>\(target.code)") { await refresh() }
        .translationTask(configuration) { session in
            // The session isn't Sendable but SwiftUI hands it to this main-actor closure; the box lets the
            // (sequential, one-shot) download call leave the main actor.
            let box = SessionBox(session: session)
            try? await box.session.prepareTranslation()
            await refresh()
        }
    }

    private func refresh() async {
        status = await LanguageAvailability().status(from: AppleEngine.language(for: source.code),
                                                     to: AppleEngine.language(for: target.code))
    }
}

private struct SessionBox: @unchecked Sendable {
    let session: TranslationSession
}

struct UpdatesSettingsView: View {
    @Bindable var updater: AppUpdater

    var body: some View {
        Form {
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                LabeledContent("Version \(AppUpdater.currentVersion)") {
                    Button("Check Now") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                }
            }
            Section("About") {
                Text("Translator is a personal, open-source macOS translator inspired by Raycast Translator.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("github.com/betty2310/translator", destination: URL(string: "https://github.com/betty2310/translator")!)
                Text("MIT License").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
