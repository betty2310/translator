import SwiftUI

/// Card for the Cmd+K and Cmd+P overlays (Raycast-style dropdown).
struct OverlayCard<Content: View>: View {
    let footer: String
    var size = CGSize(width: 340, height: 360)
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            Text(footer)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
        .frame(width: size.width, height: size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
    }
}

struct OverlaySearchField: View {
    let prompt: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($focused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear { focused = true }
    }
}

struct OverlayRowBackground: View {
    let selected: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(selected ? Color.accentColor.opacity(0.18) : .clear)
    }
}

/// Cmd+P / Cmd+Shift+P language picker with fuzzy search and recents (D7, D19).
struct LanguagePicker: View {
    @Bindable var model: PanelModel
    let role: PanelModel.LanguageRole

    var body: some View {
        OverlayCard(footer: "↑↓ Navigate   ↩ Select   esc Close", size: CGSize(width: 290, height: 320)) {
            OverlaySearchField(prompt: role == .source ? "Translate from…" : "Translate to…", text: $model.overlayQuery)
            Divider()
            let rows = model.pickerRows
            let current = role == .source ? model.source : model.target
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            if index == 0 && row.isRecent {
                                SectionHeader("Recent")
                            } else if !row.isRecent && (index == 0 || rows[index - 1].isRecent) && model.overlayQuery.isEmpty {
                                SectionHeader("All Languages")
                            }
                            LanguageRow(language: row.language,
                                        selected: index == model.overlayIndex,
                                        isCurrent: row.language == current,
                                        onDevice: model.appleSupportedCodes.contains(row.language.code))
                                .id(row.id)
                                .contentShape(Rectangle())
                                .onTapGesture { model.activateOverlayItem(at: index) }
                        }
                        if rows.isEmpty {
                            Text("No languages match").foregroundStyle(.secondary).padding(12)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: model.overlayIndex) {
                    if rows.indices.contains(model.overlayIndex) {
                        proxy.scrollTo(rows[model.overlayIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

struct LanguageRow: View {
    let language: Language
    let selected: Bool
    let isCurrent: Bool
    let onDevice: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(language.name).font(.system(size: 13))
            Text(language.code).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            if onDevice {
                Image(systemName: "apple.logo")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .help("Available offline with Apple Translation")
            }
            if isCurrent {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(OverlayRowBackground(selected: selected))
    }
}

/// Cmd+K action panel (D7).
struct ActionPanel: View {
    @Bindable var model: PanelModel

    var body: some View {
        OverlayCard(footer: "↑↓ Navigate   ↩ Run   esc Close") {
            OverlaySearchField(prompt: "Search actions…", text: $model.overlayQuery)
            Divider()
            let actions = model.filteredActions
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                            HStack(spacing: 10) {
                                Image(systemName: action.icon)
                                    .frame(width: 16)
                                    .foregroundStyle(.secondary)
                                Text(action.title).font(.system(size: 13))
                                Spacer()
                                if let shortcut = action.shortcut {
                                    HStack(spacing: 2) {
                                        ForEach(Array(shortcut.map(String.init).enumerated()), id: \.offset) { Keycap($0.element) }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(OverlayRowBackground(selected: index == model.overlayIndex))
                            .id(action.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.activateOverlayItem(at: index) }
                        }
                        if actions.isEmpty {
                            Text("No actions match").foregroundStyle(.secondary).padding(12)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: model.overlayIndex) {
                    if actions.indices.contains(model.overlayIndex) {
                        proxy.scrollTo(actions[model.overlayIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
}
