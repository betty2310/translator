import SwiftUI

/// Dictionary.app entries under the translation, one per dictionary (D35).
struct DictionarySection: View {
    let entries: [DictionaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.bottom, 14)
                    DictionaryEntryView(entry: entry)
                }
            }
        }
        .padding(.top, 6)
        .textSelection(.enabled)
    }
}

/// Headword and pronunciation, then the sections; collapsed to a preview until "Show More".
struct DictionaryEntryView: View {
    static let previewRows = 9

    let entry: DictionaryEntry
    @State private var expanded = false

    var body: some View {
        let preview = entry.preview(rows: Self.previewRows)
        let shown = expanded ? entry : preview
        VStack(alignment: .leading, spacing: 12) {
            header
            ForEach(Array(shown.sections.enumerated()), id: \.offset) { _, section in
                DictionarySectionView(section: section)
            }
            if preview != entry {
                ExpandButton(expanded: $expanded)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.headword)
                .font(.system(size: 16, weight: .semibold))
            if !entry.pronunciations.isEmpty {
                Text(entry.pronunciations.prefix(2).joined(separator: "  "))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Label(entry.dictionaryName, systemImage: "book.closed")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .help(entry.dictionary)
        }
    }
}

struct DictionarySectionView: View {
    let section: DictionaryEntry.Section

    var body: some View {
        let markers = Self.markers(for: section.senses, numbered: section.hasHiddenSenses)
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(Array(section.senses.enumerated()), id: \.offset) { index, sense in
                SenseRow(sense: sense, marker: markers[index])
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let title = section.title {
            switch section.kind {
            case .main:
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    PartOfSpeechBadge(label: title)
                    note
                }
            case .phrase:
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    note
                }
            case .extra:
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var note: some View {
        if let note = section.note {
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// "1", "2", … for senses, "•" for sub-senses; no marker for a lone sense unless `numbered`.
    nonisolated static func markers(for senses: [DictionaryEntry.Sense], numbered: Bool = false) -> [String?] {
        guard numbered || senses.filter({ !$0.isSubsense }).count > 1 || senses.contains(where: \.isSubsense) else {
            return senses.map { _ in nil }
        }
        var number = 0
        return senses.map { sense in
            if sense.isSubsense { return "•" }
            number += 1
            return "\(number)"
        }
    }
}

struct SenseRow: View {
    let sense: DictionaryEntry.Sense
    let marker: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let marker {
                Text(marker)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                if !sense.text.isEmpty || !sense.labels.isEmpty {
                    definition
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, example in
                    ExampleRow(example: example)
                }
            }
        }
    }

    /// Labels in italics, then the definition, in one wrapping text.
    private var definition: Text {
        let labels = sense.labels.map { Text($0 + " ").italic().foregroundStyle(.secondary) }
        return labels.reduce(Text(verbatim: "")) { $0 + $1 } + Text(sense.text)
    }
}

/// An example on a thin quote bar, its translation in the accent color underneath.
struct ExampleRow: View {
    let example: DictionaryEntry.Example

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Capsule()
                .fill(Color.primary.opacity(0.14))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(example.text)
                    .italic()
                    .foregroundStyle(.secondary)
                if let translation = example.translation {
                    Text(translation)
                        .foregroundStyle(.tint)
                }
            }
            .font(.system(size: 12.5))
            .lineSpacing(1)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// "noun", "verb", … in a tinted capsule, one hue per word class.
struct PartOfSpeechBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        let label = label.lowercased()
        if label.contains("adverb") { return .purple }
        if label.contains("verb") { return .green }
        if label.contains("pronoun") { return .teal }
        if label.contains("noun") { return .blue }
        if label.hasPrefix("adj") { return .orange }
        if label.contains("preposition") || label.contains("conjunction") { return .pink }
        if label.contains("interjection") || label.contains("exclamation") { return .indigo }
        return .gray
    }
}

struct ExpandButton: View {
    @Binding var expanded: Bool
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(expanded ? "Show Less" : "Show More")
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(hovering ? 0.09 : 0.05), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
