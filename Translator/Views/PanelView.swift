import SwiftUI

/// Panel content (D6), styled after Raycast Translator: a dimmed source card next to the translation on the bare
/// glass, the language selector in each pane's header, a round swap button notched into the card's edge, and a
/// footer bar.
struct PanelView: View {
    @Bindable var model: PanelModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                panes
                    .padding(10)
                Divider()
                FooterBar(model: model)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.04))
            }
            overlays
        }
        .animation(.easeOut(duration: 0.12), value: model.overlay)
    }

    @ViewBuilder
    private var panes: some View {
        switch model.settings.layout {
        case .sideBySide:
            // Equal halves put the swap button on the source card's trailing edge, in its notch.
            ZStack {
                HStack(spacing: 0) {
                    SourcePane(model: model, notch: .trailing)
                    TranslationPane(model: model)
                }
                SwapButton(model: model)
            }
        case .stacked:
            ZStack {
                VStack(spacing: 0) {
                    SourcePane(model: model, notch: .bottom)
                    TranslationPane(model: model)
                }
                SwapButton(model: model)
            }
        }
    }

    /// Pickers drop down under their selector; the action panel sits bottom-right (D7).
    @ViewBuilder
    private var overlays: some View {
        switch model.overlay {
        case .none:
            EmptyView()
        case .actions:
            ActionPanel(model: model)
                .padding(10)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)))
        case .picker(let role):
            let stacked = model.settings.layout == .stacked
            LanguagePicker(model: model, role: role)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: role == .source || stacked ? .topLeading : .topTrailing)
                .padding(.top, 48)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }
}

// MARK: - Panes

/// Dims the glass behind the source pane; the translation sits on the bare glass. Black darkens in both
/// appearances, where `.primary` would lighten in dark mode.
struct DimFill: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05)
    }
}

/// The source card: a rounded rectangle with a round notch cut out of one edge for the swap button.
struct NotchedCard: Shape {
    enum Edge { case trailing, bottom }

    let edge: Edge
    var cornerRadius: CGFloat = 14
    var notchRadius: CGFloat = SwapButton.size / 2 + 5

    func path(in rect: CGRect) -> Path {
        let card = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let center = edge == .trailing ? CGPoint(x: rect.maxX, y: rect.midY) : CGPoint(x: rect.midX, y: rect.maxY)
        let notch = CGPath(ellipseIn: CGRect(x: center.x - notchRadius, y: center.y - notchRadius,
                                             width: notchRadius * 2, height: notchRadius * 2), transform: nil)
        return Path(card.subtracting(notch))
    }
}

struct SourcePane: View {
    @Bindable var model: PanelModel
    let notch: NotchedCard.Edge

