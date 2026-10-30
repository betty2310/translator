import CoreGraphics

/// Where the panel sits on a screen (D5, D37). Its anchor is the midpoint of its top edge: by default centered
/// horizontally, 16% of the screen's height below the top. A dragged position is stored as the anchor's offset
/// from that default, so it follows the cursor's screen and survives resizing.
enum PanelPlacement {
    /// How close (in points) a dragged panel must be to a guide to snap onto it.
    static let snapDistance: CGFloat = 12

    struct Alignment: Equatable {
        var centered: Bool
        var atDefaultHeight: Bool
    }

    static func defaultAnchor(in visible: CGRect) -> CGPoint {
        CGPoint(x: visible.midX, y: visible.maxY - visible.height * 0.16)
    }

    /// The panel's frame on a screen, kept inside its visible frame (top edge first when it doesn't fit).
    static func frame(size: CGSize, in visible: CGRect, offset: CGPoint?) -> CGRect {
        let anchor = defaultAnchor(in: visible)
        let offset = offset ?? .zero
        let x = min(max(anchor.x + offset.x - size.width / 2, visible.minX), visible.maxX - size.width)
        let y = min(max(anchor.y + offset.y - size.height, visible.minY), visible.maxY - size.height)
        return CGRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }

    /// Which guides a dragged frame is on, within `snapDistance`.
    static func alignment(of frame: CGRect, in visible: CGRect) -> Alignment {
        let anchor = defaultAnchor(in: visible)
        return Alignment(centered: abs(frame.midX - anchor.x) <= snapDistance,
                         atDefaultHeight: abs(frame.maxY - anchor.y) <= snapDistance)
    }

    /// Moves a dropped frame exactly onto the guides it is close to.
    static func snapped(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let anchor = defaultAnchor(in: visible)
        let alignment = alignment(of: frame, in: visible)
        var result = frame
        if alignment.centered { result.origin.x = (anchor.x - frame.width / 2).rounded() }
        if alignment.atDefaultHeight { result.origin.y = (anchor.y - frame.height).rounded() }
        return result
    }

    /// The offset to remember for a frame; nil when it sits at the default spot (within rounding).
    static func offset(of frame: CGRect, in visible: CGRect) -> CGPoint? {
        let anchor = defaultAnchor(in: visible)
        let dx = frame.midX - anchor.x, dy = frame.maxY - anchor.y
        guard abs(dx) >= 1 || abs(dy) >= 1 else { return nil }
        return CGPoint(x: dx.rounded(), y: dy.rounded())
    }
}
