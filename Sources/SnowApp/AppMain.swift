import AppKit

@main
enum SnowMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppCoordinator()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case russian = "ru"

    // Endonyms make both choices recognizable in either interface language.
    var name: String { self == .english ? "English" : "Русский" }
    var locale: Locale { Locale(identifier: rawValue) }
}

/// Explicit app language, independent of macOS's preferred-language ordering.
/// Bundles are cached; switching language never rebuilds the snow simulation.
final class AppLocalization {
    static let preferenceKey = "snow.language.v1"
    static let shared = AppLocalization()

    private let defaults: UserDefaults
    private let bundles: [AppLanguage: Bundle]
    private let fallback: Bundle
    private let lock = NSLock()
    private var selected: AppLanguage

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        selected = AppLanguage(rawValue: defaults.string(forKey: Self.preferenceKey) ?? "") ?? .english
        var localized: [AppLanguage: Bundle] = [:]
        for language in AppLanguage.allCases {
            if let path = bundle.path(forResource: language.rawValue, ofType: "lproj"), let resource = Bundle(path: path) {
                localized[language] = resource
            }
        }
        bundles = localized
        fallback = localized[.english] ?? bundle
    }

    var language: AppLanguage {
        lock.lock(); defer { lock.unlock() }
        return selected
    }

    func select(_ language: AppLanguage) {
        lock.lock(); selected = language; lock.unlock()
        defaults.set(language.rawValue, forKey: Self.preferenceKey)
    }

    func text(_ key: String) -> String {
        let resource = bundles[language] ?? fallback
        let english = fallback.localizedString(forKey: key, value: key, table: nil)
        return resource.localizedString(forKey: key, value: english, table: nil)
    }
}

func tr(_ key: String) -> String { AppLocalization.shared.text(key) }
