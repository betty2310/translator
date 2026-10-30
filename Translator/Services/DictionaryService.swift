import CoreServices
import Foundation

/// Looks short terms up in the dictionaries enabled in Dictionary.app, in its order, including the ones the user
/// installed in ~/Library/Dictionaries (D35). After the first load a lookup takes a few ms, so a word gets an
/// answer before any network engine.
///
/// Querying one dictionary at a time and reading its records as HTML needs private Dictionary Services calls,
/// resolved at runtime. Without them it falls back to the public `DCSCopyTextDefinition`, which answers in plain
/// text from the first dictionary that has the term.
/// Docs: https://developer.apple.com/documentation/coreservices/dictionary_services
actor DictionaryService {
    private typealias GetActive = @convention(c) () -> Unmanaged<CFArray>?
    private typealias GetString = @convention(c) (CFTypeRef) -> Unmanaged<CFString>?
    private typealias CopyDefinition = @convention(c) (CFTypeRef?, CFString, CFRange) -> Unmanaged<CFString>?
    private typealias CopyRecords = @convention(c) (CFTypeRef, CFString, UnsafeRawPointer?, UnsafeRawPointer?) -> Unmanaged<CFArray>?
    private typealias CopyRecordData = @convention(c) (CFTypeRef, Int) -> Unmanaged<CFString>?

    /// At most this many same-headword records (homographs: "bear" the animal, "bear" the verb) per dictionary.
    private static let maxRecords = 3

    private let getActive: GetActive?
    private let getName: GetString?
    private let getPrimaryLanguage: GetString?
    private let copyDefinition: CopyDefinition?
    private let copyRecords: CopyRecords?
    private let getHeadword: GetString?
    private let copyRecordData: CopyRecordData?
    private var infoCache: [String: DictionaryLookup.Info] = [:]

    init() {
        let handle = dlopen(nil, RTLD_NOW)
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: type) }
        }
        getActive = symbol("DCSGetActiveDictionaries", as: GetActive.self)
        getName = symbol("DCSDictionaryGetName", as: GetString.self)
        getPrimaryLanguage = symbol("DCSDictionaryGetPrimaryLanguage", as: GetString.self)
        copyDefinition = symbol("DCSCopyTextDefinition", as: CopyDefinition.self)
        copyRecords = symbol("DCSCopyRecordsForSearchString", as: CopyRecords.self)
        getHeadword = symbol("DCSRecordGetHeadword", as: GetString.self)
        copyRecordData = symbol("DCSRecordCopyData", as: CopyRecordData.self)
    }

    /// Loads the dictionaries at startup so the first lookup on the hotkey path is fast too (D4).
    func warmUp() {
        _ = activeDictionaries()
    }

    func lookUp(_ text: String, from source: Language, to target: Language) -> [DictionaryEntry] {
        guard let term = DictionaryLookup.term(for: text) else { return [] }
        let range = CFRange(location: 0, length: (term as NSString).length)
        guard let dictionaries = activeDictionaries(), let copyDefinition else {
            guard let definition = DCSCopyTextDefinition(nil, term as CFString, range)?.takeRetainedValue() else { return [] }
            return [DictionaryParser.entry(dictionary: "Dictionary", term: term, plainText: definition as String)].compactMap { $0 }
        }
        for tier in DictionaryLookup.tiers(dictionaries, info: \.info, from: source.code, to: target.code) {
            var entries: [DictionaryEntry] = []
            for dictionary in tier {
                // The plain-text call says whether the dictionary has the term (inflections included).
                guard let definition = copyDefinition(dictionary.ref, term as CFString, range)?.takeRetainedValue() else { continue }
                let entry = richEntry(for: term, in: dictionary.ref, name: dictionary.info.name)
                    ?? DictionaryParser.entry(dictionary: dictionary.info.name, term: term, plainText: definition as String)
                if let entry { entries.append(entry) }
            }
            if !entries.isEmpty { return entries }
        }
        return []
    }

    /// The entry from the records' HTML, or nil when the private calls are missing or the HTML can't be read.
    private func richEntry(for term: String, in dictionary: CFTypeRef, name: String) -> DictionaryEntry? {
        guard let copyRecords, let getHeadword, let copyRecordData,
              let records = copyRecords(dictionary, term as CFString, nil, nil)?.takeRetainedValue() as [AnyObject]? else { return nil }
        let headwords = records.map { getHeadword($0)?.takeUnretainedValue() as String? ?? "" }
        let html = DictionaryLookup.recordIndices(headwords: headwords, term: term).prefix(Self.maxRecords).compactMap {
            copyRecordData(records[$0], 0)?.takeRetainedValue() as String?
        }
        guard !html.isEmpty else { return nil }
        return DictionaryParser.entry(dictionary: name, term: term, records: html)
    }

    /// Asked every time, so enabling or reordering dictionaries in Dictionary.app takes effect without a relaunch.
    private func activeDictionaries() -> [(ref: CFTypeRef, info: DictionaryLookup.Info)]? {
        guard let getActive, let getName, let array = getActive()?.takeUnretainedValue() else { return nil }
        return (array as [AnyObject]).map { dictionary in
            let name = getName(dictionary)?.takeUnretainedValue() as String? ?? "Dictionary"
            if let info = infoCache[name] { return (dictionary, info) }
            let language = getPrimaryLanguage?(dictionary)?.takeUnretainedValue() as String?
            let info = DictionaryLookup.info(name: name, primaryLanguage: language)
            infoCache[name] = info
            return (dictionary, info)
        }
    }
}

