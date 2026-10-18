import Foundation

/// One dictionary's entry for a looked-up term, parsed from its HTML into what the panel renders (D35):
/// a headword with pronunciations, then sections (a part of speech, a phrase, or extra material such as
/// specialized terms) holding numbered senses with examples.
struct DictionaryEntry: Equatable, Sendable, Identifiable {
    struct Example: Equatable, Sendable {
        var text: String
        var translation: String?
    }

    struct Sense: Equatable, Sendable {
        var text: String
        /// Usage or field labels ("British English", "điện ảnh"), shown in italics before the text.
        var labels: [String] = []
        var examples: [Example] = []
        /// A sub-sense of the previous numbered sense (Oxford's "•" senses).
        var isSubsense = false
    }

    struct Section: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// A part of speech (badge), or untitled.
            case main
            /// An idiom or phrasal verb ("to take after").
            case phrase
            /// Specialized terms, encyclopedia notes, origin: only in the expanded view.
            case extra
        }

        var kind: Kind
        var title: String?
        /// Inflections or grammar next to the badge ("took; taken", "plural hellos").
        var note: String?
        var senses: [Sense] = []
        /// The preview cut some senses off, so the ones shown keep their numbers.
        var hasHiddenSenses = false
    }

    let dictionary: String
    var headword: String
    var pronunciations: [String] = []
    var sections: [Section] = []

    var id: String { dictionary + "/" + headword }

    /// "VIETTIEN Anh-Việt (v6.0b1.b5)" → "VIETTIEN Anh-Việt".
    var dictionaryName: String {
        dictionary.replacing(/\s*\((v|ver|version)\s?[\d.]+[^)]*\)\s*$/.ignoresCase(), with: "")
    }

    /// The collapsed view: main and phrase sections, one example per sense, up to `rows` rows (titles,
    /// senses and examples count one each).
    func preview(rows limit: Int) -> DictionaryEntry {
        var rows = 0
        var kept: [Section] = []
        for section in sections where section.kind != .extra {
            guard rows < limit else { break }
            var shown = section
            shown.senses = []
            if section.title != nil { rows += 1 }
            for sense in section.senses {
                guard rows < limit else { break }
                var short = sense
                short.examples = Array(sense.examples.prefix(1))
                shown.senses.append(short)
                rows += 1 + short.examples.count
            }
            shown.hasHiddenSenses = shown.senses.count < section.senses.count
            if !shown.senses.isEmpty { kept.append(shown) }
        }
        var preview = self
        preview.sections = kept
        return preview
    }
}
