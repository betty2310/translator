import Foundation
import Observation

enum PanelLayout: String, Codable, CaseIterable, Sendable, Identifiable {
    case sideBySide, stacked
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sideBySide: "Side by side"
        case .stacked: "Stacked"
        }
    }
}

/// All settings, including API keys, live in `UserDefaults` (D26). Observable so views update live.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    static let defaultPanelSize = CGSize(width: 780, height: 420)
    static let minimumPanelSize = CGSize(width: 560, height: 300)

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let sourceCode = "sourceLanguageCode"
        static let targetCode = "targetLanguageCode"
        static let recentSources = "recentSourceCodes"
        static let recentTargets = "recentTargetCodes"
        static let engineMode = "engineMode"
        static let googleAPIKey = "googleAPIKey"
        static let googleAPIVersion = "googleAPIVersion"
        static let googleProjectID = "googleProjectID"
        static let deepLAPIKey = "deepLAPIKey"
        static let layout = "panelLayout"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    var sourceCode: String { didSet { defaults.set(sourceCode, forKey: Key.sourceCode) } }
    var targetCode: String { didSet { defaults.set(targetCode, forKey: Key.targetCode) } }
    var recentSourceCodes: [String] { didSet { defaults.set(recentSourceCodes, forKey: Key.recentSources) } }
    var recentTargetCodes: [String] { didSet { defaults.set(recentTargetCodes, forKey: Key.recentTargets) } }
    var engineMode: EngineMode { didSet { defaults.set(engineMode.rawValue, forKey: Key.engineMode) } }
    var googleAPIKey: String { didSet { defaults.set(googleAPIKey, forKey: Key.googleAPIKey) } }
    var googleAPIVersion: GoogleCloudEngine.APIVersion { didSet { defaults.set(googleAPIVersion.rawValue, forKey: Key.googleAPIVersion) } }
    var googleProjectID: String { didSet { defaults.set(googleProjectID, forKey: Key.googleProjectID) } }
    var deepLAPIKey: String { didSet { defaults.set(deepLAPIKey, forKey: Key.deepLAPIKey) } }
    var layout: PanelLayout { didSet { defaults.set(layout.rawValue, forKey: Key.layout) } }
    var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon) } }
    var panelSize: CGSize {
        didSet {
            defaults.set(panelSize.width, forKey: Key.panelWidth)
            defaults.set(panelSize.height, forKey: Key.panelHeight)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sourceCode = defaults.string(forKey: Key.sourceCode) ?? LanguageCatalog.english.code
        targetCode = defaults.string(forKey: Key.targetCode) ?? LanguageCatalog.vietnamese.code
        recentSourceCodes = defaults.stringArray(forKey: Key.recentSources) ?? []
        recentTargetCodes = defaults.stringArray(forKey: Key.recentTargets) ?? []
        engineMode = defaults.string(forKey: Key.engineMode).flatMap(EngineMode.init) ?? .auto
        googleAPIKey = defaults.string(forKey: Key.googleAPIKey) ?? ""
        googleAPIVersion = defaults.string(forKey: Key.googleAPIVersion).flatMap(GoogleCloudEngine.APIVersion.init) ?? .v3
        googleProjectID = defaults.string(forKey: Key.googleProjectID) ?? ""
        deepLAPIKey = defaults.string(forKey: Key.deepLAPIKey) ?? ""
        layout = defaults.string(forKey: Key.layout).flatMap(PanelLayout.init) ?? .sideBySide
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        let width = defaults.double(forKey: Key.panelWidth)
        let height = defaults.double(forKey: Key.panelHeight)
        panelSize = width > 0 && height > 0 ? CGSize(width: width, height: height) : Self.defaultPanelSize
    }

    var source: Language { LanguageCatalog.languageOrPlaceholder(for: sourceCode) }
    var target: Language { LanguageCatalog.languageOrPlaceholder(for: targetCode) }

    var isGoogleConfigured: Bool {
        GoogleCloudEngine.isConfigured(apiKey: googleAPIKey, version: googleAPIVersion, projectID: googleProjectID)
    }

    var isDeepLConfigured: Bool { DeepLEngine.isConfigured(apiKey: deepLAPIKey) }

    func makeGoogleEngine() -> GoogleCloudEngine {
        GoogleCloudEngine(apiKey: googleAPIKey, version: googleAPIVersion, projectID: googleProjectID)
    }

    func makeDeepLEngine() -> DeepLEngine { DeepLEngine(apiKey: deepLAPIKey) }

    var routerConfiguration: EngineRouter.Configuration {
        .init(mode: engineMode, googleConfigured: isGoogleConfigured, deepLConfigured: isDeepLConfigured)
    }
}