/// The pure half of the dictionary lookup: what counts as a term, which languages a dictionary covers, which
/// dictionaries answer for a language pair, and which records to read. Tested.
enum DictionaryLookup {
    struct Info: Equatable, Sendable {
        let name: String
        /// Base language codes (`en`, `vi`); equal for a monolingual dictionary, nil when unknown.
        let source: String?
        let target: String?
    }

    static let maxWords = 4
    static let maxLength = 40

    /// The text to look up, or nil when it isn't a word or short phrase. Up to four words, so Vietnamese
    /// compounds ("học sinh") and phrasal verbs ("take off") still match; surrounding punctuation is dropped.
    static func term(for text: String) -> String? {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !term.isEmpty, term.count <= maxLength, !term.contains(where: \.isNewline) else { return nil }
        guard term.split(whereSeparator: \.isWhitespace).count <= maxWords else { return nil }
        return term
    }

    /// The term for a click in longer text (D36) and the range to highlight: the selection when it's a word or
    /// short phrase (a double-click or a drag), else the word the caret is in or right after. Nil between words
    /// or for a long selection.
    static func word(in text: String, selection: Range<String.Index>) -> (term: String, range: Range<String.Index>)? {
        guard selection.upperBound <= text.endIndex else { return nil }
        if !selection.isEmpty { return term(for: String(text[selection])).map { ($0, selection) } }
        let caret = selection.lowerBound
        var word: (String, Range<String.Index>)?
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, range, _, stop in
            guard range.lowerBound <= caret else { stop = true; return }
            guard caret <= range.upperBound, let substring else { return }
            word = (substring, range)
            // A word the caret is inside beats the one it just ends (no space between them in CJK text).
            if caret < range.upperBound { stop = true }
        }
        guard let (substring, range) = word, let term = term(for: substring) else { return nil }
        return (term, range)
    }

    /// Languages from a name like "VIETTIEN Anh-Việt" or "Vietnamese – English", else from the bundle's primary
    /// language (then taken as monolingual, e.g. New Oxford American Dictionary). Custom dictionaries often
    /// declare no language, or a wrong one, so the name wins.
    static func info(name: String, primaryLanguage: String?) -> Info {
        if let pair = languagePair(in: name) {
            return Info(name: name, source: pair.source, target: pair.target)
        }
        let language = primaryLanguage.map(baseCode)
        return Info(name: name, source: language, target: language)
    }

    /// Bilingual dictionaries for the pair first; when none has the term, monolingual ones in the source
    /// language and ones whose languages are unknown. Order within a tier is Dictionary.app's.
    static func tiers<D>(_ dictionaries: [D], info: (D) -> Info, from source: String, to target: String) -> [[D]] {
        let source = baseCode(source)
        let target = baseCode(target)
        let bilingual = dictionaries.filter {
            let info = info($0)
            return info.source == source && info.target == target
        }
        let fallback = dictionaries.filter {
            let info = info($0)
            return (info.source == nil || info.source == source) && info.target == info.source
        }
        return [bilingual, fallback]
    }

    /// Which search results to read. The search ignores diacritics ("the" also finds "thè", "thế"), so exact
    /// headwords win, case-sensitive first; else the first result that isn't just the term with other
    /// diacritics, which is an inflection's lemma ("ran" → "run").
    static func recordIndices(headwords: [String], term: String) -> [Int] {
        let exactCase = headwords.indices.filter { headwords[$0] == term }
        if !exactCase.isEmpty { return exactCase }
        let exact = headwords.indices.filter { headwords[$0].caseInsensitiveCompare(term) == .orderedSame }
        if !exact.isEmpty { return exact }
        let folded = fold(term)
        return headwords.indices.first { fold(headwords[$0]) != folded }.map { [$0] } ?? []
    }

    static func baseCode(_ code: String) -> String {
        let base = code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? code
        return base == "iw" ? "he" : base
    }

    private static func languagePair(in name: String) -> (source: String, target: String)? {
        for match in name.matches(of: /(\p{L}+)\s*[-–—]\s*(\p{L}+)/) {
            if let source = language(named: String(match.1)), let target = language(named: String(match.2)) {
                return (source, target)
            }
        }
        return nil
    }

    private static func language(named word: String) -> String? {
        aliases[fold(word)]
    }

    private static func fold(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// English names from the catalog ("Chinese (Simplified)" → "chinese"), plus the short Vietnamese names
    /// Vietnamese dictionaries use ("Anh-Việt").
    private static let aliases: [String: String] = {
        var aliases: [String: String] = [:]
        for language in LanguageCatalog.all {
            let word = language.name.split(separator: " ").first.map(String.init) ?? language.name
            if aliases[fold(word)] == nil { aliases[fold(word)] = baseCode(language.code) }
        }
        let vietnamese = ["anh": "en", "viet": "vi", "phap": "fr", "đuc": "de", "nhat": "ja", "han": "ko",
                          "trung": "zh", "hoa": "zh", "nga": "ru", "y": "it", "thai": "th", "lao": "lo"]
        aliases.merge(vietnamese) { _, vietnamese in vietnamese }
        return aliases
    }()
}
