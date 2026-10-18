import AppKit
import SwiftUI

/// Raycast-style confirmation ("Copied to Clipboard") shown briefly near the bottom of the screen after the panel
/// hides. Click-through and never key, so the previous app keeps focus.
@MainActor
final class HUDWindow {
    private let panel: NSPanel
    private let hosting = NSHostingView(rootView: HUDView(message: ""))
    private var generation = 0

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
    }

    func show(_ message: String, on screen: NSScreen?) {
        hosting.rootView = HUDView(message: message)
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = hosting.fittingSize
        panel.setFrame(NSRect(x: (visible.midX - size.width / 2).rounded(), y: visible.minY + 80,
                              width: size.width, height: size.height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.invalidateShadow()

        generation += 1
        let shown = generation
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, generation == shown else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    if self.generation == shown { self.panel.orderOut(nil) }
                }
            }
        }
    }
}

private struct HUDView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .fixedSize()
    }
}
