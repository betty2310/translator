import Foundation

/// An element of a forgiving HTML tree. Dictionary bodies are XHTML, but some entries aren't well-formed
/// (unquoted attributes), so `HTMLTree.parse` never fails: stray closing tags are ignored.
struct HTMLElement: Equatable, Sendable {
    enum Node: Equatable, Sendable {
        case text(String)
        case element(HTMLElement)
    }

    var name: String
    var classes: [String]
    var children: [Node] = []

    func has(_ className: String) -> Bool { classes.contains(className) }

    var text: String { text(excluding: { _ in false }) }

    func text(excluding skip: (HTMLElement) -> Bool) -> String {
        children.map { node in
            switch node {
            case .text(let text): text
            case .element(let element): skip(element) ? "" : element.text(excluding: skip)
            }
        }.joined()
    }

    /// Descendants matching `predicate`, in document order, without looking inside a match or a `stop` element.
    func find(_ predicate: (HTMLElement) -> Bool, stoppingAt stop: (HTMLElement) -> Bool = { _ in false }) -> [HTMLElement] {
        var found: [HTMLElement] = []
        for case .element(let element) in children {
            if predicate(element) {
                found.append(element)
            } else if !stop(element) {
                found += element.find(predicate, stoppingAt: stop)
            }
        }
        return found
    }

    func first(_ predicate: (HTMLElement) -> Bool, stoppingAt stop: (HTMLElement) -> Bool = { _ in false }) -> HTMLElement? {
        for case .element(let element) in children {
            if predicate(element) { return element }
            if !stop(element), let found = element.first(predicate, stoppingAt: stop) { return found }
        }
        return nil
    }
}

enum HTMLTree {
    private static let voidElements: Set<String> = ["img", "br", "hr", "meta", "link", "base", "input", "source"]

    static func parse(_ html: String) -> HTMLElement {
        var stack = [HTMLElement(name: "#root", classes: [])]
        func append(text: Substring) {
            let text = decodeEntities(String(text))
            if !text.isEmpty { stack[stack.count - 1].children.append(.text(text)) }
        }
        func closeTop() {
            let element = stack.removeLast()
            stack[stack.count - 1].children.append(.element(element))
        }

        var rest = html[...]
        while let open = rest.utf8.firstIndex(of: UInt8(ascii: "<")) {
            if open > rest.startIndex { append(text: rest[..<open]) }
            guard let close = rest[open...].utf8.firstIndex(of: UInt8(ascii: ">")) else {
                rest = rest[open...]
                break
            }
            let tag = rest[rest.index(after: open)..<close]
            rest = rest[rest.index(after: close)...]
            if tag.first == "!" || tag.first == "?" { continue }
            if tag.first == "/" {
                let name = tag.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
                if let index = stack.lastIndex(where: { $0.name == name }), index > 0 {
                    while stack.count > index { closeTop() }
                }
                continue
            }
            let name = String(tag.prefix { !$0.isWhitespace && $0 != "/" }).lowercased()
            guard !name.isEmpty else { continue }
            let element = HTMLElement(name: name, classes: classes(in: tag))
            if tag.last == "/" || voidElements.contains(name) {
                stack[stack.count - 1].children.append(.element(element))
            } else {
                stack.append(element)
            }
        }
        if !rest.isEmpty { append(text: rest) }
        while stack.count > 1 { closeTop() }
        return stack[0]
    }

    private static func classes(in tag: Substring) -> [String] {
        guard let match = tag.firstMatch(of: /class\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>\/]+))/) else { return [] }
        let value = match.1 ?? match.2 ?? match.3 ?? ""
        return value.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = text[...]
        while let ampersand = rest.firstIndex(of: "&") {
            result += rest[..<ampersand]
            let afterAmpersand = rest.index(after: ampersand)
            if let semicolon = rest[afterAmpersand...].prefix(10).firstIndex(of: ";"),
               let character = character(forEntity: rest[afterAmpersand..<semicolon]) {
                result.append(character)
                rest = rest[rest.index(after: semicolon)...]
            } else {
                result.append("&")
                rest = rest[afterAmpersand...]
            }
        }
        return result + rest
    }

    private static func character(forEntity name: Substring) -> Character? {
        switch name {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return " "
        default:
            guard name.hasPrefix("#") else { return nil }
            let digits = name.dropFirst()
            let value = digits.hasPrefix("x") || digits.hasPrefix("X") ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
            return value.flatMap(Unicode.Scalar.init).map(Character.init)
        }
    }
}

