import SwiftUI

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var settings = AppSettings.shared

    var body: some Scene {
        // D22: menu bar icon with Open, Settings, Check for Updates, Quit; hideable.
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            Button("Open Translator") { appDelegate.showPanel() }
            Button("Settings…") { appDelegate.showSettings() }
            Button("Check for Updates…") { appDelegate.updater.checkForUpdates() }
            Divider()
            Button("Quit Translator") { NSApp.terminate(nil) }
        } label: {
            Text("🦉")  // the app icon is the same owl (Assets.xcassets/AppIcon)
        }
    }
}
