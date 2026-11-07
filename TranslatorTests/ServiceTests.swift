import AppKit
import Foundation
import Testing
@testable import Translator

struct FuzzyMatcherTests {
    @Test func prefixBeatsSubsequence() {
        let vi = FuzzyMatcher.score("vi", in: "Vietnamese")!
        let sub = FuzzyMatcher.score("vi", in: "Slovenian")!
        #expect(vi > sub)
    }

    @Test func requiresAllCharactersInOrder() {
        #expect(FuzzyMatcher.score("xyz", in: "Vietnamese") == nil)
        #expect(FuzzyMatcher.score("tv", in: "Vietnamese") == nil)
        #expect(FuzzyMatcher.score("", in: "anything") == 0)
    }

    @Test func ignoresCaseAndDiacritics() {
        #expect(FuzzyMatcher.score("TIENG", in: "tiếng việt") != nil)
    }

    @Test func filterRanksBestFirstAndKeepsOrderForTies() {
        let languages = ["Vietnamese", "Slovenian", "Latvian", "Swahili", "Bosnian"]
        let result = FuzzyMatcher.filter(languages, query: "vi") { $0 }
        #expect(result.first == "Vietnamese")
        #expect(!result.contains("Swahili"))
        #expect(FuzzyMatcher.filter(languages, query: "   ") { $0 } == languages)
    }

    @Test func wordStartsScoreHigher() {
        let wordStart = FuzzyMatcher.score("tr", in: "Chinese (Traditional)")!
        let middle = FuzzyMatcher.score("tr", in: "Australian")!
        #expect(wordStart > middle)
    }
}

struct LanguageCatalogTests {
    @Test func looksUpLanguagesByCode() {
        #expect(LanguageCatalog.language(for: "vi") == LanguageCatalog.vietnamese)
        #expect(LanguageCatalog.language(for: "zh-CN")?.name == "Chinese (Simplified)")
        #expect(LanguageCatalog.language(for: "nope") == nil)
        #expect(LanguageCatalog.languageOrPlaceholder(for: "nope") == Language(code: "nope", name: "nope"))
    }

    @Test func catalogIsSortedAndUnique() {
        let names = LanguageCatalog.all.map(\.name)
        #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        #expect(Set(LanguageCatalog.all.map(\.code)).count == LanguageCatalog.all.count)
    }

    @Test func recentsMoveToFrontAndCapAtFive() {
        #expect(Recents.push("vi", into: []) == ["vi"])
        #expect(Recents.push("vi", into: ["en", "vi", "fr"]) == ["vi", "en", "fr"])
        #expect(Recents.push("f", into: ["a", "b", "c", "d", "e"]) == ["f", "a", "b", "c", "d"])
    }
}

struct DictionaryLookupTests {
    @Test func acceptsWordsAndShortPhrases() {
        #expect(DictionaryLookup.term(for: "hello") == "hello")
        #expect(DictionaryLookup.term(for: "  take off\n") == "take off")
        #expect(DictionaryLookup.term(for: "học sinh") == "học sinh")
        #expect(DictionaryLookup.term(for: "“running,”") == "running")
        #expect(DictionaryLookup.term(for: "don't") == "don't")
    }

    @Test func rejectsSentencesAndBlankText() {
        #expect(DictionaryLookup.term(for: "") == nil)
        #expect(DictionaryLookup.term(for: " ... ") == nil)
        #expect(DictionaryLookup.term(for: "this is a whole sentence") == nil)
        #expect(DictionaryLookup.term(for: "two\nlines") == nil)
        #expect(DictionaryLookup.term(for: String(repeating: "a", count: 41)) == nil)
    }

