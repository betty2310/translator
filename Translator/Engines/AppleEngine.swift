import Foundation
import Translation

/// Apple's on-device Translation framework (D3). https://developer.apple.com/documentation/translation
///
/// `TranslationSession(installedSource:target:)` (macOS 26+) only uses language packs that are already
/// downloaded; it never downloads. Downloads happen in Settings → Engines through the SwiftUI
/// `.translationTask` + `prepareTranslation()` path (`AppleLanguagePackView`).
struct AppleEngine: TranslationEngine {
    let id = EngineID.apple

    func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        let from = Self.language(for: source.code)
        let to = Self.language(for: target.code)
        switch await LanguageAvailability().status(from: from, to: to) {
        case .installed: break
        case .supported: throw TranslationError.notInstalled
        case .unsupported: throw TranslationError.unsupportedPair(.apple)
        @unknown default: throw TranslationError.unsupportedPair(.apple)
        }
        // A fresh session per request: `TranslationSession` isn't Sendable, and creating one for installed
        // models is cheap.
        let session = TranslationSession(installedSource: from, target: to)
        do {
            return try await session.translate(text).targetText
        } catch {
            if error is CancellationError { throw TranslationError.cancelled }
            if TranslationError.notInstalledMatches(error) { throw TranslationError.notInstalled }
            throw TranslationError.http(.apple, status: 0, message: error.localizedDescription)
        }
    }

    // MARK: Pure language mapping (tested)

    /// Apple's language identifier for a Google code. Apple keys Chinese by script and Portuguese by region.
    static func language(for googleCode: String) -> Locale.Language {
        let identifier: String
        switch googleCode {
        case "zh-CN": identifier = "zh-Hans"
        case "zh-TW": identifier = "zh-Hant"
        case "iw": identifier = "he"
        case "jw": identifier = "jv"
        case "pt": identifier = "pt-BR"
        case "fr-FR": identifier = "fr"
        case "fr-CA": identifier = "fr"
        default: identifier = googleCode
        }
        return Locale.Language(identifier: identifier)
    }

    /// Whether `language` is in Apple's supported list, comparing language code and (when given) script, so
    /// `en` matches Apple's `en-US`/`en-GB` and `zh-Hans` matches `zh-Hans-CN` but not `zh-Hant-TW`.
    static func isSupported(_ language: Locale.Language, in supported: [Locale.Language]) -> Bool {
        guard let code = language.languageCode else { return false }
        return supported.contains { candidate in
            guard candidate.languageCode == code else { return false }
            guard let script = language.script else { return true }
            return candidate.script == script || candidate.maximalIdentifier.contains(script.identifier)
        }
    }

    /// Google codes from `catalog` that Apple can translate (marked in the picker, D19).
    static func supportedCodes(in catalog: [Language], supported: [Locale.Language]) -> Set<String> {
        Set(catalog.filter { isSupported(language(for: $0.code), in: supported) }.map(\.code))
    }
}

private extension TranslationError {
    static func notInstalledMatches(_ error: any Error) -> Bool {
        if #available(macOS 26.0, *), case Translation.TranslationError.notInstalled = error { return true }
        return false
    }
}
