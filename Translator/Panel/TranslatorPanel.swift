import AppKit

/// The floating, non-activating panel (D5, D12). Built once and reused; AppKit owns key handling so the
/// SwiftUI content never has to fight the text editor for Enter, Esc and Cmd shortcuts.
final class TranslatorPanel: NSPanel {
    /// Return true to swallow the key event (routed by `PanelModel.handleKey`).
    var keyHandler: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?
    var onMouseDown: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        minSize = AppSettings.minimumPanelSize
        isExcludedFromWindowsMenu = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        if event.type == .leftMouseDown { onMouseDown?() }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