    @Test func clickPicksTheWordUnderTheCaretOrTheSelection() {
        let text = "I ran home, then “slept”. Don't wake"
        func at(_ offset: Int, length: Int = 0) -> String? {
            let start = text.index(text.startIndex, offsetBy: offset)
            return DictionaryLookup.word(in: text, selection: start..<text.index(start, offsetBy: length))?.term
        }
        #expect(at(3) == "ran")  // inside
        #expect(at(5) == "ran")  // right after the word
        #expect(at(6) == "home")  // start of the next word beats the end of the previous one
        #expect(at(0) == "I")
        #expect(at(11) == nil)  // between ", " and "then"
        #expect(at(19) == "slept")  // quotes dropped
        #expect(at(26) == "Don't")
        #expect(at(text.count) == "wake")  // end of text: the last word
        #expect(at(2, length: 9) == "ran home")  // a dragged phrase
        let caret = text.index(text.startIndex, offsetBy: 20)
        #expect(DictionaryLookup.word(in: text, selection: caret..<caret).map { text[$0.range] } == "slept")  // highlight
        #expect(at(0, length: text.count) == nil)  // the whole sentence isn't a term
    }

    @Test func picksExactHeadwordsThenLemmas() {
        #expect(DictionaryLookup.recordIndices(headwords: ["In", "in"], term: "in") == [1])
        #expect(DictionaryLookup.recordIndices(headwords: ["cat", "cat", "CAT"], term: "cat") == [0, 1])
        #expect(DictionaryLookup.recordIndices(headwords: ["Hello"], term: "hello") == [0])
        #expect(DictionaryLookup.recordIndices(headwords: ["the", "thè", "thế"], term: "the") == [0])
        #expect(DictionaryLookup.recordIndices(headwords: ["cát", "cất", "cắt"], term: "cat") == [])
        #expect(DictionaryLookup.recordIndices(headwords: ["run", "running"], term: "ran") == [0])
    }

    @Test func readsLanguagesFromTheName() {
        let anhViet = DictionaryLookup.info(name: "VIETTIEN Anh-Việt (v6.0b1.b5)", primaryLanguage: "en_GB")
        #expect(anhViet.source == "en" && anhViet.target == "vi")
        let vietAnh = DictionaryLookup.info(name: "VIETTIEN Việt-Anh (v6.0b1)", primaryLanguage: nil)
        #expect(vietAnh.source == "vi" && vietAnh.target == "en")
        let french = DictionaryLookup.info(name: "French – English", primaryLanguage: "fr")
        #expect(french.source == "fr" && french.target == "en")
    }

    @Test func fallsBackToPrimaryLanguageAsMonolingual() {
        let noad = DictionaryLookup.info(name: "New Oxford American Dictionary", primaryLanguage: "en_US")
        #expect(noad.source == "en" && noad.target == "en")
        let unknown = DictionaryLookup.info(name: "My Glossary", primaryLanguage: nil)
        #expect(unknown.source == nil && unknown.target == nil)
    }

    @Test func prefersBilingualForThePairThenMonolingualInTheSource() {
        let dictionaries = [
            DictionaryLookup.Info(name: "Việt-Anh", source: "vi", target: "en"),
            DictionaryLookup.Info(name: "Anh-Việt", source: "en", target: "vi"),
            DictionaryLookup.Info(name: "NOAD", source: "en", target: "en"),
            DictionaryLookup.Info(name: "Việt-Việt", source: "vi", target: "vi"),
            DictionaryLookup.Info(name: "Glossary", source: nil, target: nil),
        ]
        let enVi = DictionaryLookup.tiers(dictionaries, info: { $0 }, from: "en", to: "vi").map { $0.map(\.name) }
        #expect(enVi == [["Anh-Việt"], ["NOAD", "Glossary"]])
        let viEn = DictionaryLookup.tiers(dictionaries, info: { $0 }, from: "vi", to: "en").map { $0.map(\.name) }
        #expect(viEn == [["Việt-Anh"], ["Việt-Việt", "Glossary"]])
        let zhEn = DictionaryLookup.tiers(dictionaries, info: { $0 }, from: "zh-CN", to: "en").map { $0.map(\.name) }
        #expect(zhEn == [[], ["Glossary"]])
    }
}