/// Turns a dictionary record into a `DictionaryEntry` (D35). Two formats are understood: Apple's Oxford
/// dictionaries (semantic classes: `hw`, `ph`, `pos`, `df`, `ex`, …) and the `<pre>` layout of VIETTIEN-style
/// Vietnamese dictionaries (`m` headword line, `lt` part of speech, "◦" senses, `<li>` examples with a
/// `<font>` translation). Anything else, and the plain-text fallback, goes through the line-based reader.
/// Pure, tested with canned records.
enum DictionaryParser {
    static func entry(dictionary: String, term: String, records: [String]) -> DictionaryEntry? {
        var entry = DictionaryEntry(dictionary: dictionary, headword: "")
        for record in records {
            let root = HTMLTree.parse(record)
            let parsed = root.first { $0.has("hw") } != nil ? oxford(root, dictionary: dictionary) : lineBased(root, dictionary: dictionary)
            if entry.headword.isEmpty { entry.headword = parsed.headword }
            for pronunciation in parsed.pronunciations where !entry.pronunciations.contains(pronunciation) {
                entry.pronunciations.append(pronunciation)
            }
            entry.sections += parsed.sections
        }
        if entry.headword.isEmpty { entry.headword = term }
        return entry.sections.isEmpty ? nil : entry
    }

    static func entry(dictionary: String, term: String, plainText: String) -> DictionaryEntry? {
        var builder = LineBuilder(dictionary: dictionary, headword: term)
        builder.consume(plainText)
        let entry = builder.finish()
        return entry.sections.isEmpty ? nil : entry
    }

    // MARK: Parts of speech

    /// Vietnamese abbreviations and names → English labels, longest first so "ng.đt." beats "đt.".
    private static let partsOfSpeech: [(String, String)] = [
        ("ngoại động từ", "transitive verb"), ("nội động từ", "intransitive verb"), ("trợ động từ", "auxiliary verb"),
        ("động từ", "verb"), ("danh từ", "noun"), ("tính từ", "adjective"), ("phó từ", "adverb"), ("trạng từ", "adverb"),
        ("giới từ", "preposition"), ("liên từ", "conjunction"), ("thán từ", "interjection"), ("cảm từ", "interjection"),
        ("đại từ", "pronoun"), ("mạo từ", "article"), ("số từ", "numeral"),
        ("ng.đt.", "transitive verb"), ("n.đt.", "intransitive verb"), ("đg.từ", "verb"), ("ph.từ", "adverb"),
        ("d.từ", "noun"), ("t.từ", "adjective"), ("pht.", "adverb"), ("tht.", "interjection"), ("dt.", "noun"),
        ("tt.", "adjective"), ("đt.", "verb"), ("gt.", "preposition"), ("lt.", "conjunction"), ("mt.", "article"),
        ("st.", "numeral"),
    ]

    /// "ng.đt. took; taken" → ("transitive verb", "took; taken"). Unknown text is kept as the label.
    static func partOfSpeech(_ raw: String) -> (label: String, note: String?) {
        let text = squeezed(raw)
        for (prefix, label) in partsOfSpeech where text.lowercased().hasPrefix(prefix) {
            let rest = text.dropFirst(prefix.count)
            guard rest.isEmpty || prefix.hasSuffix(".") || rest.first?.isLetter == false else { continue }
            let note = squeezed(String(rest)).trimmingCharacters(in: CharacterSet(charactersIn: ",;:").union(.whitespaces))
            return (label, note.isEmpty ? nil : note)
        }
        return (text, nil)
    }

    static func isPartOfSpeech(_ text: String) -> Bool {
        let lowered = squeezed(text).lowercased()
        return partsOfSpeech.contains { $0.0 == lowered }
    }

    /// "1. Nói … 2. Tỏ …" → two senses; text without a "1." … "2." sequence stays whole.
    static func numberedParts(_ text: String) -> [String] {
        let markers = text.matches(of: /(?:^|\s)(\d{1,2})\.\s/)
        guard markers.count >= 2, markers.first.map({ Int($0.1) == 1 }) == true else { return [text] }
        var parts: [String] = []
        for (index, marker) in markers.enumerated() {
            let end = index + 1 < markers.count ? markers[index + 1].range.lowerBound : text.endIndex
            let part = squeezed(String(text[marker.range.upperBound..<end]))
            if !part.isEmpty { parts.append(part) }
        }
        let lead = squeezed(String(text[..<markers[0].range.lowerBound]))
        return lead.isEmpty ? parts : [lead] + parts
    }

