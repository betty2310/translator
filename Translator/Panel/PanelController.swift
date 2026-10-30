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
        panel.onMouseDown = { [weak self] in self?.model.lastInputWasClick = true }
        panel.onDrag = { [weak self] frame in self?.drag(to: frame) ?? frame }
        panel.onDragEnd = { [weak self] in self?.endDrag() }
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

    /// The editor's text view, kept so a highlight can be cleared after focus moves to an overlay.
    private weak var highlightedTextView: NSTextView?

    /// Marks the clicked word whose entries are shown (D36). A rendering attribute, not part of the text, so
    /// typing, copying and pasting never carry it. Nil clears it.
    func highlightSource(_ range: NSRange?) {
        if range != nil, let textView = panel.firstResponder as? NSTextView { highlightedTextView = textView }
        guard let textView = highlightedTextView else { return }
        let color = NSColor.controlAccentColor.withAlphaComponent(0.3)
        if let layout = textView.textLayoutManager, let content = layout.textContentManager {
            layout.removeRenderingAttribute(.backgroundColor, for: layout.documentRange)
            guard let range,
                  let start = content.location(content.documentRange.location, offsetBy: range.location),
                  let end = content.location(start, offsetBy: range.length),
                  let textRange = NSTextRange(location: start, end: end) else { return }
            layout.addRenderingAttribute(.backgroundColor, value: color, for: textRange)
        } else if let layout = textView.layoutManager {
            let all = NSRange(location: 0, length: (textView.string as NSString).length)
            layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: all)
            if let range { layout.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range) }
        }
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

    /// On the cursor's screen: centered a bit above the middle (D5), or where it was dragged to (D37).
    private func place(on screen: NSScreen? = nil) {
        let size = CGSize(width: max(settings.panelSize.width, AppSettings.minimumPanelSize.width),
                          height: max(settings.panelSize.height, AppSettings.minimumPanelSize.height))
        guard let visible = (screen ?? Self.screen(containing: NSEvent.mouseLocation))?.visibleFrame else { return }
        panel.setFrame(PanelPlacement.frame(size: size, in: visible, offset: settings.panelOffset), display: true)
    }

    /// Back to the default spot (D37); moves the panel now if it's open.
    func resetPosition() {
        settings.panelOffset = nil
        if panel.isVisible { place(on: panel.screen) }
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: Dragging (D37)

    private let guides = SnapGuides()

    /// Shows the guides on the screen under the panel's top edge and snaps the panel onto the ones it's near.
    private func drag(to proposed: NSRect) -> NSRect {
        guard let screen = Self.screen(containing: NSPoint(x: proposed.midX, y: proposed.maxY)) else { return proposed }
        let frame = PanelPlacement.snapped(proposed, in: screen.visibleFrame)
        guides.show(on: screen, alignment: PanelPlacement.alignment(of: frame, in: screen.visibleFrame), below: panel)
        return frame
    }

    private func endDrag() {
        guides.hide()
        guard let visible = panel.screen?.visibleFrame else { return }
        settings.panelOffset = PanelPlacement.offset(of: panel.frame, in: visible)
    }

    // MARK: NSWindowDelegate

    func windowDidEndLiveResize(_ notification: Notification) {
        settings.panelSize = panel.frame.size
        // Resizing from the left or top edge moves the anchor; keep a dragged position in step.
        if settings.panelOffset != nil, let visible = panel.screen?.visibleFrame {
            settings.panelOffset = PanelPlacement.offset(of: panel.frame, in: visible)
        }
        panel.invalidateShadow()
    }
}
