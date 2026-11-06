import SwiftUI

/// The history list that replaces the translator panes (D39): a search field and the last 30 days of
/// translations, newest first. A `List` is backed by a table view that only builds the rows on screen and
/// reuses them while scrolling, so thousands of entries stay cheap. Keys go through `PanelModel.handleKey`.
struct HistoryView: View {
    @Bindable var model: PanelModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { model.screen = .translator } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)  // with keyboard navigation on it would take focus from the search field
                .help("Back to Translator (esc)")
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search history…", text: $model.historyQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                Text(countLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Divider()
            if model.filteredHistory.isEmpty {
                Text(model.history.isEmpty ? "No translations in the last 30 days" : "No translations match")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        // Deferred: it appears in the same update that removes the Cmd+K search field, which still holds focus.
        .onAppear { Task { @MainActor in searchFocused = true } }
        .onChange(of: model.focusToken) { Task { @MainActor in searchFocused = true } }
    }

    private var countLabel: String {
        let total = model.history.count
        let shown = model.filteredHistory.count
        let noun = total == 1 ? "translation" : "translations"
        return model.historyQuery.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(total) \(noun) · last 30 days" : "\(shown) of \(total) \(noun)"
    }

    private var list: some View {
        let selectedID = model.selectedHistoryEntry?.id
        return ScrollViewReader { proxy in
            List {
                ForEach(model.filteredHistory) { entry in
                    HistoryRow(entry: entry, selected: entry.id == selectedID)
                        .id(entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.selectHistoryEntry(entry.id)
                            model.openHistoryEntry()
                        }
                        .onTapGesture { model.selectHistoryEntry(entry.id) }
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: model.historyIndex) {
                if let id = model.selectedHistoryEntry?.id { proxy.scrollTo(id) }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(TranslationHistory.preview(entry.sourceText))
                    .font(.system(size: 14))
                Text(TranslationHistory.preview(entry.translation))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.sourceCode.uppercased()) → \(entry.targetCode.uppercased())")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(entry.date, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(OverlayRowBackground(selected: selected))
    }
}
