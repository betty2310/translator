import SwiftUI

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var settings = AppSettings.shared

    var body: some Scene {
        // D22: menu bar icon with Open, Settings, Check for Updates, Quit; hideable.
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            Button("Open \(AppFlavor.name)") { appDelegate.showPanel() }
            Button("Settings…") { appDelegate.showSettings() }
            Button("Check for Updates…") { appDelegate.updater.checkForUpdates() }
            Divider()
            Button("Quit \(AppFlavor.name)") { NSApp.terminate(nil) }
        } label: {
            // D34: owl-in-glasses template image (design/menubar-icon*.svg); the dev flavor's has a "d" (D33).
            Image(AppFlavor.isDev ? "MenuBarIconDev" : "MenuBarIcon")
        }
    }
}
