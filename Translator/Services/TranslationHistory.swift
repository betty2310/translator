import Foundation

/// One translation the user made (D39).
struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var date: Date
    var sourceText: String
    var translation: String
    var sourceCode: String
    var targetCode: String
    var engine: EngineID
}

/// History rules (D39). Pure, tested.
enum TranslationHistory {
    /// Entries older than this are dropped.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    static func pruned(_ entries: [HistoryEntry], now: Date) -> [HistoryEntry] {
        entries.filter { now.timeIntervalSince($0.date) < retention }
    }

    /// `entry` on top, newest first. Translate as you type (D10) records every pause, so `entry` replaces
    /// `previous` (the entry recorded just before in the same panel session) when one text extends or shortens
    /// the other with the same pair: "hel", "hello", "hello world" leave one entry. An older entry with the same
    /// text and pair moves to the top instead of repeating.
    static func recording(_ entry: HistoryEntry, after previous: HistoryEntry?, in entries: [HistoryEntry], now: Date) -> [HistoryEntry] {
        let replaced = previous.flatMap { previous in
            let samePair = previous.sourceCode == entry.sourceCode && previous.targetCode == entry.targetCode
            let continues = entry.sourceText.hasPrefix(previous.sourceText) || previous.sourceText.hasPrefix(entry.sourceText)
            return samePair && continues ? previous.id : nil
        }
        let rest = entries.filter {
            $0.id != replaced && $0.id != entry.id
                && !($0.sourceText == entry.sourceText && $0.sourceCode == entry.sourceCode && $0.targetCode == entry.targetCode)
        }
        return pruned([entry] + rest, now: now)
    }

    /// One line of at most 200 characters for a list row; the full text shows when the entry is opened.
    static func preview(_ text: String) -> String {
        String(text.prefix(200)).split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    /// Entries whose source or translation contains `query` (case- and diacritic-insensitive), newest first.
    static func filter(_ entries: [HistoryEntry], query: String) -> [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.sourceText.localizedStandardContains(trimmed) || $0.translation.localizedStandardContains(trimmed) }
    }
}

/// Reads and writes the history as JSON in Application Support, off the main actor (D4, D39). Each flavor
/// has its own folder (D33).
actor HistoryStore {
    let url: URL

    init(url: URL) { self.url = url }

    static let standard = HistoryStore(url: URL.applicationSupportDirectory
        .appending(path: Bundle.main.bundleIdentifier ?? "com.betty.translator")
        .appending(path: "History.json"))

    /// Empty when the file is missing or unreadable.
    func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    func save(_ entries: [HistoryEntry]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: url, options: .atomic)
        } catch {
            NSLog("Translator: couldn't save history: \(error)")
        }
    }
}
