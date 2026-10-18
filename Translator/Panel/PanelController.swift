import AppKit
import SwiftUI

/// Shows/hides the pre-built panel, remembers the previous app, reads the selection, places and resizes the
/// window (D4, D5, D8, D23).
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let panel: TranslatorPanel
    let model: PanelModel
    private let settings: AppSettings
    private(set) var previousApp: NSRunningApplication?
    private static let cornerRadius: CGFloat = 20
    private var pendingShow = false
    private let hud = HUDWindow()
    private var outsideClickMonitor: Any?

    init(settings: AppSettings) {
        self.settings = settings
        model = PanelModel(settings: settings)
        let size = settings.panelSize
        panel = TranslatorPanel(contentRect: NSRect(origin: .zero, size: size))
        super.init()

        // The window shadow follows the content's alpha. Clip everything to the glass shape so the shadow is
        // rounded too; otherwise it traces the rectangular frame as a dark outline around the corners.
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        let glass = NSGlassEffectView(frame: container.bounds)
        glass.cornerRadius = Self.cornerRadius
        glass.style = .regular
        glass.autoresizingMask = [.width, .height]
        let hosting = NSHostingView(rootView: PanelView(model: model))
        hosting.sizingOptions = []
        hosting.frame = glass.bounds
        hosting.autoresizingMask = [.width, .height]
        glass.contentView = hosting
        container.addSubview(glass)
        panel.contentView = container
        panel.delegate = self
        panel.keyHandler = { [weak self] event in self?.model.handleKey(event) ?? false }
        panel.onResignKey = { [weak self] in self?.panelDidResignKey() }
        model.controller = self
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible && panel.isKeyWindow { hide() } else { show() }
    }

    /// Hotkey path (D4): no disk or network work here. The AX read is synchronous and fast; the Cmd+C
    /// fallback (D8) runs before the panel takes key focus, bounded to ~120 ms.
    func show() {
        guard !pendingShow else { return }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
        model.previousAppName = previousApp?.localizedName
        switch SelectionReader.focusedSelection() {
        case .selection(let text):
            present(selection: text)
        case .unavailable:
            pendingShow = true
            Task {
                let text = await SelectionReader.selectionViaCopy()
                pendingShow = false
                present(selection: text)
            }
        }
    }

    private func present(selection: String?) {
        model.prepareForShow(selection: selection)
        if !panel.isVisible { place() }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        watchOutsideClicks()
    }

    func hide() {
        stopWatchingOutsideClicks()
        guard panel.isVisible else { return }
        model.overlay = .none
        panel.orderOut(nil)
    }

    func showHUD(_ message: String) {
        hud.show(message, on: panel.screen)
    }

    /// Hide, hand focus back, paste (D23).
    func pasteBack(_ text: String) {
        let target = previousApp
        hide()
        Task { await PasteService.paste(text, into: target) }
    }

    func openSettings() {
        AppDelegate.shared?.showSettings()
    }

    private func panelDidResignKey() {
        guard panel.isVisible, !model.isPinned else { return }
        hide()
    }

    /// The panel never activates the app, so a click in another app doesn't always take key focus from it
    /// (e.g. on the desktop or the already active app). A global monitor sees only clicks outside our windows.
    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelDidResignKey() }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    /// Centered horizontally on the cursor's screen, a bit above the middle (D5).
    private func place() {
        let size = CGSize(width: max(settings.panelSize.width, AppSettings.minimumPanelSize.width),
                          height: max(settings.panelSize.height, AppSettings.minimumPanelSize.height))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - size.width / 2
        let y = visible.maxY - visible.height * 0.16 - size.height
        panel.setFrame(NSRect(x: x.rounded(), y: max(y, visible.minY).rounded(), width: size.width, height: size.height),
                       display: true)
    }

    // MARK: NSWindowDelegate

    func windowDidEndLiveResize(_ notification: Notification) {
        settings.panelSize = panel.frame.size
        panel.invalidateShadow()
    }
}