    /// "(điện ảnh) cảnh quay" → label "điện ảnh", text "cảnh quay".
    static func extractingFieldLabel(_ sense: DictionaryEntry.Sense) -> DictionaryEntry.Sense {
        guard let match = sense.text.prefixMatch(of: /\(([^()]{1,40})\)\s+/), match.range.upperBound < sense.text.endIndex else { return sense }
        var sense = sense
        sense.labels.append(squeezed(String(match.1)))
        sense.text = String(sense.text[match.range.upperBound...])
        return sense
    }

    /// Collapses whitespace and drops private-use glyphs (icons in a dictionary's own font).
    static func squeezed(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.unicodeScalars.filter { !(0xE000...0xF8FF).contains($0.value) })
        return String(scalars).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func trimmingTrailing(_ characters: String, from text: String) -> String {
        var text = text
        while let last = text.last, characters.contains(last) || last.isWhitespace { text.removeLast() }
        return text
    }

    // MARK: Oxford (Apple's bundled dictionaries)

    private static func isSense(_ element: HTMLElement) -> Bool { element.has("msDict") || element.has("msThes") }

    private static func oxford(_ root: HTMLElement, dictionary: String) -> DictionaryEntry {
        let headGroup = root.first { $0.has("hg") }
        var entry = DictionaryEntry(dictionary: dictionary, headword: squeezed(root.first { $0.has("hw") }?.text(excluding: { $0.has("ty_hom") }) ?? ""))
        entry.pronunciations = (headGroup?.find { $0.has("ph") } ?? []).map { "/" + squeezed($0.text(excluding: { $0.has("gp") })) + "/" }
        func visit(_ element: HTMLElement) {
            if element.has("hg") { return }
            if element.has("se1") {
                let header = element.find({ $0.has("pos") || $0.has("infg") || $0.has("gg") }, stoppingAt: { isSense($0) || $0.has("se2") })
                let title = header.first { $0.has("pos") }.map { squeezed($0.text) }
                let note = header.filter { !$0.has("pos") }.map { squeezed($0.text) }.joined(separator: " ")
                entry.sections.append(.init(kind: .main, title: title, note: note.isEmpty ? nil : note, senses: senses(in: element)))
                return
            }
            if element.has("subEntry") {
                let title = element.first { $0.has("l") }.map { squeezed($0.text) }
                entry.sections.append(.init(kind: .phrase, title: title, senses: senses(in: element)))
                return
            }
            if element.has("etym") {
                let origin = squeezed(element.text(excluding: { $0.has("ty_label") }))
                if !origin.isEmpty { entry.sections.append(.init(kind: .extra, title: "Origin", senses: [.init(text: origin)])) }
                return
            }
            for case .element(let child) in element.children { visit(child) }
        }
        visit(root)
        entry.sections.removeAll { $0.senses.isEmpty }
        return entry
    }

    private static func senses(in element: HTMLElement) -> [DictionaryEntry.Sense] {
        element.find(isSense).flatMap { found in [sense(found)].compactMap { $0 } + senses(in: found) }
    }

    private static func sense(_ element: HTMLElement) -> DictionaryEntry.Sense? {
        let first = { (className: String) in element.first({ $0.has(className) }, stoppingAt: isSense).map { squeezed($0.text) } }
        var text = first("df") ?? first("synList") ?? first("xrg") ?? ""
        text = trimmingTrailing(":.;", from: text)
        let labels = element.find({ ["lg", "reg", "sj", "gg"].contains(where: $0.has) }, stoppingAt: { isSense($0) || $0.has("eg") || $0.has("df") || $0.has("synList") || $0.has("antList") })
            .map { squeezed($0.text).trimmingCharacters(in: CharacterSet(charactersIn: "[]() ")) }
            .filter { !$0.isEmpty }
        let examples = element.find({ $0.has("ex") }, stoppingAt: isSense)
            .map { squeezed($0.text) }
            .filter { !$0.isEmpty }
            .map { DictionaryEntry.Example(text: $0) }
        guard !text.isEmpty || !examples.isEmpty else { return nil }
        return .init(text: text, labels: labels, examples: examples, isSubsense: element.has("t_subsense"))
    }

    // MARK: VIETTIEN-style <pre> layout

    private static func lineBased(_ root: HTMLElement, dictionary: String) -> DictionaryEntry {
        var builder = LineBuilder(dictionary: dictionary, headword: "")
        builder.walk(root.children)
        return builder.finish()
    }

