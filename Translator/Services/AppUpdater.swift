import Foundation
import Observation
import Sparkle

/// In-app updates via Sparkle (D1, D21). The feed is `appcast.xml` on the latest GitHub Release, written by
/// the release workflow; Sparkle verifies each update with the EdDSA key in Info.plist.
@MainActor
@Observable
final class AppUpdater: NSObject {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    /// `start: false` gives an inert updater (previews, tests).
    init(start: Bool = true) {
        super.init()
        // Unit tests run inside the app (TEST_HOST): never check for updates there.
        guard start, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        // Sparkle skips its scheduled check on the very first launch; check now so every launch checks.
        controller?.updater.checkForUpdatesInBackground()
    }

    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticallyChecks: Bool {
        get { access(keyPath: \.automaticallyChecks); return controller?.updater.automaticallyChecksForUpdates ?? false }
        set { withMutation(keyPath: \.automaticallyChecks) { controller?.updater.automaticallyChecksForUpdates = newValue } }
    }

    /// Shows the update window (or "You're up to date").
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// "0.1.0" from Info.plist (`CFBundleShortVersionString`, set from the release tag).
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

extension AppUpdater: SPUUpdaterDelegate {
    #if DEBUG
    /// The dev flavor (D33) only checks when asked: an update would replace it with the release build.
    nonisolated func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        if updateCheck == .updatesInBackground { throw CocoaError(.userCancelled) }
    }
    #endif
}
