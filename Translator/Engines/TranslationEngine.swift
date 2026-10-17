import Foundation

/// A translation backend. Engines are pluggable (D3, D30–D32): views never talk to one directly, they go
/// through `EngineRouter`.
protocol TranslationEngine: Sendable {
    var id: EngineID { get }
    func translate(_ text: String, from source: Language, to target: Language) async throws -> String
}

enum EngineID: String, Codable, CaseIterable, Sendable {
    case google, deepL, apple

    var displayName: String {
        switch self {
        case .google: "Google"
        case .deepL: "DeepL"
        case .apple: "Apple"
        }
    }

    /// Cloud engines get the Auto-mode timeout (D3); on-device translation doesn't.
    var isCloud: Bool { self != .apple }
}

/// The user's engine setting (D3, D32).
enum EngineMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case auto, google, deepL, apple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .google: "Google"
        case .deepL: "DeepL"
        case .apple: "Apple"
        }
    }
}

struct TranslationResult: Equatable, Sendable {
    let text: String
    let engine: EngineID
}

enum TranslationError: Error, Equatable, Sendable {
    /// The engine needs an API key (or project) that isn't set (D18).
    case notConfigured(EngineID)
    /// The engine can't translate between these two languages.
    case unsupportedPair(EngineID)
    /// The Apple language pack for this pair isn't downloaded (Settings → Engines).
    case notInstalled
    case offline
    case timeout(EngineID)
    case http(EngineID, status: Int, message: String)
    case invalidResponse(EngineID)
    case cancelled
}

extension TranslationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured(let engine): "\(engine.displayName) isn't set up. Add its API key in Settings → Engines."
        case .unsupportedPair(let engine): "\(engine.displayName) doesn't support this language pair."
        case .notInstalled: "Apple's language pack for this pair isn't downloaded. Settings → Engines → Download."
        case .offline: "You're offline."
        case .timeout(let engine): "\(engine.displayName) didn't answer in time."
        case .http(let engine, let status, let message): "\(engine.displayName) error \(status): \(message)"
        case .invalidResponse(let engine): "\(engine.displayName) returned an unexpected response."
        case .cancelled: "Cancelled."
        }
    }
}

extension TranslationError {
    /// Maps transport errors to the engine-independent cases.
    static func from(_ error: any Error, engine: EngineID) -> TranslationError {
        if let error = error as? TranslationError { return error }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled: return .cancelled
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .internationalRoamingOff, .dataNotAllowed:
                return .offline
            case .timedOut: return .timeout(engine)
            default: break
            }
        }
        return .http(engine, status: 0, message: error.localizedDescription)
    }
}
