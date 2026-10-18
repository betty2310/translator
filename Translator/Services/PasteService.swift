import AppKit

/// Clipboard actions: copy the result (Enter) and paste it back into the previous app (Cmd+Enter). Both leave
/// the translation on the clipboard (D7, D23).
@MainActor
enum PasteService {
    static func copy(_ text: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies `text`, activates `app` and pastes with a simulated Cmd+V. The caller hides the panel first so the
    /// previous app's text field is key again.
    static func paste(_ text: String, into app: NSRunningApplication?) async {
        copy(text)
        if let app, !app.isActive {
            app.activate()
            // Give the window server time to switch key focus before typing.
            try? await Task.sleep(for: .milliseconds(150))
        }
        KeySimulator.post(.v, flags: .maskCommand)
    }
}

/// A copy of a pasteboard's items, restorable later.
struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func take(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { copy[type] = data }
            }
            return copy
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
