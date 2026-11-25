import AppKit
import Combine
import ServiceManagement

/// Temporarily hidden product features. Keep their implementation and saved
/// preferences so one flag can restore both the UI and runtime behavior.
enum SnowAppFeatures {
    static let snowflakePreviews = false
    static let bladeImages = false
    static let winterScenes = false
    static let widgetSnow = false
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case snow, wind, accumulation, play, cleaner, garlands, scenes, displays, performance, general
    var id: String { rawValue }
    static var visibleCases: [Self] { allCases.filter { $0 != .scenes || SnowAppFeatures.winterScenes } }
    var symbol: String {
        switch self {
        case .snow: return "snowflake"
        case .wind: return "wind"
        case .accumulation: return "square.stack.3d.up"
        case .play: return "hand.draw"
        case .cleaner: return "sparkles" // SettingsView supplies the original broom artwork.
        case .garlands: return "lightbulb"
        case .scenes: return "house"
        case .displays: return "display"
        case .performance: return "speedometer"
        case .general: return "gearshape"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var value: SnowSettings {
        didSet {
            var safe = value
            safe.sanitize()
            if safe != value { value = safe; return }
            if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: Self.key) }
            onChange?()
        }
    }
    @Published var loginEnabled = false
    @Published var loginMessage = ""
    @Published var windowGeometryMessageKey = "geometry.checking"
    var windowGeometryMessage: String { tr(windowGeometryMessageKey) }
    @Published var windowsAvailable = true
    @Published var displayList: [(id: UInt32, name: String)] = []
    @Published var statusMessageKey = "status.running"
    var statusMessage: String { tr(statusMessageKey) }
    @Published private(set) var language = AppLocalization.shared.language
    @Published var selectedPane: SettingsPane? = .snow
    var activePane: SettingsPane {
        guard let selectedPane, SettingsPane.visibleCases.contains(selectedPane) else { return .snow }
        return selectedPane
    }
    @Published var dockMessageKey = "dock.checking"
    var dockMessage: String { tr(dockMessageKey) }
    @Published var widgetMessageKey = "widgets.checking"
    var widgetMessage: String { tr(widgetMessageKey) }
    @Published var effectPaused = false
    @Published var treeShown = false
    @Published var selectedTool: SnowTool = .snowball { didSet { onToolChanged?() } }
    let importer = ImageImporter()
    var onAssetsChanged: (() -> Void)?
    var onClean: (() -> Void)?
    var onPlay: (() -> Void)?
    var onToolChanged: (() -> Void)?
    var onGrowTree: (() -> Void)?
    var onRemoveTree: (() -> Void)?
    var onChange: (() -> Void)?
    var onLanguageChanged: (() -> Void)?
    private let defaults: UserDefaults
    static let key = "snow.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        value = SnowSettings.load(defaults.data(forKey: Self.key))
        refreshLoginStatus()
        importer.onCommit = { [weak self] _ in
            guard let self else { return }
            self.value.useBladeImage = true
            self.onAssetsChanged?()
        }
    }
    func reset() { value = SnowSettings() }
    func selectLanguage(_ language: AppLanguage) {
        AppLocalization.shared.select(language)
        guard language != self.language else { return }
        self.language = language
        refreshLoginStatus()
        onLanguageChanged?()
    }
    func refreshLoginStatus() {
        guard #available(macOS 13, *) else {
            loginEnabled = LegacyLoginItem.isEnabled
            loginMessage = tr(loginEnabled ? "login.enabled" : "login.disabled")
            return
        }
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        switch status {
        case .enabled: loginMessage = tr("login.enabled")
        case .requiresApproval: loginMessage = tr("login.approval")
        case .notRegistered: loginMessage = tr("login.disabled")
        case .notFound: loginMessage = tr("login.notfound")
        @unknown default: loginMessage = tr("login.unknown")
        }
    }
    func setLoginEnabled(_ enabled: Bool) {
        do {
            if #available(macOS 13, *) {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } else { try LegacyLoginItem.setEnabled(enabled) }
            refreshLoginStatus()
        } catch {
            refreshLoginStatus()
            loginMessage = tr("login.error") + " " + error.localizedDescription
        }
    }
    func openLoginSettings() {
        if #available(macOS 13, *) { SMAppService.openSystemSettingsLoginItems() }
        else if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.users") { NSWorkspace.shared.open(url) }
    }
}

enum LegacyLoginItem {
    private static let label = "local.snow.login"
    private static var file: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/" + label + ".plist") }
    private static var service: String { "gui/\(getuid())/\(label)" }
    private static func run(_ args: [String]) throws -> Int32 {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl"); process.arguments = args
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit(); return process.terminationStatus
    }
    private static var isRegistered: Bool { (try? run(["print", service])) == 0 }
    static var isEnabled: Bool {
        guard FileManager.default.fileExists(atPath: file.path), isRegistered else { return false }
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print-disabled", "gui/\(getuid())"]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        let pattern = "\"local\\.snow\\.login\"\\s*=>\\s*true"
        return process.terminationStatus == 0 && text.range(of: pattern, options: .regularExpression) == nil
    }
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executable = Bundle.main.executableURL else { throw CocoaError(.fileNoSuchFile) }
            let data = try PropertyListSerialization.data(fromPropertyList: ["Label": label, "ProgramArguments": [executable.path], "RunAtLoad": true], format: .xml, options: 0)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            guard try run(["enable", service]) == 0 else { throw CocoaError(.fileWriteNoPermission) }
            if !isRegistered, try run(["bootstrap", "gui/\(getuid())", file.path]) != 0 {
                try? FileManager.default.removeItem(at: file); throw CocoaError(.fileWriteNoPermission)
            }
        } else {
            // Disabling the job does not terminate an app currently launched by that job.
            guard try run(["disable", service]) == 0 else { throw CocoaError(.fileWriteNoPermission) }
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
    }
}
