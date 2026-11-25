import AppKit
import SwiftUI

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = SettingsStore()
    private let geometry = WindowGeometryProvider()
    private var statusItem: NSStatusItem!
    private var overlays: [UInt32: OverlayController] = [:]
    private var settingsWindow: NSWindow?
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var pause = PauseState()
    private var fullscreenIDs: Set<UInt32> = []
    private var windowProfiles: [UInt32: SnowProfile] = [:]
    private var interactionDisplay: UInt32?
    private var tool: SnowTool {
        get { settings.selectedTool }
        set { settings.selectedTool = newValue }
    }
    private var inputLab: NativeInputLab?
    private var materialLab: SnowMaterialLab?
    private var previousApp: NSRunningApplication?
    private var spaceTransition = false
    private var smokeMode: Bool { CommandLine.arguments.contains("--smoke-test") }
    private var resourceMode: Bool { CommandLine.arguments.contains("--resource-check") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices normally routes a second launch to the first instance; also guard direct execution.
        let own = Bundle.main.bundleIdentifier ?? "local.snow.app"
        if NSRunningApplication.runningApplications(withBundleIdentifier: own).contains(where: { $0.processIdentifier != getpid() }) {
            NSApp.terminate(nil); return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: tr("app.name"))
        statusItem.button?.toolTip = tr("app.name")
        statusItem.button?.setAccessibilityLabel(tr("app.name"))
        installApplicationMenu()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        settings.onChange = { [weak self] in self?.settingsChanged() }
        settings.onAssetsChanged = { [weak self] in self?.overlays.values.forEach { $0.scene.decorations.reloadAssets() } }
        settings.onClean = { [weak self] in self?.runCleaner() }
        settings.onPlay = { [weak self] in self?.beginInteraction() }
        settings.onToolChanged = { [weak self] in
            guard let self, let id = self.interactionDisplay else { return }
            self.overlays[id]?.setInteraction(true, tool: self.tool)
        }
        settings.onGrowTree = { [weak self] in self?.growTree() }
        settings.onRemoveTree = { [weak self] in self?.removeTree() }
        installObservers()
        updatePower()
        rebuildDisplays()
        if CommandLine.arguments.contains("--input-lab") {
            setReason(.hidden, true)
            inputLab = NativeInputLab()
            inputLab?.show()
        }
        else if CommandLine.arguments.contains("--material-lab") {
            setReason(.hidden, true)
            materialLab = SnowMaterialLab(); materialLab?.show()
        }
        else if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
            do { try FeatureChecks.renderPreviews(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); print("Rendered original scene previews") }
            catch { fputs("Preview rendering failed: \(error.localizedDescription)\n", stderr) }
            NSApp.terminate(nil)
        }
        else if CommandLine.arguments.contains("--feature-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let checks = FeatureChecks.run()
                if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]),
                   let json = String(data: data, encoding: .utf8) { print(json) }
                NSApp.terminate(nil)
            }
        }
        else if CommandLine.arguments.contains("--show-settings") { openSettings() }
        else if smokeMode { runSmokeTest() }
        else if resourceMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 35) { [weak self] in self?.setReason(.hidden, true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 65) { NSApp.terminate(nil) }
        }
        else if !UserDefaults.standard.bool(forKey: "snow.didExplainMenu") {
            UserDefaults.standard.set(true, forKey: "snow.didExplainMenu")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showWelcome() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        for (center, token) in observers { center.removeObserver(token) }
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidResignActive(_ notification: Notification) { exitInteraction(restore: false) }
    func applicationDidBecomeActive(_ notification: Notification) { settings.refreshLoginStatus() }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        observers.append((center, token))
    }
    private func installObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.rebuildDisplays() }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in self?.setReason(.sleep, true) }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in self?.setReason(.sleep, false) }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in self?.setReason(.displaySleep, true) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in self?.setReason(.displaySleep, false) }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in self?.setReason(.sessionInactive, true) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in self?.setReason(.sessionInactive, false) }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.spaceChanged() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in self?.refreshGeometry() }
        observe(.default, .NSProcessInfoPowerStateDidChange) { [weak self] in self?.updatePower() }
        observe(.default, ProcessInfo.thermalStateDidChangeNotification) { [weak self] in self?.updatePower() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification) { [weak self] in self?.settingsChanged() }
    }
    private func installApplicationMenu() {
        let root = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: tr("app.name"))
        let preferences = add(appMenu, "menu.settings", #selector(openSettings))
        preferences.keyEquivalent = ","
        appMenu.addItem(.separator())
        let quit = add(appMenu, "menu.quit", #selector(quitApp))
        quit.keyEquivalent = "q"
        appItem.submenu = appMenu; root.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: tr("menu.window"))
        windowMenu.addItem(withTitle: tr("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu; root.addItem(windowItem)
        NSApp.mainMenu = root
        NSApp.windowsMenu = windowMenu
    }
    private var budget: RenderBudget {
        let info = ProcessInfo.processInfo
        return .resolve(quality: settings.value.quality, lowPower: info.isLowPowerModeEnabled,
                        thermallyLimited: info.thermalState == .serious || info.thermalState == .critical,
                        reduceMotion: settings.value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
    private func updatePower() { setReason(.systemRestriction, ProcessInfo.processInfo.thermalState == .critical) }
    private func setReason(_ reason: PauseReason, _ active: Bool) {
        pause.set(reason, active: active)
        if active { exitInteraction() }
        refreshGeometry()
        applyState()
    }
    private func settingsChanged() {
        let wanted = Set(NSScreen.screens.compactMap { screen -> UInt32? in
            let id = displayID(screen)
            return settings.value.allDisplays || settings.value.displayIDs.contains(id) ? id : nil
        })
        if wanted != Set(overlays.keys) { rebuildDisplays() }
        else {
            refreshGeometry(); applyState()
            overlays.values.forEach { $0.scene.redrawSurfaces() }
        }
    }
    private func displayID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    private func rebuildDisplays() {
        exitInteraction()
        let previous = overlays
        var next: [UInt32: OverlayController] = [:]
        settings.displayList = NSScreen.screens.map { (displayID($0), $0.localizedName) }
        for screen in NSScreen.screens {
            let id = displayID(screen)
            guard settings.value.allDisplays || settings.value.displayIDs.contains(id) else { continue }
            if let existing = previous[id] { existing.reconfigure(screen: screen); next[id] = existing; continue }
            next[id] = OverlayController(screen: screen, displayID: id,
                                             settings: { [weak self] in self?.settings.value ?? .init() },
                                             onEscape: { [weak self] in self?.exitInteraction() })
        }
        for (id, old) in previous where next[id] == nil { old.close() }
        overlays = next; fullscreenIDs.formIntersection(Set(next.keys))
        refreshGeometry()
        applyState()
    }
    private func spaceChanged() {
        exitInteraction()
        spaceTransition = true
        applyState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.spaceTransition = false
            self.refreshGeometry()
            self.applyState()
        }
    }
    private func refreshGeometry() {
        guard !pause.isHidden, !spaceTransition else { applyState(); return }
        let ids = Set(overlays.values.map { UInt32($0.window.windowNumber) })
        let reading = geometry.read(excluding: ids)
        reconcileWindowState(reading)
        let geometryMessage = reading.available ? tr("geometry.available") : tr("geometry.unavailable")
        if settings.windowGeometryMessage != geometryMessage { settings.windowGeometryMessage = geometryMessage }
        if settings.windowsAvailable != reading.available { settings.windowsAvailable = reading.available }
        let visibleDock = reading.dockFrames.contains { dock in NSScreen.screens.contains { SurfaceGeometry.dock(frame: dock, display: $0.frame, vertical: settings.value.verticalDock) != nil } }
        let dockMessage = tr(visibleDock ? "dock.available" : "dock.unavailable")
        let widgetMessage = tr(reading.widgets.isEmpty ? "widgets.unavailable" : "widgets.available")
        if settings.dockMessage != dockMessage { settings.dockMessage = dockMessage }
        if settings.widgetMessage != widgetMessage { settings.widgetMessage = widgetMessage }
        var nextFullscreen: Set<UInt32> = []
        for (id, overlay) in overlays {
            // Conservative geometry heuristic: no attempt to classify video or games.
            if reading.windows.contains(where: { $0.eligible && SurfaceGeometry.isFullscreen($0.frame, on: overlay.screenFrame) }) {
                nextFullscreen.insert(id)
            }
            overlay.updateGeometry(reading, settings: settings.value, budget: budget)
        }
        if nextFullscreen != fullscreenIDs { exitInteraction() }
        fullscreenIDs = nextFullscreen
        applyState()
    }
    private func reconcileWindowState(_ reading: GeometryReading) {
        let candidates = Array(reading.windows.filter(\.eligible).prefix(96)) + (SnowAppFeatures.widgetSnow ? reading.widgets : [])
        let frames = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.frame) })
        if let live = reading.liveIDs { windowProfiles = windowProfiles.filter { live.contains($0.key) } }
        let ordered = overlays.sorted { $0.key < $1.key }
        for (_, overlay) in ordered {
            let sim = overlay.scene.simulation
            for surface in sim.surfaces where surface.kind == .window || surface.kind == .widget {
                guard let frame = frames[surface.id], let local = sim.profiles[surface.id] else { continue }
                var shared = windowProfiles[surface.id] ?? local
                if shared.width != frame.width || shared.maximum != settings.value.windowHeight {
                    shared.resize(to: frame.width, maximum: settings.value.windowHeight)
                }
                let spans = surface.visible.map { SnowInterval($0.lower, $0.upper < local.width ? $0.upper - 0.001 : $0.upper) }
                shared.merge(from: local, visible: spans)
                windowProfiles[surface.id] = shared
            }
        }
        if windowProfiles.count > 128 {
            windowProfiles = windowProfiles.filter { frames[$0.key] != nil }
            windowProfiles = Dictionary(uniqueKeysWithValues: windowProfiles.sorted { $0.key < $1.key }.prefix(128).map { ($0.key, $0.value) })
        }
        for (sourceID, source) in ordered {
            let surfaceIDs = Set(source.scene.simulation.game.balls.compactMap(\.surfaceID))
            for id in surfaceIDs {
                guard let frame = frames[id] else { continue }
                for (targetID, target) in ordered where targetID != sourceID {
                    _ = source.scene.simulation.game.transfer(on: id, to: target.scene.simulation.game) { ball in
                        let global = SnowSurface(id: id, frame: frame, visible: []).point(at: ball.localX, height: ball.anchorHeight)
                        return ordered.first(where: { $0.value.screenFrame.contains(global) })?.key == targetID
                    }
                }
            }
        }
        for (_, overlay) in ordered {
            var changed = false
            for (id, profile) in windowProfiles where frames[id]?.intersects(overlay.screenFrame) == true {
                if overlay.scene.simulation.adopt(profile, for: id) { changed = true }
            }
            if changed { overlay.scene.redrawSurfaces() }
        }
    }
    private func applyState() {
        let paused = pause.isPaused || overlays.isEmpty || fullscreenIDs.count == overlays.count
        if settings.effectPaused != paused { settings.effectPaused = paused }
        let hasTree = overlays.values.contains { $0.scene.holidayTree.isVisible }
        if settings.treeShown != hasTree { settings.treeShown = hasTree }
        for (id, overlay) in overlays {
            var state = pause
            state.set(.fullscreen, active: fullscreenIDs.contains(id))
            if spaceTransition { state.set(.systemRestriction, active: true) }
            overlay.apply(state)
        }
        if pause.isHidden || spaceTransition || overlays.isEmpty { installTimer(interval: nil) }
        else { installTimer(interval: fullscreenIDs.count == overlays.count ? 0.5 : 0.1) }
        let message: String
        if interactionDisplay != nil { message = tr("status.interaction") }
        else if let reason = PauseReason.allCases.first(where: { pause.reasons.contains($0) }) { message = tr("pause." + reason.rawValue) }
        else if overlays.isEmpty { message = tr("status.noDisplays") }
        else if fullscreenIDs.count == overlays.count { message = tr("pause.fullscreen") }
        else { message = tr("status.running") }
        if settings.statusMessage != message { settings.statusMessage = message }
    }
    private func installTimer(interval: TimeInterval?) {
        guard interval != (timer == nil ? nil : timerInterval) else { return }
        timer?.invalidate(); timer = nil
        guard let interval else { return }
        timerInterval = interval
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshGeometry() }
        }
        next.tolerance = interval * 0.1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
    private func beginInteraction() {
        guard pause.allowsInteraction else { return }
        let pointer = NSEvent.mouseLocation
        guard let (id, overlay) = overlays.first(where: { $0.value.screenFrame.contains(pointer) && !fullscreenIDs.contains($0.key) }) else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        interactionDisplay = id
        NSApp.activate(ignoringOtherApps: true)
        overlay.setInteraction(true, tool: tool)
        applyState()
    }
    private func exitInteraction(restore: Bool = true) {
        guard interactionDisplay != nil else { return }
        interactionDisplay = nil
        overlays.values.forEach { $0.setInteraction(false, tool: tool) }
        if restore, NSApp.isActive { previousApp?.activate(options: []) }
        previousApp = nil
        applyState()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: settings.statusMessage, action: nil, keyEquivalent: "")
        status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        add(menu, pause.reasons.contains(.user) ? "menu.resume" : "menu.pause", #selector(togglePause))
        add(menu, pause.reasons.contains(.hidden) ? "menu.show" : "menu.hide", #selector(toggleHidden))
        let weather = NSMenuItem(title: tr("section.snow"), action: nil, keyEquivalent: "")
        let weatherMenu = NSMenu()
        for mode in SnowWeather.allCases {
            let item = add(weatherMenu, "weather." + mode.rawValue, #selector(selectWeather(_:)))
            item.representedObject = mode.rawValue; item.state = settings.value.weather == mode ? .on : .off
        }
        weather.submenu = weatherMenu; menu.addItem(weather)
        let interact = add(menu, interactionDisplay == nil ? "menu.interact" : "menu.exitInteraction", #selector(toggleInteraction))
        interact.isEnabled = pause.allowsInteraction && fullscreenIDs.count < overlays.count
        let tools = NSMenuItem(title: tr("menu.tool"), action: nil, keyEquivalent: "")
        let toolMenu = NSMenu()
        for value in SnowTool.allCases {
            let item = add(toolMenu, "tool." + value.rawValue, #selector(selectTool(_:)))
            item.representedObject = value.rawValue; item.state = tool == value ? .on : .off
        }
        tools.submenu = toolMenu; menu.addItem(tools)
        add(menu, "menu.clear", #selector(clearSnow))
        let cleaner = add(menu, "menu.runCleaner", #selector(runCleaner))
        cleaner.isEnabled = !settings.effectPaused
        let tree = add(menu, "tree.grow", #selector(toggleTree))
        tree.state = settings.treeShown ? .on : .off
        tree.isEnabled = !settings.effectPaused || settings.treeShown
        let lights = NSMenuItem(title: tr("section.garlands"), action: nil, keyEquivalent: "")
        let lightMenu = NSMenu()
        for style in GarlandStyle.allCases {
            let item = add(lightMenu, "garland.style." + style.rawValue, #selector(selectGarlandStyle(_:)))
            item.representedObject = style.rawValue; item.state = settings.value.garlandStyle == style ? .on : .off
        }
        lightMenu.addItem(.separator())
        for mode in GarlandMode.allCases {
            let item = add(lightMenu, "garland." + mode.rawValue, #selector(selectGarland(_:)))
            item.representedObject = mode.rawValue; item.state = settings.value.garland == mode ? .on : .off
        }
        lights.submenu = lightMenu; menu.addItem(lights)
        menu.addItem(.separator())
        let settingsItem = add(menu, "menu.settings", #selector(openSettings))
        settingsItem.keyEquivalent = ","
        let quit = add(menu, "menu.quit", #selector(quitApp))
        quit.keyEquivalent = "q"
    }
    @discardableResult private func add(_ menu: NSMenu, _ key: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: tr(key), action: action, keyEquivalent: "")
        item.target = self; menu.addItem(item); return item
    }
    @objc private func togglePause() { setReason(.user, !pause.reasons.contains(.user)) }
    @objc private func toggleHidden() { setReason(.hidden, !pause.reasons.contains(.hidden)) }
    @objc private func toggleInteraction() { if interactionDisplay == nil { beginInteraction() } else { exitInteraction() } }
    @objc private func selectWeather(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let weather = SnowWeather(rawValue: raw) { settings.value.weather = weather }
    }
    @objc private func selectTool(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let value = SnowTool(rawValue: raw) {
            tool = value
            if let id = interactionDisplay { overlays[id]?.setInteraction(true, tool: tool) }
            else if pause.allowsInteraction { beginInteraction() }
        }
    }
    @objc private func clearSnow() { windowProfiles.removeAll(); overlays.values.forEach { $0.clear() } }
    @objc private func runCleaner() {
        guard !settings.effectPaused else { return }
        for (id, overlay) in overlays where !fullscreenIDs.contains(id) {
            _ = overlay.scene.simulation.cleaner.start(character: settings.value.cleaner)
        }
    }
    @objc private func toggleTree() { if settings.treeShown { removeTree() } else { growTree() } }
    @objc private func growTree() {
        guard !settings.effectPaused else { return }
        let available = overlays.values.filter { !fullscreenIDs.contains($0.displayID) && $0.scene.isRunning }
        let point = NSEvent.mouseLocation
        guard let target = available.first(where: { $0.screenFrame.contains(point) }) ?? available.sorted(by: { $0.displayID < $1.displayID }).first else { return }
        for overlay in overlays.values where overlay !== target { overlay.scene.removeTree() }
        target.scene.growTree()
        settings.treeShown = true
    }
    @objc private func removeTree() {
        overlays.values.forEach { $0.scene.removeTree() }
        settings.treeShown = false
    }
    @objc private func selectGarland(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = GarlandMode(rawValue: raw) { settings.value.garland = mode }
    }
    @objc private func selectGarlandStyle(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let style = GarlandStyle(rawValue: raw) {
            settings.value.garlandStyle = style
            if settings.value.garland == .off { settings.value.garland = .steady }
        }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func openSettings() {
        exitInteraction(restore: false)
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(store: settings))
            let window = NSWindow(contentViewController: controller)
            window.title = tr("settings.title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settings.refreshLoginStatus()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = tr("welcome.title")
        alert.informativeText = tr("welcome.body")
        alert.addButton(withTitle: tr("welcome.ok"))
        alert.addButton(withTitle: tr("menu.settings"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { openSettings() }
    }

    /// Opt-in lifecycle diagnostics. Reports only our own state, never foreign window titles.
    private func runSmokeTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            var checks: [String: Bool] = [:]
            checks["overlaysCreated"] = !self.overlays.isEmpty
            checks["clickThrough"] = self.overlays.values.allSatisfy { $0.window.ignoresMouseEvents && !$0.window.canBecomeKey }
            checks["transparent"] = self.overlays.values.allSatisfy { !$0.window.isOpaque && $0.view.allowsTransparency }
            checks["menuCreated"] = self.statusItem.button != nil
            let reading = self.geometry.read(excluding: Set(self.overlays.values.map { UInt32($0.window.windowNumber) }))
            checks["geometryAPIAvailable"] = reading.available
            checks["foreignWindowBoundsAvailable"] = reading.windows.contains(where: \.eligible)
            self.setReason(.user, true)
            checks["pauseStopsSimulationAndPassesInput"] = self.overlays.values.allSatisfy { !$0.scene.isRunning && $0.window.isVisible && $0.window.ignoresMouseEvents }
            self.setReason(.sleep, true); self.setReason(.sleep, false)
            checks["userPauseSurvivesWake"] = self.pause.reasons.contains(.user)
            self.setReason(.hidden, true)
            checks["hideStopsRendererAndTimer"] = self.timer == nil && self.overlays.values.allSatisfy { !$0.window.isVisible && $0.view.isPaused }
            self.setReason(.hidden, false); self.setReason(.user, false)
            checks["resume"] = self.overlays.values.allSatisfy { $0.window.isVisible && !$0.view.isPaused }
            self.growTree()
            checks["growingTreeDoesNotCaptureInput"] = self.settings.treeShown && self.overlays.values.filter { $0.scene.holidayTree.isVisible }.count == 1 && self.overlays.values.allSatisfy { $0.window.ignoresMouseEvents && !$0.scene.interactionEnabled }
            self.removeTree()
            checks["removeTreeUpdatesSettingsAndScene"] = !self.settings.treeShown && self.overlays.values.allSatisfy { !$0.scene.holidayTree.isVisible }
            self.beginInteraction()
            checks["interactionExplicit"] = self.interactionDisplay != nil && self.overlays.values.contains { !$0.window.ignoresMouseEvents }
            // App activation and WindowServer compositing are asynchronous,
            // especially under Rosetta. Wait for a real hit region, without
            // changing focus or retrying activation to manufacture a pass.
            let inputDeadline = ProcessInfo.processInfo.systemUptime + 1.5
            @MainActor func finishInputCheck() {
                if let overlay = self.overlays.values.first(where: { $0.window.acceptsInteraction }),
                   NSWindow.windowNumber(at: CGPoint(x: overlay.window.frame.midX, y: overlay.window.frame.midY), belowWindowWithWindowNumber: 0) != overlay.window.windowNumber,
                   ProcessInfo.processInfo.systemUptime < inputDeadline {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finishInputCheck() }
                    return
                }
                checks["gameRemainsActiveUntilEscape"] = self.interactionDisplay != nil
                if let overlay = self.overlays.values.first(where: { $0.window.acceptsInteraction }) {
                    let point = CGPoint(x: overlay.window.frame.midX, y: overlay.window.frame.midY)
                    checks["gameReceivesInputAtEmptyPixels"] = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0) == overlay.window.windowNumber
                    if checks["gameReceivesInputAtEmptyPixels"] != true {
                        fputs("Input map: own window \(overlay.window.windowNumber), hit \(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)), visible \(overlay.window.isVisible), active \(NSApp.isActive), on active Space \(overlay.window.isOnActiveSpace), occluded \(!overlay.window.occlusionState.contains(.visible)), level \(overlay.window.level.rawValue), paused \(overlay.view.isPaused), frame \(overlay.window.frame)\n", stderr)
                    }
                    overlay.window.cancelOperation(nil)
                } else { checks["gameReceivesInputAtEmptyPixels"] = false }
                checks["escapeHandlerReleasesInput"] = self.interactionDisplay == nil && self.overlays.values.allSatisfy { $0.window.ignoresMouseEvents && $0.scene.childNode(withName: "interaction.backing")?.isHidden == true }
                if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]),
                   let json = String(data: data, encoding: .utf8) { print(json) }
                NSApp.terminate(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finishInputCheck() }
        }
    }
}