struct TextStatsTests {
    @Test func countsWordsAndCharacters() {
        #expect(TextStats.describe("") == "")
        #expect(TextStats.describe("a") == "1 word • 1 character")
        #expect(TextStats.describe("Hello,  world\nagain") == "3 words • 19 characters")
    }
}

struct SpeechServiceTests {
    @Test func picksExactThenBaseLanguageVoice() {
        let voices = ["en-US", "en-GB", "vi-VN", "zh-CN", "zh-TW", "he-IL"]
        #expect(SpeechService.voiceLanguage(for: "vi", available: voices) == "vi-VN")
        #expect(SpeechService.voiceLanguage(for: "en", available: voices) == "en-US")
        #expect(SpeechService.voiceLanguage(for: "zh-TW", available: voices) == "zh-TW")
        #expect(SpeechService.voiceLanguage(for: "iw", available: voices) == "he-IL")
        #expect(SpeechService.voiceLanguage(for: "yua", available: voices) == nil)
    }
}

struct PasteboardSnapshotTests {
    @Test @MainActor func restoresPreviousContents() {
        let pasteboard = NSPasteboard(name: .init("com.betty.translator.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        let snapshot = PasteboardSnapshot.take(from: pasteboard)
        PasteService.copy("translation", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "translation")
        snapshot.restore(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "before")
    }
}

struct PanelPlacementTests {
    // A screen offset like a second display: default anchor (1640, 840).
    private let visible = CGRect(x: 1000, y: 0, width: 1280, height: 1000)
    private let size = CGSize(width: 780, height: 420)

    @Test func defaultFrameIsCenteredBelowTheTop() {
        #expect(PanelPlacement.frame(size: size, in: visible, offset: nil) == CGRect(x: 1250, y: 420, width: 780, height: 420))
    }

    @Test func offsetRoundTripsAndFollowsTheScreen() {
        let dragged = CGRect(x: 1100, y: 500, width: 780, height: 420)  // top-center (1490, 920)
        let offset = PanelPlacement.offset(of: dragged, in: visible)
        #expect(offset == CGPoint(x: -150, y: 80))
        #expect(PanelPlacement.frame(size: size, in: visible, offset: offset) == dragged)
        // Same spot relative to the default on another screen.
        let other = CGRect(x: 0, y: 0, width: 1920, height: 1080)  // anchor (960, 907.2)
        #expect(PanelPlacement.frame(size: size, in: other, offset: offset) == CGRect(x: 420, y: 567, width: 780, height: 420))
        #expect(PanelPlacement.offset(of: PanelPlacement.frame(size: size, in: other, offset: nil), in: other) == nil)
    }

    @Test func frameStaysOnScreen() {
        let frame = PanelPlacement.frame(size: size, in: visible, offset: CGPoint(x: 5000, y: 5000))
        #expect(frame == CGRect(x: 1500, y: 580, width: 780, height: 420))  // right and top edges of the screen
    }

    @Test func snapsOnlyWithinDistanceOnEachAxis() {
        // 10 pt right of center (snaps), 30 pt below the default height (doesn't).
        let near = CGRect(x: 1260, y: 390, width: 780, height: 420)
        #expect(PanelPlacement.alignment(of: near, in: visible) == .init(centered: true, atDefaultHeight: false))
        #expect(PanelPlacement.snapped(near, in: visible) == CGRect(x: 1250, y: 390, width: 780, height: 420))
        let far = CGRect(x: 1263, y: 408, width: 780, height: 420)  // 13 pt right, 12 pt below
        #expect(PanelPlacement.snapped(far, in: visible) == CGRect(x: 1263, y: 420, width: 780, height: 420))
    }
}

@MainActor
struct AppSettingsTests {
    private func makeSettings() -> AppSettings {
        let suite = "com.betty.translator.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }

    @Test func defaultsToEnglishVietnameseAuto() {
        let settings = makeSettings()
        #expect(settings.source == LanguageCatalog.english)
        #expect(settings.target == LanguageCatalog.vietnamese)
        #expect(settings.engineMode == .auto)
        #expect(settings.googleAPIVersion == .v3)
        #expect(settings.panelSize == AppSettings.defaultPanelSize)
        #expect(settings.showMenuBarIcon)
        #expect(settings.dictionaryLookup)
    }

    @Test func panelOffsetPersistsAndResets() {
        let suite = "com.betty.translator.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.panelOffset == nil)
        settings.panelOffset = CGPoint(x: -120, y: 0)
        #expect(AppSettings(defaults: defaults).panelOffset == CGPoint(x: -120, y: 0))
        settings.panelOffset = nil
        #expect(AppSettings(defaults: defaults).panelOffset == nil)
    }

    @Test func routerConfigurationReflectsKeys() {
        let settings = makeSettings()
        #expect(settings.routerConfiguration == .init(mode: .auto, googleConfigured: false, deepLConfigured: false))
        settings.googleAPIKey = "k"
        #expect(!settings.isGoogleConfigured)  // v3 needs a project
        settings.googleProjectID = "p"
        settings.deepLAPIKey = "d:fx"
        #expect(settings.routerConfiguration == .init(mode: .auto, googleConfigured: true, deepLConfigured: true))
    }
}

struct TranslationHistoryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func entry(_ text: String, _ pair: (String, String) = ("en", "vi"), age: TimeInterval = 0) -> HistoryEntry {
        HistoryEntry(date: now.addingTimeInterval(-age), sourceText: text, translation: "t:" + text,
                     sourceCode: pair.0, targetCode: pair.1, engine: .google)
    }

    @Test func keepsOnlyTheLast30Days() {
        let kept = entry("kept", age: 30 * day - 1)
        let dropped = entry("dropped", age: 30 * day + 1)
        #expect(TranslationHistory.pruned([kept, dropped], now: now) == [kept])
    }

    @Test func typingReplacesTheSessionEntry() {
        let hel = entry("hel")
        var list = TranslationHistory.recording(hel, after: nil, in: [], now: now)
        let hello = entry("hello")
        list = TranslationHistory.recording(hello, after: hel, in: list, now: now)
        #expect(list == [hello])
        let backspaced = entry("hell")  // shortening also continues
        list = TranslationHistory.recording(backspaced, after: hello, in: list, now: now)
        #expect(list == [backspaced])
    }

    @Test func otherTextOrPairStartsANewEntry() {
        let hello = entry("hello")
        let world = entry("world")
        var list = TranslationHistory.recording(world, after: hello, in: [hello], now: now)
        #expect(list.map(\.sourceText) == ["world", "hello"])
        let french = entry("world", ("en", "fr"))
        list = TranslationHistory.recording(french, after: world, in: list, now: now)
        #expect(list.map(\.targetCode) == ["fr", "vi", "vi"])
    }

    @Test func repeatedTextMovesToTheTop() {
        let old = entry("cat", age: day)
        let other = entry("dog", age: 10)
        let again = entry("cat")
        let list = TranslationHistory.recording(again, after: nil, in: [other, old], now: now)
        #expect(list == [again, other])
    }

    @Test func searchesSourceAndTranslationIgnoringCaseAndAccents() {
        let a = HistoryEntry(date: now, sourceText: "Good morning", translation: "Chào buổi sáng",
                             sourceCode: "en", targetCode: "vi", engine: .deepL)
        let b = entry("Thank you")
        #expect(TranslationHistory.filter([a, b], query: "chao") == [a])
        #expect(TranslationHistory.filter([a, b], query: "THANK") == [b])
        #expect(TranslationHistory.filter([a, b], query: " ") == [a, b])
    }

    @Test func previewIsOneShortLine() {
        #expect(TranslationHistory.preview("one\ntwo\r\nthree") == "one two three")
        #expect(TranslationHistory.preview(String(repeating: "a", count: 500)).count == 200)
    }

    @Test func storeRoundTripsAndToleratesAMissingFile() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "history-\(UUID().uuidString)/History.json")
        let store = HistoryStore(url: url)
        #expect(await store.load().isEmpty)
        let entries = [entry("a"), entry("b", ("fr", "en"), age: day)]
        await store.save(entries)
        #expect(await store.load() == entries)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

@MainActor
struct PanelModelTests {
    private func makeModel(history: HistoryStore? = nil) -> PanelModel {
        let suite = "com.betty.translator.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PanelModel(settings: AppSettings(defaults: defaults), historyStore: history ?? Self.temporaryStore())
    }

    private static func temporaryStore() -> HistoryStore {
        HistoryStore(url: FileManager.default.temporaryDirectory.appending(path: "history-\(UUID().uuidString).json"))
    }

    private func key(_ code: UInt16, _ chars: String = "", _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                         characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
    }

    @Test func shortcutsOpenOverlays() {
        let model = makeModel()
        #expect(model.handleKey(key(35, "p", .command)))
        #expect(model.overlay == .picker(.target))
        #expect(model.handleKey(key(35, "P", [.command, .shift])))
        #expect(model.overlay == .picker(.source))
        #expect(model.handleKey(key(53)))  // esc closes the overlay only
        #expect(model.overlay == .none)
        #expect(model.handleKey(key(40, "k", .command)))
        #expect(model.overlay == .actions)
        #expect(model.handleKey(key(40, "k", .command)))  // toggles
        #expect(model.overlay == .none)
    }

    @Test func escapeClearsTextThenCloses() {
        let model = makeModel()
        model.sourceText = "hello"
        #expect(model.handleKey(key(53)))
        #expect(model.sourceText.isEmpty)
        #expect(model.handleKey(key(53)))  // empty: dismisses
        #expect(model.sourceText.isEmpty)
    }

    @Test func commandDSwapsLanguages() {
        let model = makeModel()
        let (source, target) = (model.source, model.target)
        #expect(model.handleKey(key(2, "d", .command)))
        #expect(model.source == target)
        #expect(model.target == source)
        #expect(!model.handleKey(key(1, "s", .command)))
    }

    @Test func plainTypingPassesThrough() {
        let model = makeModel()
        #expect(!model.handleKey(key(0, "a")))
        #expect(!model.handleKey(key(36, "\r", .shift)))  // shift+enter: newline
        #expect(!model.handleKey(key(0, "a", .command)))  // cmd+a: select all in the editor
    }

    @Test func pickerSelectionSwapsWhenPairCollides() {
        let model = makeModel()
        model.select(LanguageCatalog.vietnamese, for: .source)
        #expect(model.source == LanguageCatalog.vietnamese)
        #expect(model.target == LanguageCatalog.english)
        #expect(model.settings.recentSourceCodes == ["vi"])
    }

    @Test func pickerRowsShowRecentsThenAll() {
        let model = makeModel()
        model.settings.recentTargetCodes = ["fr", "de"]
        model.overlay = .picker(.target)
        let rows = model.pickerRows
        #expect(rows.prefix(2).map(\.language.code) == ["fr", "de"])
        let firstTwoAreRecent = rows.prefix(2).allSatisfy(\.isRecent)
        #expect(firstTwoAreRecent)
        #expect(rows.count == LanguageCatalog.all.count + 2)
        model.overlayQuery = "viet"
        #expect(model.pickerRows.first?.language == LanguageCatalog.vietnamese)
        #expect(model.overlayIndex == 0)
    }

    @Test func arrowKeysMoveWithinBounds() {
        let model = makeModel()
        model.overlay = .actions
        model.overlayQuery = "copy"
        let count = model.filteredActions.count
        #expect(count == 2)
        #expect(model.handleKey(key(125)))
        #expect(model.handleKey(key(125)))
        #expect(model.overlayIndex == count - 1)
        #expect(model.handleKey(key(126)))
        #expect(model.handleKey(key(126)))
        #expect(model.overlayIndex == 0)
    }

    @Test func freshSelectionReplacesTextOnShow() {
        let model = makeModel()
        model.sourceText = "old"
        model.prepareForShow(selection: nil)
        #expect(model.sourceText == "old")
        model.prepareForShow(selection: "  ")
        #expect(model.sourceText == "old")
        model.prepareForShow(selection: "fresh")
        #expect(model.sourceText == "fresh")
        #expect(model.selectAllToken == 3)
    }

    @Test func freshSelectionTranslatesWithoutTheDebounce() async throws {
        let model = makeModel()
        model.prepareForShow(selection: "fresh")
        try await Task.sleep(for: .milliseconds(50))  // well under the 250 ms debounce
        #expect(model.status != .idle)
    }

    @Test func emptyTextClearsTranslation() async throws {
        let model = makeModel()
        model.sourceText = "hello"
        #expect(model.status == .idle)  // debounce not elapsed
        model.sourceText = ""
        #expect(model.translation.isEmpty)
        #expect(model.status == .idle)
    }

    @Test func historyOpensFromActionsAndEscGoesBack() {
        let model = makeModel()
        model.sourceText = "hello"
        #expect(model.handleKey(key(40, "k", .command)))
        model.overlayQuery = "history"
        #expect(model.filteredActions.first?.id == "history")
        #expect(model.handleKey(key(36, "\r")))
        #expect(model.screen == .history)
        #expect(model.overlay == .none)
        #expect(!model.handleKey(key(0, "a")))  // typing goes to the search field
        model.historyQuery = "x"
        #expect(model.handleKey(key(53)))  // esc clears the search first
        #expect(model.historyQuery.isEmpty && model.screen == .history)
        #expect(model.handleKey(key(53)))
        #expect(model.screen == .translator)
        #expect(model.sourceText == "hello")  // the translator keeps its text
    }

    @Test func openingAnEntryRestoresItsTextPairAndTranslation() async {
        let store = Self.temporaryStore()
        let older = HistoryEntry(date: .now.addingTimeInterval(-60), sourceText: "bonjour", translation: "hello",
                                 sourceCode: "fr", targetCode: "en", engine: .deepL)
        let newer = HistoryEntry(date: .now, sourceText: "cat", translation: "con mèo",
                                 sourceCode: "en", targetCode: "vi", engine: .google)
        await store.save([newer, older])
        let model = makeModel(history: store)
        await model.historyLoadTask?.value
        model.showHistory()
        #expect(model.filteredHistory == [newer, older])
        #expect(model.handleKey(key(125)))  // down to "bonjour"
        #expect(model.handleKey(key(125)))  // stays on the last row
        #expect(model.selectedHistoryEntry == older)
        #expect(model.handleKey(key(36, "\r")))
        #expect(model.screen == .translator)
        #expect(model.sourceText == "bonjour")
        #expect(model.source.code == "fr" && model.target.code == "en")
        #expect(model.translation == "hello")
        #expect(model.status == .done(.deepL))
    }

    @Test func deletingAnEntryPersists() async {
        let store = Self.temporaryStore()
        let a = HistoryEntry(date: .now, sourceText: "a", translation: "A", sourceCode: "en", targetCode: "vi", engine: .apple)
        let b = HistoryEntry(date: .now.addingTimeInterval(-5), sourceText: "b", translation: "B", sourceCode: "en", targetCode: "vi", engine: .apple)
        await store.save([a, b])
        let model = makeModel(history: store)
        await model.historyLoadTask?.value
        model.showHistory()
        model.historyQuery = "b"
        #expect(model.handleKey(key(51, "\u{7F}", .command)))
        #expect(model.history == [a])
        await model.historySaveTask?.value
        #expect(await store.load() == [a])
        model.historyQuery = ""
        model.clearHistory()
        await model.historySaveTask?.value
        #expect(await store.load().isEmpty)
    }
}
