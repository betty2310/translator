import AVFoundation

/// Text to speech for the source and the translation (D13).
@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: trimmed)
        let voices = AVSpeechSynthesisVoice.speechVoices().map(\.language)
        if let language = Self.voiceLanguage(for: languageCode, available: voices) {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// The installed voice language (BCP-47, e.g. `vi-VN`) for a Google code: exact match, then same base
    /// language. Pure, tested.
    nonisolated static func voiceLanguage(for googleCode: String, available: [String]) -> String? {
        let wanted: String
        switch googleCode {
        case "iw": wanted = "he"
        case "jw": wanted = "jv"
        case "fil": wanted = "fil"
        case "zh-CN": wanted = "zh-CN"
        case "zh-TW": wanted = "zh-TW"
        default: wanted = googleCode
        }
        let lower = wanted.lowercased()
        if let exact = available.first(where: { $0.lowercased() == lower }) { return exact }
        let base = lower.split(separator: "-").first.map(String.init) ?? lower
        return available.first { $0.lowercased().split(separator: "-").first.map(String.init) == base }
    }
}
