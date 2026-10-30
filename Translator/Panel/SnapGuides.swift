import AppKit

/// Dashed guides shown while the panel is dragged (D37): the edges of the panel's default spot, so a drag left,
/// right or up still shows where it lines up. Two vertical lines at its left and right edges and one horizontal line
/// at its top edge. Lines are gray, and blue while the panel is snapped onto them. Click-through and never key.
@MainActor
final class SnapGuides {
    private let window: NSPanel
    private let left = CAShapeLayer()
    private let right = CAShapeLayer()
    private let top = CAShapeLayer()

    init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        for line in [left, right, top] {
            line.fillColor = nil
            line.lineDashPattern = [6, 4]
            line.shadowColor = NSColor.black.cgColor
            line.shadowOpacity = 0.35
            line.shadowRadius = 1
            line.shadowOffset = .zero
            view.layer?.addSublayer(line)
        }
        window.contentView = view
    }

    func show(on screen: NSScreen, alignment: PanelPlacement.Alignment, below panel: NSWindow) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if window.frame != screen.frame { window.setFrame(screen.frame, display: false) }
        // The default frame for the panel's current size, in the guide window's coordinates.
        let visible = screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        let spot = PanelPlacement.frame(size: panel.frame.size, in: visible, offset: nil)
        left.path = Self.line(from: CGPoint(x: spot.minX, y: visible.minY), to: CGPoint(x: spot.minX, y: visible.maxY))
        right.path = Self.line(from: CGPoint(x: spot.maxX, y: visible.minY), to: CGPoint(x: spot.maxX, y: visible.maxY))
        top.path = Self.line(from: CGPoint(x: visible.minX, y: spot.maxY), to: CGPoint(x: visible.maxX, y: spot.maxY))
        // The panel keeps its width while dragged, so its left edge is on the left line exactly when its right edge
        // is on the right one.
        style(left, active: alignment.centered)
        style(right, active: alignment.centered)
        style(top, active: alignment.atDefaultHeight)
        CATransaction.commit()
        if !window.isVisible { window.order(.below, relativeTo: panel.windowNumber) }
    }

    func hide() {
        window.orderOut(nil)
    }

    private static func line(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func style(_ line: CAShapeLayer, active: Bool) {
        // Mid gray reads on light and dark backgrounds alike; blue marks the guide the panel is on.
        line.strokeColor = (active ? NSColor.systemBlue : NSColor(white: 0.5, alpha: 0.9)).cgColor
        line.lineWidth = active ? 2 : 1.5
    }
}
