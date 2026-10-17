import Foundation

/// DeepL API (D31). https://developers.deepl.com/docs/api-reference/translate
///
/// `POST {host}/v2/translate` with `Authorization: DeepL-Auth-Key <key>` and a JSON body. Free keys end in
/// `:fx` and must use `api-free.deepl.com`; Pro keys use `api.deepl.com`.
/// Language codes: https://developers.deepl.com/docs/getting-started/supported-languages
struct DeepLEngine: TranslationEngine {
    let id = EngineID.deepL
    var apiKey: String
    var session: URLSession = .shared

    static let freeHost = URL(string: "https://api-free.deepl.com/v2/translate")!
    static let proHost = URL(string: "https://api.deepl.com/v2/translate")!

    static func isConfigured(apiKey: String) -> Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isConfigured: Bool { Self.isConfigured(apiKey: apiKey) }

    func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        guard isConfigured else { throw TranslationError.notConfigured(.deepL) }
        let request = try Self.makeRequest(text: text, source: source.code, target: target.code, apiKey: apiKey)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranslationError.from(error, engine: .deepL)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.parseResponse(data, status: status)
    }

    // MARK: Pure request/response code (tested with canned JSON)

    static func endpoint(for apiKey: String) -> URL {
        apiKey.trimmingCharacters(in: .whitespaces).hasSuffix(":fx") ? freeHost : proHost
    }

    /// DeepL source code for a Google code, or nil when DeepL can't read that language.
    static func sourceCode(for googleCode: String) -> String? {
        let code = base(for: googleCode)
        return sourceLanguages.contains(code) ? code : nil
    }

    /// DeepL target code for a Google code, or nil when DeepL can't write that language. Regional Google codes
    /// map to DeepL's regional variants; plain English and Portuguese pick DeepL's US / Brazilian variants,
    /// which is what Google's `en` / `pt` produce.
    static func targetCode(for googleCode: String) -> String? {
        let code: String
        switch googleCode {
        case "en": code = "EN-US"
        case "pt": code = "PT-BR"
        case "zh-CN": code = "ZH-HANS"
        case "zh-TW": code = "ZH-HANT"
        case "fr-FR": code = "FR-FR"
        case "fr-CA": code = "FR-CA"
        case "pt-PT": code = "PT-PT"
        case "pt-BR": code = "PT-BR"
        default: code = base(for: googleCode)
        }
        return targetLanguages.contains(code) ? code : nil
    }

    private static func base(for googleCode: String) -> String {
        switch googleCode {
        case "iw": "HE"
        case "jw": "JV"
        case "fil": "TL"
        case "no": "NB"
        case "zh-CN", "zh-TW": "ZH"
        case "fr-FR", "fr-CA": "FR"
        case "pt-PT", "pt-BR": "PT"
        default: googleCode.uppercased()
        }
    }

    static func makeRequest(text: String, source: String, target: String, apiKey: String) throws -> URLRequest {
        guard let sourceLang = sourceCode(for: source), let targetLang = targetCode(for: target) else {
            throw TranslationError.unsupportedPair(.deepL)
        }
        var request = URLRequest(url: endpoint(for: apiKey))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["text": [text], "source_lang": sourceLang, "target_lang": targetLang]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(_ data: Data, status: Int) throws -> String {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(status) else {
            let message: String
            switch status {
            case 403: message = "Invalid API key."
            case 456: message = "Character quota exceeded for this billing period."
            case 429: message = "Too many requests."
            default: message = (json?["message"] as? String) ?? String(decoding: data, as: UTF8.self)
            }
            throw TranslationError.http(.deepL, status: status, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let translations = json?["translations"] as? [[String: Any]],
              let text = translations.first?["text"] as? String else {
            throw TranslationError.invalidResponse(.deepL)
        }
        return text
    }

    /// Regional variants are target-only on DeepL.
    static let targetOnly: Set<String> = ["ZH-HANS", "ZH-HANT", "EN-US", "EN-GB", "FR-CA", "FR-FR", "DE-DE", "DE-CH",
                                          "PT-BR", "PT-PT", "ES-ES", "ES-419"]

    static let targetLanguages: Set<String> = [
        "ACE", "AF", "SQ", "AR", "AN", "HY", "AS", "AY", "AZ", "BA", "EU", "BE", "BN", "BHO", "BS", "BR", "BG", "MY",
        "YUE", "CA", "CEB", "ZH-HANS", "ZH-HANT", "ZH", "HR", "CS", "DA", "PRS", "NL", "EN", "EN-US", "EN-GB", "EO",
        "ET", "FI", "FR", "FR-CA", "FR-FR", "GL", "KA", "DE", "DE-DE", "DE-CH", "EL", "GN", "GU", "HT", "HA", "HE",
        "HI", "HU", "IS", "IG", "ID", "GA", "IT", "JA", "JV", "PAM", "KK", "GOM", "KO", "KMR", "CKB", "KY", "LA",
        "LV", "LN", "LT", "LMO", "LB", "MK", "MAI", "MG", "MS", "ML", "MT", "MI", "MR", "MN", "NE", "NB", "OC", "OM",
        "PAG", "PS", "FA", "PL", "PT-BR", "PT-PT", "PT", "PA", "QU", "RO", "RU", "SA", "SR", "ST", "SCN", "SK", "SL",
        "ES", "ES-ES", "ES-419", "SU", "SW", "SV", "TL", "TG", "TA", "TT", "TE", "TH", "TS", "TN", "TR", "TK", "UK",
        "UR", "UZ", "VI", "CY", "WO", "XH", "YI", "ZU",
    ]

    static let sourceLanguages: Set<String> = targetLanguages.subtracting(targetOnly)
}
