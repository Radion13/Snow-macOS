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

func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }
