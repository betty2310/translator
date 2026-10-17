import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// D11: Option+D by default; changeable in Settings → General.
    static let togglePanel = Self("togglePanel", initial: .init(.d, modifiers: [.option]))
}

/// Startup (D4): builds the panel once, registers the hotkey, starts the updater. Owns the Settings window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate?

    let settings = AppSettings.shared
    private(set) var updater = AppUpdater(start: false)
    private(set) var panelController: PanelController?
    private var settingsWindow: SettingsWindowController?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app (TEST_HOST): no hotkey, no updater, no panel.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        updater = AppUpdater()
        let controller = PanelController(settings: settings)
        panelController = controller
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak controller] in
            controller?.toggle()
        }
        // Ask for Accessibility once (D8); afterwards Settings → General has the Grant button.
        let promptedKey = "didPromptAccessibility"
        if !SelectionReader.isTrusted, !UserDefaults.standard.bool(forKey: promptedKey) {
            UserDefaults.standard.set(true, forKey: promptedKey)
            SelectionReader.requestTrust()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    func showPanel() {
        panelController?.show()
    }

    func showSettings() {
        panelController?.hide()
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, updater: updater)
        }
        settingsWindow?.show()
    }
}