    /// Reads a dictionary laid out as lines: "◦" starts a sense, "▪" an example, `<li>` holds an example and its
    /// translation, and class markers start sections. Plain text goes through `consume` alone.
    fileprivate struct LineBuilder {
        let dictionary: String
        var headword: String
        var pronunciations: [String] = []
        var sections: [DictionaryEntry.Section] = []
        /// Set once inside specialized terms / encyclopedia material; later sections stay extra.
        var extraTitle: String?
        /// After "▪ term", the ": meaning" text is the translation.
        var awaitingTranslation = false
        var startsLine = true

        init(dictionary: String, headword: String) {
            self.dictionary = dictionary
            self.headword = headword
        }

        func finish() -> DictionaryEntry {
            var sections = sections
            for index in sections.indices {
                sections[index].senses.removeAll { $0.text.isEmpty && $0.examples.isEmpty }
                sections[index].senses = sections[index].senses.map(DictionaryParser.extractingFieldLabel)
            }
            sections.removeAll { $0.senses.isEmpty }
            return DictionaryEntry(dictionary: dictionary, headword: headword, pronunciations: pronunciations, sections: sections)
        }

        mutating func walk(_ nodes: [HTMLElement.Node]) {
            for node in nodes {
                switch node {
                case .text(let text): consume(text)
                case .element(let element): visit(element)
                }
            }
        }

        private mutating func visit(_ element: HTMLElement) {
            switch element.name {
            case "h1":
                if headword.isEmpty { headword = squeezed(element.text) }
                return
            case "head", "img", "audio", "a", "style", "script": return
            case "hr": startSection(.main, title: nil); return
            case "br": consume("\n"); return
            case "li": item(element); return
            default: break
            }
            if element.has("c") || element.has("ap") || element.has("z3") { return }
            if element.has("m") { headline(squeezed(element.text)); return }
            if element.has("lt") {
                let pos = partOfSpeech(element.text)
                if let extraTitle {
                    startSection(.extra, title: "\(extraTitle) · \(pos.label)", note: pos.note)
                } else {
                    startSection(.main, title: pos.label, note: pos.note)
                }
                return
            }
            if element.has("thn") || element.has("fi") || element.has("bk") { extraHeading(element); return }
            if element.has("mtnew") { startSection(extraTitle == nil ? .main : .extra, title: nil); return }
            if element.has("dk1") { fillSense(squeezed(element.text)); return }
            if element.has("dk2") {
                addExample(squeezed(element.text), translation: nil)
                awaitingTranslation = true
                return
            }
            walk(element.children)
        }

        mutating func consume(_ text: String) {
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if index > 0 {
                    startsLine = true
                    awaitingTranslation = false
                }
                var segment = squeezed(String(line))
                segment = String(segment.drop { "™▸".contains($0) }).trimmingCharacters(in: .whitespaces)
                guard !segment.isEmpty else { continue }
                defer { startsLine = false }
                if segment.hasPrefix("◦") || segment.hasPrefix("•") {
                    awaitingTranslation = false
                    startSense(squeezed(String(segment.dropFirst())))
                } else if segment.hasPrefix("▪") {
                    let example = squeezed(String(segment.dropFirst()))
                    if !example.isEmpty { addExample(example, translation: nil) }
                    awaitingTranslation = true
                } else if awaitingTranslation, segment.hasPrefix(":") {
                    awaitingTranslation = false
                    setTranslation(squeezed(String(segment.dropFirst())))
                } else if segment.wholeMatch(of: /\[[^\]]*\]/) != nil {
                    continue  // "['rʌniɳ]", "[chào]": a repeated headword or pronunciation
                } else if startsLine, sections.isEmpty || currentSenses.isEmpty, segment.caseInsensitiveCompare(headword) == .orderedSame {
                    continue
                } else if startsLine, isPartOfSpeech(segment) {
                    let pos = partOfSpeech(segment)
                    startSection(extraTitle == nil ? .main : .extra, title: pos.label)
                } else if !startsLine, var sense = lastSense {
                    sense.text = squeezed(sense.text + " " + segment)
                    lastSense = sense
                } else if currentSenses.isEmpty {
                    startSense(segment)
                } else if var sense = lastSense {
                    sense.text += sense.text.isEmpty ? segment : "\n" + segment
                    lastSense = sense
                }
            }
        }

        /// The `m` line: the headword with its pronunciations first, then idioms and phrasal verbs.
        private mutating func headline(_ text: String) {
            let pronunciations = text.matches(of: /\/[^\/]+\//).map { String($0.output) }
            let word = squeezed(String(text[..<(text.firstIndex(of: "/") ?? text.endIndex)]))
            let isHeadword = word.caseInsensitiveCompare(headword) == .orderedSame
            if self.pronunciations.isEmpty, !pronunciations.isEmpty, sections.isEmpty || isHeadword {
                for pronunciation in pronunciations where !self.pronunciations.contains(pronunciation) {
                    self.pronunciations.append(pronunciation)
                }
                if headword.isEmpty { headword = word }
                return
            }
            guard !word.isEmpty, !isHeadword else { return }
            startSection(extraTitle == nil ? .phrase : .extra, title: word)
        }

        /// "THUẬT NGỮ", "BÁCH KHOA", "Ng.: K.tế": everything from here on is extra.
        private mutating func extraHeading(_ element: HTMLElement) {
            var title = squeezed(element.text)
            if element.has("thn") {
                title = title.replacing(/^Ng\.?\s*:\s*/, with: "")
            } else {
                title = title.lowercased()
                title = title.prefix(1).uppercased() + title.dropFirst()
            }
            guard !title.isEmpty else { return }
            if let last = sections.last, last.kind == .extra, last.senses.isEmpty, let lastTitle = last.title {
                title = lastTitle + " · " + title
            }
            extraTitle = title
            startSection(.extra, title: title)
        }

        private mutating func item(_ element: HTMLElement) {
            if let idiom = element.first({ $0.has("z4") }) {
                startSection(extraTitle == nil ? .phrase : .extra, title: squeezed(idiom.text))
                return
            }
            let translation = squeezed(element.find { $0.name == "font" }.map(\.text).joined(separator: " "))
            if !translation.isEmpty {
                let source = trimmingTrailing(":", from: squeezed(element.text(excluding: { $0.name == "font" })))
                addExample(source, translation: translation)
                return
            }
            // A definition (Việt-Việt): "[đg.từ] 1. … 2. …".
            var text = squeezed(element.text)
            if let match = text.firstMatch(of: /^\[([^\]]+)\]\s*/) {
                let pos = partOfSpeech(String(match.1))
                if let last = sections.last, last.title == nil, last.senses.isEmpty {
                    sections[sections.count - 1].title = pos.label
                    sections[sections.count - 1].note = pos.note
                } else {
                    startSection(extraTitle == nil ? .main : .extra, title: pos.label, note: pos.note)
                }
                text.removeSubrange(match.range)
            }
            for part in numberedParts(text) { startSense(part) }
        }

        // MARK: Building blocks

        private var currentSenses: [DictionaryEntry.Sense] { sections.last?.senses ?? [] }

        private var lastSense: DictionaryEntry.Sense? {
            get { sections.last?.senses.last }
            set {
                guard let newValue, !currentSenses.isEmpty else { return }
                sections[sections.count - 1].senses[currentSenses.count - 1] = newValue
            }
        }

        /// An empty section is replaced rather than kept, so "THUẬT NGỮ" + "dt." become one heading.
        private mutating func startSection(_ kind: DictionaryEntry.Section.Kind, title: String?, note: String? = nil) {
            let section = DictionaryEntry.Section(kind: kind, title: title, note: note)
            if let last = sections.last, last.senses.isEmpty {
                sections[sections.count - 1] = section
            } else {
                sections.append(section)
            }
        }

        private mutating func ensureSection() {
            if sections.isEmpty { startSection(extraTitle == nil ? .main : .extra, title: extraTitle) }
        }

        private mutating func startSense(_ text: String) {
            ensureSection()
            sections[sections.count - 1].senses.append(.init(text: text))
        }

        /// "◦" followed by a `dk1` span: the span holds the text.
        private mutating func fillSense(_ text: String) {
            if var sense = lastSense, sense.text.isEmpty, sense.examples.isEmpty {
                sense.text = text
                lastSense = sense
            } else {
                startSense(text)
            }
        }

        private mutating func addExample(_ text: String, translation: String?) {
            if currentSenses.isEmpty { startSense("") }
            guard var sense = lastSense else { return }
            sense.examples.append(.init(text: text, translation: translation))
            lastSense = sense
        }

        private mutating func setTranslation(_ translation: String) {
            guard var sense = lastSense, !sense.examples.isEmpty, !translation.isEmpty else { return }
            sense.examples[sense.examples.count - 1].translation = translation
            lastSense = sense
        }
    }
}
