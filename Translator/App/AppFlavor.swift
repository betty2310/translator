/// Debug builds are the dev flavor (D33): their own bundle id, name, settings, Accessibility grant and hotkey, so they
/// run next to the installed app, and a "d" on the menu bar owl and a DEV tag so they're never mistaken for it.
enum AppFlavor {
    #if DEBUG
    static let isDev = true
    #else
    static let isDev = false
    #endif

    static let name = isDev ? "Translator Dev" : "Translator"
}
