import AppKit
import ApplicationServices

/// Reads the text selected in the front app (D8). Needs the Accessibility permission (D17).
@MainActor
enum SelectionReader {
    enum AXResult: Equatable {
        /// The focused element answered: its selection (possibly empty, meaning "nothing selected").
        case selection(String)
        /// The element doesn't expose a selection (Electron, Chrome, Java…): try the Cmd+C fallback.
        case unavailable
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts the system Accessibility dialog (once) and returns the current state.
    @discardableResult
    static func requestTrust() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary  // kAXTrustedCheckOptionPrompt
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Synchronous AX read of the focused element's selected text: fast enough for the hotkey path (D4).
    static func focusedSelection() -> AXResult {
        guard isTrusted else { return .unavailable }
        var focused: CFTypeRef?
        let system = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return .unavailable }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard status == .success else { return .unavailable }
        return .selection((value as? String) ?? "")
    }

    /// Fallback: simulate Cmd+C in the front app and read the clipboard, then restore it. Must run before the
    /// panel takes keyboard focus. Returns nil when nothing was copied within `budget`.
    static func selectionViaCopy(budget: Duration = .milliseconds(120)) async -> String? {
        guard isTrusted else { return nil }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.take(from: pasteboard)
        let before = pasteboard.changeCount
        KeySimulator.post(.c, flags: .maskCommand)
        let deadline = ContinuousClock.now + budget
        while pasteboard.changeCount == before, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(15))
        }
        guard pasteboard.changeCount != before else { return nil }
        let text = pasteboard.string(forType: .string)
        snapshot.restore(to: pasteboard)
        return text?.isEmpty == false ? text : nil
    }
}

/// Posts key events to the front app via the HID event tap (needs Accessibility).
enum KeySimulator {
    enum Key: CGKeyCode {
        case c = 8
        case v = 9
    }

    static func post(_ key: Key, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