    var body: some View {
        VStack(spacing: 0) {
            LanguageSelector(icon: "textformat", language: model.source, hint: "⌘⇧P") {
                model.overlay = model.overlay == .picker(.source) ? .none : .picker(.source)
            }
            SourceEditor(model: model)
            HStack(spacing: 14) {
                PaneIconButton(systemImage: "speaker.wave.2", help: "Speak source") { model.speakSource() }
                    .disabled(model.sourceText.isEmpty)
                Spacer()
                Text(TextStats.describe(model.sourceText))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(DimFill().clipShape(NotchedCard(edge: notch)))
    }
}

struct TranslationPane: View {
    @Bindable var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            LanguageSelector(icon: "flag", language: model.target, hint: "⌘P") {
                model.overlay = model.overlay == .picker(.target) ? .none : .picker(.target)
            }
            ResultPane(model: model)
            HStack(spacing: 14) {
                PaneIconButton(systemImage: "speaker.wave.2", help: "Speak translation") { model.speakTranslation() }
                    .disabled(model.translation.isEmpty)
                Spacer()
                if case .done(let engine) = model.status {
                    EngineBadge(engine: engine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

/// "English ⌄" at the top of a pane: plain text, no button chrome.
struct LanguageSelector: View {
    let icon: String
    let language: Language
    let hint: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(language.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Change language (\(hint))")
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

/// A borderless dimmed circle sitting in the source card's notch, with a Raycast-style hint above it on hover.
struct SwapButton: View {
    nonisolated static let size: CGFloat = 36

    @Bindable var model: PanelModel
    @State private var hovering = false
    @State private var showsHint = false

    var body: some View {
        Button { model.swap() } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? .primary : .secondary)
                .frame(width: Self.size, height: Self.size)
                .background(DimFill().clipShape(Circle()))
                .background(Color.primary.opacity(hovering ? 0.06 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showsHint {
                HStack(spacing: 8) {
                    Text("Swap languages").font(.system(size: 12))
                    HStack(spacing: 3) { Keycap("⌘"); Keycap("D") }
                }
                .padding(.leading, 10)
                .padding(.trailing, 5)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .fixedSize()
                .offset(y: -40)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .onHover { hovering = $0 }
        .task(id: hovering) {
            guard hovering else { showsHint = false; return }
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { showsHint = true }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.12), value: showsHint)
    }
}

struct PaneIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct SourceEditor: View {
    @Bindable var model: PanelModel
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if model.sourceText.isEmpty {
                Text("Type or paste text to translate…")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $model.sourceText, selection: $selection)
                .font(.system(size: 17))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .focused($focused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { focused = true }
        .onChange(of: model.focusToken) { focused = true }
        .onChange(of: model.selectAllToken) {
            let text = model.sourceText
            Task { @MainActor in
                selection = TextSelection(range: text.startIndex..<text.endIndex)
                focused = true
            }
        }
    }
}

struct ResultPane: View {
    @Bindable var model: PanelModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !model.translation.isEmpty {
                    Text(model.translation)
                        .font(.system(size: 17))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    if model.needsSetup {
                        Button("Set up in Settings…") { model.openSettings() }
                            .controlSize(.small)
                    }
                } else {
                    Text(model.status == .translating ? "Translating…" : "Translation")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                }
                if let message = model.errorMessage, !model.translation.isEmpty {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "26 words • 142 characters". Pure, tested.
enum TextStats {
    static func describe(_ text: String) -> String {
        let characters = text.count
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        guard characters > 0 else { return "" }
        return "\(words) \(words == 1 ? "word" : "words") • \(characters) \(characters == 1 ? "character" : "characters")"
    }
}

// MARK: - Footer

struct FooterBar: View {
    @Bindable var model: PanelModel

    var body: some View {
        HStack(spacing: 10) {
            // From the asset catalog, not `NSApp.applicationIconImage`: Launch Services caches that per bundle.
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 22, height: 22)
            Text("Translator")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if AppFlavor.isDev { DevTag() }
            statusView
            Spacer()
            if model.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .help("Pinned (⌘.)")
            }
            EngineMenu(model: model)
            Divider().frame(height: 16)
            FooterAction(title: "Copy Translation", keys: ["↩"]) { model.copyAndClose() }
                .disabled(model.translation.isEmpty)
            Divider().frame(height: 16)
            FooterAction(title: "Actions", keys: ["⌘", "K"], primary: false) { model.overlay = .actions }
        }
        .font(.system(size: 13))
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .translating:
            ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }
}

/// Engine mode as a plain "Auto ⌄" menu (D3, D32).
struct EngineMenu: View {
    @Bindable var model: PanelModel

    var body: some View {
        Menu {
            ForEach(EngineMode.allCases) { mode in
                Button {
                    model.setEngineMode(mode)
                } label: {
                    if mode == model.settings.engineMode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Text(mode.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(model.settings.engineMode.displayName)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Translation engine")
    }
}

/// Marks the dev flavor (D33) so it's never mistaken for the installed app.
struct DevTag: View {
    var body: some View {
        Text("DEV")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.orange, in: .capsule)
            .help("Development build")
    }
}

/// Which engine produced the result (D3).
struct EngineBadge: View {
    let engine: EngineID

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: engine == .apple ? "apple.logo" : "cloud")
            Text(engine.displayName)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .help("Translated by \(engine.displayName)")
    }
}

/// The primary action reads in full strength, the others in secondary, as in Raycast.
struct FooterAction: View {
    let title: String
    let keys: [String]
    var primary = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: primary ? .semibold : .medium))
                    .foregroundStyle(primary ? .primary : .secondary)
                HStack(spacing: 3) {
                    ForEach(keys, id: \.self) { Keycap($0) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Keycap: View {
    let symbol: String

    init(_ symbol: String) { self.symbol = symbol }

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }
}
