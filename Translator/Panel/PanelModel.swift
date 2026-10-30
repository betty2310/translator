import AppKit
import Observation
import Translation

/// State and commands of the panel. Views stay thin: they render this and call its methods; keyboard
/// routing (`handleKey`) is centralized here so the overlays and the editor never compete for keys.
@MainActor
@Observable
final class PanelModel {
    enum LanguageRole: Equatable { case source, target }
    enum Overlay: Equatable { case none, actions, picker(LanguageRole) }
    enum Status: Equatable { case idle, translating, done(EngineID), failed(TranslationError) }

    struct Action: Identifiable {
        let id: String
        let title: String
        let shortcut: String?
        let icon: String
        let run: @MainActor () -> Void
    }

    struct PickerRow: Identifiable {
        let language: Language
        let isRecent: Bool
        var id: String { (isRecent ? "recent-" : "all-") + language.code }
    }

    static let debounce: Duration = .milliseconds(250)

    let settings: AppSettings
    @ObservationIgnored weak var controller: PanelController?
    @ObservationIgnored private let appleEngine = AppleEngine()
    @ObservationIgnored private let speech = SpeechService()
    @ObservationIgnored private let dictionary = DictionaryService()
    @ObservationIgnored private var translationTask: Task<Void, Never>?
    @ObservationIgnored private var dictionaryTask: Task<Void, Never>?

    var sourceText = "" {
        didSet {
            guard sourceText != oldValue else { return }
            lastInputWasClick = false  // the caret move that follows comes from the edit
            controller?.highlightSource(nil)  // its range no longer matches the text
            scheduleTranslation()
        }
    }
    private(set) var translation = ""
    /// The trimmed input `translation` belongs to, with the current pair; nil while translating or after a failure.
    @ObservationIgnored private var translatedText: String?
    /// Dictionary.app entries for a word or short phrase, shown under the translation (D35), or for the word
    /// clicked in longer text (D36).
    private(set) var dictionaryEntries: [DictionaryEntry] = []
    /// What `dictionaryEntries` were looked up for.
    @ObservationIgnored private var dictionaryTerm: String?
    /// Bumped when a clicked word's entries land, so the result pane scrolls to them.
    private(set) var revealDictionaryToken = 0
    /// Set by a mouse-down in the panel, cleared by a key-down: a caret move then came from a click (D36).
    @ObservationIgnored var lastInputWasClick = false
    private(set) var status: Status = .idle
    var overlay: Overlay = .none {
        didSet {
            overlayQuery = ""
            overlayIndex = 0
            if overlay == .none, oldValue != .none { focusToken += 1 }
        }
    }
    var overlayQuery = "" {
        didSet { overlayIndex = 0 }
    }
    var overlayIndex = 0
    var isPinned = false
    var previousAppName: String?
    /// Bumped to ask the editor to select everything / take focus (D23).
    private(set) var selectAllToken = 0
    private(set) var focusToken = 0
    /// Google codes Apple can translate on-device, for the picker marks (D19).
    private(set) var appleSupportedCodes: Set<String> = []

    init(settings: AppSettings) {
        self.settings = settings
        Task.detached(priority: .utility) { [weak self] in
            let supported = await LanguageAvailability().supportedLanguages
            let codes = AppleEngine.supportedCodes(in: LanguageCatalog.all, supported: supported)
            await MainActor.run { self?.appleSupportedCodes = codes }
        }
        Task { [dictionary] in await dictionary.warmUp() }
    }

    var source: Language { settings.source }
    var target: Language { settings.target }

    var errorMessage: String? {
        if case .failed(let error) = status { return error.errorDescription }
        return nil
    }

    var needsSetup: Bool {
        if case .failed(.notConfigured) = status { return true }
        return false
    }

    // MARK: Show / hide

    /// Reopen keeps the last text, selected; a fresh selection replaces it (D23).
    func prepareForShow(selection: String?) {
        overlay = .none
        if let selection, !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, selection != sourceText {
            sourceText = selection
        }
        lastInputWasClick = false  // the select-all that follows isn't a click
        selectAllToken += 1
        focusToken += 1
    }

