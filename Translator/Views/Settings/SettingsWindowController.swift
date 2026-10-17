import AppKit
import SwiftUI

/// The Settings window (D28): System Settings-style toolbar tabs (`NSTabViewController`, `.toolbar`), each tab a
/// SwiftUI view. Our own window rather than the SwiftUI `Settings` scene so AppKit code (menu bar, Cmd+, in
/// the panel) can open it directly.
@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings, updater: AppUpdater) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", height: 560, view: GeneralSettingsView(settings: settings)))
        tabs.addTabViewItem(Self.tab("Engines", symbol: "globe", height: 560, view: EnginesSettingsView(settings: settings)))
        tabs.addTabViewItem(Self.tab("Updates", symbol: "arrow.down.circle", height: 280, view: UpdatesSettingsView(updater: updater)))
        let window = NSWindow(contentViewController: tabs)
        window.title = "Translator Settings"
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    /// Each tab gets a fixed size so the window animates to it when switching tabs. The tab view controller sizes
    /// the window from `preferredContentSize`; without it the window stays 500×500 and clips the form's margins.
    private static func tab(_ title: String, symbol: String, height: CGFloat, view: some View) -> NSTabViewItem {
        let size = NSSize(width: 540, height: height)
        let host = NSHostingController(rootView: view.frame(width: size.width, height: size.height))
        host.sizingOptions = []
        host.preferredContentSize = size
        host.title = title
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    func show() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
