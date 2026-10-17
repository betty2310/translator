import Foundation

/// Picks engines for the user's mode and applies the Auto fallback chain (D3, D32):
/// Google → DeepL → Apple, skipping cloud engines without a key, moving on after an error, being offline, or a
/// 1.5 s timeout. The plan and the fallback rule are pure functions, tested.
struct EngineRouter: Sendable {
    struct Configuration: Equatable, Sendable {
        var mode: EngineMode
        var googleConfigured: Bool
        var deepLConfigured: Bool
    }

    var engines: [EngineID: any TranslationEngine]
    var cloudTimeout: Duration = .milliseconds(1500)

    /// Engines to try, in order. Explicit modes always use their engine, even unconfigured, so the panel can
    /// show the "Set up" error (D18).
    static func plan(for configuration: Configuration) -> [EngineID] {
        switch configuration.mode {
        case .google: return [.google]
        case .deepL: return [.deepL]
        case .apple: return [.apple]
        case .auto:
            var plan: [EngineID] = []
            if configuration.googleConfigured { plan.append(.google) }
            if configuration.deepLConfigured { plan.append(.deepL) }
            plan.append(.apple)
            return plan
        }
    }

    /// Auto moves to the next engine after any failure except the user's own cancellation (D3).
    static func shouldFallBack(after error: any Error) -> Bool {
        if error is CancellationError { return false }
        if case TranslationError.cancelled = error { return false }
        return true
    }

    func translate(_ text: String, from source: Language, to target: Language,
                   configuration: Configuration) async throws -> TranslationResult {
        let plan = Self.plan(for: configuration)
        var lastError: any Error = TranslationError.notConfigured(.google)
        for (index, id) in plan.enumerated() {
            guard let engine = engines[id] else { continue }
            do {
                let translated: String
                if id.isCloud, plan.count > 1 {
                    translated = try await Self.withTimeout(cloudTimeout, engine: id) {
                        try await engine.translate(text, from: source, to: target)
                    }
                } else {
                    translated = try await engine.translate(text, from: source, to: target)
                }
                return TranslationResult(text: translated, engine: id)
            } catch {
                try Task.checkCancellation()
                lastError = error
                let isLast = index == plan.count - 1
                if isLast || !Self.shouldFallBack(after: error) { throw error }
            }
        }
        throw lastError
    }

    static func withTimeout<T: Sendable>(_ limit: Duration, engine: EngineID,
                                         _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw TranslationError.timeout(engine)
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw TranslationError.timeout(engine) }
            return first
        }
    }
}