    // MARK: Translation (D10)

    private func scheduleTranslation() {
        translationTask?.cancel()
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translation = ""
            dictionaryTask?.cancel()
            dictionaryEntries = []
            status = .idle
            return
        }
        translationTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.translateNow()
        }
    }

    func retranslate() {
        translationTask?.cancel()
        translatedText = nil
        translationTask = Task { [weak self] in await self?.translateNow() }
    }

    private func translateNow() async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translation = ""
            dictionaryTask?.cancel()
            dictionaryEntries = []
            status = .idle
            return
        }
        status = .translating
        translatedText = nil
        lookUpInDictionary(text)
        let router = EngineRouter(engines: [
            .google: settings.makeGoogleEngine(),
            .deepL: settings.makeDeepLEngine(),
            .apple: appleEngine,
        ])
        let configuration = settings.routerConfiguration
        do {
            let result = try await router.translate(text, from: source, to: target, configuration: configuration)
            guard !Task.isCancelled else { return }
            translation = result.text
            translatedText = text
            status = .done(result.engine)
        } catch {
            guard !Task.isCancelled else { return }
            let failure = TranslationError.from(error, engine: .google)
            if failure == .cancelled { return }
            status = .failed(failure)
        }
    }

    /// Runs next to the engine; a lookup takes a few ms, so the entry usually shows first (D35). A clicked word
    /// (`highlight`, D36) is highlighted and scrolled to once it has entries.
    private func lookUpInDictionary(_ text: String, highlight: NSRange? = nil) {
        dictionaryTask?.cancel()
        controller?.highlightSource(nil)
        dictionaryTerm = DictionaryLookup.term(for: text)
        guard settings.dictionaryLookup, let term = dictionaryTerm else {
            dictionaryEntries = []
            return
        }
        let (source, target) = (self.source, self.target)
        dictionaryTask = Task { [weak self, dictionary] in
            let entries = await dictionary.lookUp(term, from: source, to: target)
            guard !Task.isCancelled, let self else { return }
            dictionaryEntries = entries
            if let highlight, !entries.isEmpty {
                controller?.highlightSource(highlight)
                revealDictionaryToken += 1
            }
        }
    }

    /// A click in the source text looks up the word under it, or the word or short phrase it selected (D36).
    /// Typing and keyboard moves don't. A click on another occurrence of the term shown only moves the highlight.
    func sourceSelectionChanged(to selection: Range<String.Index>) {
        guard lastInputWasClick, settings.dictionaryLookup,
              let word = DictionaryLookup.word(in: sourceText, selection: selection) else { return }
        let range = NSRange(word.range, in: sourceText)
        guard word.term != dictionaryTerm else {
            if !dictionaryEntries.isEmpty { controller?.highlightSource(range) }
            return
        }
        lookUpInDictionary(word.term, highlight: range)
    }

    // MARK: Commands (D7)

    func copyAndClose() {
        guard !translation.isEmpty else { return }
        PasteService.copy(translation)
        controller?.showHUD("Copied to Clipboard")
        controller?.hide()
    }

    /// Pastes and leaves the translation on the clipboard, so it's there even if the paste lands nowhere.
    func pasteBack() {
        guard !translation.isEmpty else { return }
        controller?.showHUD("Pasted and Copied")
        controller?.pasteBack(translation)
    }

    func copySource() {
        guard !sourceText.isEmpty else { return }
        PasteService.copy(sourceText)
        controller?.showHUD("Copied to Clipboard")
        controller?.hide()
    }

    /// Cmd+D: swap the pair and move the translation into the input (D19).
    func swap() {
        let newSource = target
        let newTarget = source
        // Only move a translation of the current input; a failed, pending or in-flight one is stale.
        let isCurrent = translatedText == sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.sourceCode = newSource.code
        settings.targetCode = newTarget.code
        if isCurrent, !translation.isEmpty { sourceText = translation }
        // Always translate: setting the same text (e.g. a name the engine left as is) doesn't trigger didSet.
        retranslate()
        lastInputWasClick = false  // the select-all that follows isn't a click
        selectAllToken += 1
    }

    func select(_ language: Language, for role: LanguageRole) {
        overlay = .none
        switch role {
        case .source:
            if language.code == settings.targetCode { settings.targetCode = settings.sourceCode }
            settings.sourceCode = language.code
            settings.recentSourceCodes = Recents.push(language.code, into: settings.recentSourceCodes)
        case .target:
            if language.code == settings.sourceCode { settings.sourceCode = settings.targetCode }
            settings.targetCode = language.code
            settings.recentTargetCodes = Recents.push(language.code, into: settings.recentTargetCodes)
        }
        retranslate()
    }

    func setEngineMode(_ mode: EngineMode) {
        overlay = .none
        settings.engineMode = mode
        retranslate()
    }

    func togglePin() {
        isPinned.toggle()
    }

    func speakSource() {
        speech.speak(sourceText, languageCode: source.code)
    }

    func speakTranslation() {
        speech.speak(translation, languageCode: target.code)
    }

    func openInGoogleTranslate() {
        var components = URLComponents(string: "https://translate.google.com/")!
        components.queryItems = [
            .init(name: "sl", value: source.code), .init(name: "tl", value: target.code),
            .init(name: "text", value: sourceText), .init(name: "op", value: "translate"),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
        controller?.hide()
    }

    /// Opens the term in Dictionary.app.
    func openInDictionary() {
        guard let term = dictionaryTerm,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "dict://\(encoded)") else { return }
        NSWorkspace.shared.open(url)
        controller?.hide()
    }

    func clearText() {
        overlay = .none
        sourceText = ""
        focusToken += 1
    }

    func openSettings() {
        overlay = .none
        controller?.openSettings()
    }

    /// Esc clears the input first, then closes the panel.
    func escape() {
        if sourceText.isEmpty { dismiss() } else { clearText() }
    }

    func dismiss() {
        speech.stop()
        controller?.hide()
    }

    // MARK: Overlays

    var actions: [Action] {
        var list: [Action] = [
            Action(id: "copy", title: "Copy Translation", shortcut: "↩", icon: "doc.on.doc") { [weak self] in self?.copyAndClose() },
            Action(id: "paste", title: "Paste to \(previousAppName ?? "Previous App")", shortcut: "⌘↩", icon: "arrow.turn.down.left") { [weak self] in self?.pasteBack() },
            Action(id: "copySource", title: "Copy Source Text", shortcut: nil, icon: "doc.on.doc") { [weak self] in self?.copySource() },
            Action(id: "swap", title: "Swap Languages", shortcut: "⌘D", icon: "arrow.left.arrow.right") { [weak self] in self?.overlay = .none; self?.swap() },
            Action(id: "target", title: "Change Target Language", shortcut: "⌘P", icon: "globe") { [weak self] in self?.overlay = .picker(.target) },
            Action(id: "source", title: "Change Source Language", shortcut: "⌘⇧P", icon: "globe") { [weak self] in self?.overlay = .picker(.source) },
            Action(id: "speakTranslation", title: "Speak Translation", shortcut: nil, icon: "speaker.wave.2") { [weak self] in self?.overlay = .none; self?.speakTranslation() },
            Action(id: "speakSource", title: "Speak Source", shortcut: nil, icon: "speaker.wave.1") { [weak self] in self?.overlay = .none; self?.speakSource() },
            Action(id: "pin", title: isPinned ? "Unpin Window" : "Pin Window", shortcut: "⌘.", icon: isPinned ? "pin.slash" : "pin") { [weak self] in self?.overlay = .none; self?.togglePin() },
            Action(id: "web", title: "Open in Google Translate", shortcut: nil, icon: "safari") { [weak self] in self?.openInGoogleTranslate() },
        ]
        if !dictionaryEntries.isEmpty {
            list.append(Action(id: "dictionary", title: "Open in Dictionary", shortcut: nil, icon: "book") { [weak self] in self?.openInDictionary() })
        }
        for mode in EngineMode.allCases {
            let current = mode == settings.engineMode
            list.append(Action(id: "engine-\(mode.rawValue)", title: "Engine: \(mode.displayName)" + (current ? " (current)" : ""),
                               shortcut: nil, icon: current ? "checkmark.circle" : "circle") { [weak self] in self?.setEngineMode(mode) })
        }
        if settings.panelOffset != nil {
            list.append(Action(id: "resetPosition", title: "Reset Window Position", shortcut: nil, icon: "arrow.up.and.down.and.arrow.left.and.right") { [weak self] in
                self?.overlay = .none
                self?.controller?.resetPosition()
            })
        }
        list.append(Action(id: "clear", title: "Clear Text", shortcut: nil, icon: "xmark.circle") { [weak self] in self?.clearText() })
        list.append(Action(id: "settings", title: "Settings…", shortcut: "⌘,", icon: "gearshape") { [weak self] in self?.openSettings() })
        return list
    }

    var filteredActions: [Action] {
        FuzzyMatcher.filter(actions, query: overlayQuery, key: \.title)
    }

    var pickerRole: LanguageRole? {
        if case .picker(let role) = overlay { return role }
        return nil
    }

    var pickerRows: [PickerRow] {
        guard let role = pickerRole else { return [] }
        let recents = (role == .source ? settings.recentSourceCodes : settings.recentTargetCodes)
            .compactMap(LanguageCatalog.language(for:))
        if overlayQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return recents.map { PickerRow(language: $0, isRecent: true) }
                + LanguageCatalog.all.map { PickerRow(language: $0, isRecent: false) }
        }
        return FuzzyMatcher.filter(LanguageCatalog.all, query: overlayQuery) { "\($0.name) \($0.code)" }
            .map { PickerRow(language: $0, isRecent: false) }
    }

    var overlayItemCount: Int {
        switch overlay {
        case .none: 0
        case .actions: filteredActions.count
        case .picker: pickerRows.count
        }
    }

    func activateOverlayItem(at index: Int) {
        switch overlay {
        case .none: return
        case .actions:
            guard filteredActions.indices.contains(index) else { return }
            filteredActions[index].run()
        case .picker(let role):
            guard pickerRows.indices.contains(index) else { return }
            select(pickerRows[index].language, for: role)
        }
    }

    // MARK: Keyboard (D7)

    private enum KeyCode {
        static let `return`: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    /// Routes a key-down from the panel. Returns true when consumed.
    func handleKey(_ event: NSEvent) -> Bool {
        lastInputWasClick = false
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let plain = flags.subtracting(.shift).isEmpty
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let isEnter = event.keyCode == KeyCode.return || event.keyCode == KeyCode.keypadEnter
        let isEscape = event.keyCode == KeyCode.escape

        if overlay == .none {
            if isEscape { escape(); return true }
            if isEnter && plain && !shift { copyAndClose(); return true }
            if isEnter && command { pasteBack(); return true }
            guard command else { return false }
            switch key {
            case "k" where !shift: overlay = .actions
            case "p": overlay = .picker(shift ? .source : .target)
            case ".": togglePin()
            case "d" where !shift: swap()
            case ",": openSettings()
            default: return false
            }
            return true
        }

        if isEscape { overlay = .none; return true }
        if event.keyCode == KeyCode.down { overlayIndex = min(overlayIndex + 1, max(overlayItemCount - 1, 0)); return true }
        if event.keyCode == KeyCode.up { overlayIndex = max(overlayIndex - 1, 0); return true }
        if isEnter { activateOverlayItem(at: overlayIndex); return true }
        guard command else { return false }
        switch key {
        case "k" where !shift: overlay = overlay == .actions ? .none : .actions
        case "p":
            let role: LanguageRole = shift ? .source : .target
            overlay = overlay == .picker(role) ? .none : .picker(role)
        case ",": openSettings()
        default: return false
        }
        return true
    }
}
