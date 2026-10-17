import Foundation

/// Google Cloud Translation (D2, D30).
///
/// - v3 (Advanced): `POST https://translation.googleapis.com/v3/projects/{project}:translateText`
///   https://cloud.google.com/translate/docs/reference/rest/v3/projects/translateText
/// - v2 (Basic):    `POST https://translation.googleapis.com/language/translate/v2`
///   https://cloud.google.com/translate/docs/reference/rest/v2/translate
///
/// The API key goes in the `x-goog-api-key` header for both (never in the URL, so it stays out of logs).
/// Note: Google's authentication page (https://cloud.google.com/translate/docs/authentication) says only the
/// Basic API supports API keys; Settings offers v2 if v3 rejects the key (D30).
struct GoogleCloudEngine: TranslationEngine {
    enum APIVersion: String, Codable, CaseIterable, Sendable, Identifiable {
        case v3, v2
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .v3: "v3 (Advanced)"
            case .v2: "v2 (Basic)"
            }
        }
    }

    let id = EngineID.google
    var apiKey: String
    var version: APIVersion
    /// Google Cloud project ID or number; only v3 needs it (`parent=projects/…`).
    var projectID: String
    var session: URLSession = .shared

    static let v3Base = URL(string: "https://translation.googleapis.com/v3/")!
    static let v2Endpoint = URL(string: "https://translation.googleapis.com/language/translate/v2")!

    static func isConfigured(apiKey: String, version: APIVersion, projectID: String) -> Bool {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return false }
        return version == .v2 || !projectID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isConfigured: Bool { Self.isConfigured(apiKey: apiKey, version: version, projectID: projectID) }

    func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        guard isConfigured else { throw TranslationError.notConfigured(.google) }
        let request = try Self.makeRequest(text: text, source: source.code, target: target.code,
                                           apiKey: apiKey, version: version, projectID: projectID)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranslationError.from(error, engine: .google)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.parseResponse(data, status: status, version: version)
    }

    // MARK: Pure request/response code (tested with canned JSON)

    static func makeRequest(text: String, source: String, target: String, apiKey: String,
                            version: APIVersion, projectID: String) throws -> URLRequest {
        let url: URL
        let body: [String: Any]
        switch version {
        case .v3:
            let project = projectID.trimmingCharacters(in: .whitespaces)
            guard !project.isEmpty else { throw TranslationError.notConfigured(.google) }
            url = v3Base.appending(path: "projects/\(project):translateText")
            body = ["contents": [text], "sourceLanguageCode": source, "targetLanguageCode": target,
                    "mimeType": "text/plain"]
        case .v2:
            url = v2Endpoint
            body = ["q": [text], "source": source, "target": target, "format": "text"]
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey.trimmingCharacters(in: .whitespaces), forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(_ data: Data, status: Int, version: APIVersion) throws -> String {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(status) else {
            let error = json?["error"] as? [String: Any]
            let message = (error?["message"] as? String) ?? String(decoding: data, as: UTF8.self)
            throw TranslationError.http(.google, status: status, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let translations: [[String: Any]]?
        switch version {
        case .v3: translations = json?["translations"] as? [[String: Any]]
        case .v2: translations = (json?["data"] as? [String: Any])?["translations"] as? [[String: Any]]
        }
        guard let text = translations?.first?["translatedText"] as? String else {
            throw TranslationError.invalidResponse(.google)
        }
        // v2 HTML-escapes even with format=text in some responses (e.g. "&#39;"); v3 doesn't for text/plain.
        return version == .v2 ? text.decodingHTMLEntities() : text
    }
}

extension String {
    /// Decodes the few entities Google's v2 API emits (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&#NN;`).
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }
        var result = replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        // Numeric entities like &#8217;
        while let range = result.range(of: #"&#(\d+);"#, options: .regularExpression) {
            let digits = result[range].dropFirst(2).dropLast()
            let replacement = Int(digits).flatMap(UnicodeScalar.init).map { String(Character($0)) } ?? ""
            result.replaceSubrange(range, with: replacement)
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
