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

@MainActor
struct PanelModelTests {
    private func makeModel() -> PanelModel {
        let suite = "com.betty.translator.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PanelModel(settings: AppSettings(defaults: defaults))
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

    @Test func emptyTextClearsTranslation() async throws {
        let model = makeModel()
        model.sourceText = "hello"
        #expect(model.status == .idle)  // debounce not elapsed
        model.sourceText = ""
        #expect(model.translation.isEmpty)
        #expect(model.status == .idle)
    }
}
