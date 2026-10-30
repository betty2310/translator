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
        isMovableByWindowBackground = false  // moved in `sendEvent` (D37)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        minSize = AppSettings.minimumPanelSize
        isExcludedFromWindowsMenu = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Called with the proposed frame while the background is dragged; returns the frame to use (snapping, D37).
    var onDrag: ((NSRect) -> NSRect)?
    var onDragEnd: (() -> Void)?
    private var dragStart: (mouse: NSPoint, frame: NSRect)?
    private var didDrag = false

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if keyHandler?(event) == true { return }
        case .leftMouseDown:
            onMouseDown?()
            // The app moves the panel itself instead of `isMovableByWindowBackground`: a window-server drag lets
            // macOS tile the panel to half the screen on drop, and the app can't follow it to draw the guides (D37).
            if contentView?.superview?.hitTest(event.locationInWindow)?.mouseDownCanMoveWindow == true {
                dragStart = (NSEvent.mouseLocation, frame)
                didDrag = false
            }
            super.sendEvent(event)
            // An edge resize runs its own loop until the button comes up; don't treat it as a move.
            if NSEvent.pressedMouseButtons & 1 == 0 || inLiveResize { dragStart = nil }
            return
        case .leftMouseDragged:
            if let dragStart {
                let mouse = NSEvent.mouseLocation
                let proposed = dragStart.frame.offsetBy(dx: mouse.x - dragStart.mouse.x, dy: mouse.y - dragStart.mouse.y)
                setFrame(onDrag?(proposed) ?? proposed, display: true)
                didDrag = true
                return
            }
        case .leftMouseUp:
            if dragStart != nil {
                dragStart = nil
                if didDrag { onDragEnd?() }
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
