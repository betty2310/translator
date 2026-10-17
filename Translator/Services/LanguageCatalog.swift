import Foundation

/// A language as the picker shows it. `code` is the Google Cloud Translation code (D19); engines map it to
/// their own codes (`DeepLEngine.sourceCode`, `AppleEngine.language`).
struct Language: Hashable, Codable, Sendable, Identifiable {
    let code: String
    let name: String

    var id: String { code }
}

/// Google's language list (https://cloud.google.com/translate/docs/languages, NMT model), sorted by name.
enum LanguageCatalog {
    static let english = Language(code: "en", name: "English")
    static let vietnamese = Language(code: "vi", name: "Vietnamese")

    static func language(for code: String) -> Language? { byCode[code] }

    /// The catalog entry for `code`, or a placeholder so an unknown stored code never breaks the UI.
    static func languageOrPlaceholder(for code: String) -> Language {
        byCode[code] ?? Language(code: code, name: code)
    }

    private static let byCode: [String: Language] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })

    static let all: [Language] = [
        ("ab", "Abkhaz"), ("ace", "Acehnese"), ("ach", "Acholi"), ("af", "Afrikaans"), ("sq", "Albanian"),
        ("alz", "Alur"), ("am", "Amharic"), ("ar", "Arabic"), ("hy", "Armenian"), ("as", "Assamese"),
        ("awa", "Awadhi"), ("ay", "Aymara"), ("az", "Azerbaijani"), ("ban", "Balinese"), ("bm", "Bambara"),
        ("ba", "Bashkir"), ("eu", "Basque"), ("btx", "Batak Karo"), ("bts", "Batak Simalungun"), ("bbc", "Batak Toba"),
        ("be", "Belarusian"), ("bem", "Bemba"), ("bn", "Bengali"), ("bew", "Betawi"), ("bho", "Bhojpuri"),
        ("bik", "Bikol"), ("bs", "Bosnian"), ("br", "Breton"), ("bg", "Bulgarian"), ("bua", "Buryat"),
        ("yue", "Cantonese"), ("ca", "Catalan"), ("ceb", "Cebuano"), ("ny", "Chichewa (Nyanja)"),
        ("zh-CN", "Chinese (Simplified)"), ("zh-TW", "Chinese (Traditional)"), ("cv", "Chuvash"), ("co", "Corsican"),
        ("crh", "Crimean Tatar"), ("hr", "Croatian"), ("cs", "Czech"), ("da", "Danish"), ("din", "Dinka"),
        ("dv", "Divehi"), ("doi", "Dogri"), ("dov", "Dombe"), ("nl", "Dutch"), ("dz", "Dzongkha"),
        ("en", "English"), ("eo", "Esperanto"), ("et", "Estonian"), ("ee", "Ewe"), ("fj", "Fijian"),
        ("fil", "Filipino (Tagalog)"), ("fi", "Finnish"), ("fr", "French"), ("fr-FR", "French (France)"),
        ("fr-CA", "French (Canada)"), ("fy", "Frisian"), ("ff", "Fulfulde"), ("gaa", "Ga"), ("gl", "Galician"),
        ("lg", "Ganda (Luganda)"), ("ka", "Georgian"), ("de", "German"), ("el", "Greek"), ("gn", "Guarani"),
        ("gu", "Gujarati"), ("ht", "Haitian Creole"), ("cnh", "Hakha Chin"), ("ha", "Hausa"), ("haw", "Hawaiian"),
        ("iw", "Hebrew"), ("hil", "Hiligaynon"), ("hi", "Hindi"), ("hmn", "Hmong"), ("hu", "Hungarian"),
        ("hrx", "Hunsrik"), ("is", "Icelandic"), ("ig", "Igbo"), ("ilo", "Iloko"), ("id", "Indonesian"),
        ("ga", "Irish"), ("it", "Italian"), ("ja", "Japanese"), ("jw", "Javanese"), ("kn", "Kannada"),
        ("pam", "Kapampangan"), ("kk", "Kazakh"), ("km", "Khmer"), ("cgg", "Kiga"), ("rw", "Kinyarwanda"),
        ("ktu", "Kituba"), ("gom", "Konkani"), ("ko", "Korean"), ("kri", "Krio"), ("ku", "Kurdish (Kurmanji)"),
        ("ckb", "Kurdish (Sorani)"), ("ky", "Kyrgyz"), ("lo", "Lao"), ("ltg", "Latgalian"), ("la", "Latin"),
        ("lv", "Latvian"), ("lij", "Ligurian"), ("li", "Limburgan"), ("ln", "Lingala"), ("lt", "Lithuanian"),
        ("lmo", "Lombard"), ("luo", "Luo"), ("lb", "Luxembourgish"), ("mk", "Macedonian"), ("mai", "Maithili"),
        ("mak", "Makassar"), ("mg", "Malagasy"), ("ms", "Malay"), ("ms-Arab", "Malay (Jawi)"), ("ml", "Malayalam"),
        ("mt", "Maltese"), ("mi", "Maori"), ("mr", "Marathi"), ("chm", "Meadow Mari"), ("mni-Mtei", "Meiteilon (Manipuri)"),
        ("min", "Minang"), ("lus", "Mizo"), ("mn", "Mongolian"), ("my", "Myanmar (Burmese)"), ("nr", "Ndebele (South)"),
        ("new", "Nepalbhasa (Newari)"), ("ne", "Nepali"), ("nso", "Northern Sotho (Sepedi)"), ("no", "Norwegian"),
        ("nus", "Nuer"), ("oc", "Occitan"), ("or", "Odia (Oriya)"), ("om", "Oromo"), ("pag", "Pangasinan"),
        ("pap", "Papiamento"), ("ps", "Pashto"), ("fa", "Persian"), ("pl", "Polish"), ("pt", "Portuguese"),
        ("pt-PT", "Portuguese (Portugal)"), ("pt-BR", "Portuguese (Brazil)"), ("pa", "Punjabi"),
        ("pa-Arab", "Punjabi (Shahmukhi)"), ("qu", "Quechua"), ("rom", "Romani"), ("ro", "Romanian"), ("rn", "Rundi"),
        ("ru", "Russian"), ("sm", "Samoan"), ("sg", "Sango"), ("sa", "Sanskrit"), ("gd", "Scots Gaelic"),
        ("sr", "Serbian"), ("st", "Sesotho"), ("crs", "Seychellois Creole"), ("shn", "Shan"), ("sn", "Shona"),
        ("scn", "Sicilian"), ("szl", "Silesian"), ("sd", "Sindhi"), ("si", "Sinhala"), ("sk", "Slovak"),
        ("sl", "Slovenian"), ("so", "Somali"), ("es", "Spanish"), ("su", "Sundanese"), ("sw", "Swahili"),
        ("ss", "Swati"), ("sv", "Swedish"), ("tg", "Tajik"), ("ta", "Tamil"), ("tt", "Tatar"), ("te", "Telugu"),
        ("tet", "Tetum"), ("th", "Thai"), ("ti", "Tigrinya"), ("ts", "Tsonga"), ("tn", "Tswana"), ("tr", "Turkish"),
        ("tk", "Turkmen"), ("ak", "Twi (Akan)"), ("uk", "Ukrainian"), ("ur", "Urdu"), ("ug", "Uyghur"),
        ("uz", "Uzbek"), ("vi", "Vietnamese"), ("cy", "Welsh"), ("xh", "Xhosa"), ("yi", "Yiddish"),
        ("yo", "Yoruba"), ("yua", "Yucatec Maya"), ("zu", "Zulu"),
    ]
    .map { Language(code: $0.0, name: $0.1) }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

/// "5 recent languages on top" (D19). Pure list rules, tested.
enum Recents {
    static let limit = 5

    /// `code` moved (or inserted) to the front, capped at `limit`.
    static func push(_ code: String, into recents: [String]) -> [String] {
        Array(([code] + recents.filter { $0 != code }).prefix(limit))
    }
}
