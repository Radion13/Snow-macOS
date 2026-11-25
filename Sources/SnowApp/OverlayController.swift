import AppKit
import SpriteKit

final class SnowOverlayWindow: NSWindow {
    var acceptsInteraction = false
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { acceptsInteraction }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

final class SnowSKView: SKView {
    var onEscape: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { (scene as? SnowScene)?.interactionEnabled == true }
    // AppKit owns the gesture from down through up. Forward once to the catch-all
    // scene so decorative SpriteKit nodes cannot interrupt dragging or release.
    override func mouseDown(with event: NSEvent) { (scene as? SnowScene)?.mouseDown(with: event) }
    override func mouseDragged(with event: NSEvent) { (scene as? SnowScene)?.mouseDragged(with: event) }
    override func mouseUp(with event: NSEvent) { (scene as? SnowScene)?.mouseUp(with: event) }
    override func rightMouseDown(with event: NSEvent) { (scene as? SnowScene)?.rightMouseDown(with: event) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

@MainActor
final class OverlayController {
    let displayID: UInt32
    private(set) var screenFrame: CGRect
    let window: SnowOverlayWindow
    let view: SnowSKView
    let scene: SnowScene
    let background = WinterSceneController()
    private var lastState = PauseState()
    private var lastSurfaces: [SnowSurface]?
    private var lastSettings: SnowSettings?
    private var lastLiveIDs: Set<UInt32>?

    init(screen: NSScreen, displayID: UInt32, settings: @escaping () -> SnowSettings, onEscape: @escaping () -> Void) {
        self.displayID = displayID
        screenFrame = screen.frame
        var frame = screen.frame
        // Keep the menu bar reachable even while the rest of this display takes mouse events.
        let topInset = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        frame.size.height -= topInset
        window = SnowOverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenNone]
        if #available(macOS 13, *) { window.collectionBehavior.insert(.canJoinAllApplications) }
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = true
        window.onEscape = onEscape
        view = SnowSKView(frame: CGRect(origin: .zero, size: frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.onEscape = onEscape
        scene = SnowScene(size: frame.size, seed: UInt64(displayID))
        scene.settings = settings
        scene.exitInteraction = onEscape
        window.contentView = view
        view.presentScene(scene)
        window.orderFrontRegardless()
    }

    func updateGeometry(_ reading: GeometryReading, settings: SnowSettings, budget: RenderBudget) {
        scene.budget = budget
        view.preferredFramesPerSecond = budget.framesPerSecond
        let reduceMotion = settings.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        background.configure(kind: SnowAppFeatures.winterScenes ? (settings.scenes[displayID] ?? .none) : .none,
                             frame: screenFrame, reduceMotion: reduceMotion)
        let widgets = SnowAppFeatures.widgetSnow ? reading.widgets : []
        let widgetIDs = Set(widgets.map(\.id))
        var surfaces = SurfaceGeometry.surfaces(windows: reading.windows + widgets, display: window.frame, snowHeight: settings.windowHeight)
        for index in surfaces.indices where widgetIDs.contains(surfaces[index].id) { surfaces[index].kind = .widget }
        scene.decorations.windows = (reading.windows + widgets).map {
            WindowSnapshot(id: $0.id, frame: SnowCoordinates.localRect($0.frame, display: window.frame), eligible: $0.eligible)
        }
        for frame in reading.dockFrames {
            if let dock = SurfaceGeometry.dock(frame: frame, display: window.frame, vertical: settings.verticalDock) { surfaces.append(dock); break }
        }
        guard surfaces != lastSurfaces || settings != lastSettings || reading.liveIDs != lastLiveIDs else { return }
        lastSurfaces = surfaces; lastSettings = settings; lastLiveIDs = reading.liveIDs
        scene.simulation.synchronize(surfaces: surfaces, settings: settings, liveWindowIDs: reading.liveIDs)
        scene.simulation.game.step(delta: 0, surfaces: scene.simulation.surfaces, profiles: scene.simulation.profiles, size: scene.size)
        scene.redrawSurfaces()
    }
    func reconfigure(screen: NSScreen) {
        screenFrame = screen.frame
        var frame = screen.frame
        frame.size.height -= max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true)
        view.frame = CGRect(origin: .zero, size: frame.size); scene.size = frame.size
        lastSurfaces = nil; lastSettings = nil
    }
    func apply(_ state: PauseState) {
        if state != lastState { scene.resetClock() }
        lastState = state
        scene.isRunning = !state.isPaused
        // Paused snow still follows window geometry and responds to Clear. Hidden effects
        // stop the SKView entirely; user pause needs only a low-rate static redraw.
        view.preferredFramesPerSecond = state.isPaused ? 10 : scene.budget.framesPerSecond
        view.isPaused = state.isHidden
        background.apply(state)
        if state.isHidden { window.orderOut(nil) }
        else if !window.isVisible { window.orderFrontRegardless() }
    }
    func setInteraction(_ enabled: Bool, tool: SnowTool) {
        window.acceptsInteraction = enabled
        // A key game window must enter the current Space. Keeping the decorative
        // canJoinAllApplications policy here can leave it logically visible but
        // off the active Space, so WindowServer sends clicks to the app beneath.
        if enabled {
            window.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenNone]
            if #available(macOS 13, *) { window.collectionBehavior.insert(.canJoinAllApplications) }
        }
        // Floating stays above normal windows while leaving menu/Dock levels alone.
        window.level = .floating
        window.ignoresMouseEvents = !enabled
        scene.setInteraction(enabled, tool: tool)
        if enabled { window.orderFrontRegardless(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view) }
        else if window.isKeyWindow { window.resignKey() }
    }
    func clear() { scene.simulation.clear(); scene.redrawSurfaces() }
    func close() {
        window.ignoresMouseEvents = true
        view.isPaused = true
        view.presentScene(nil)
        background.close()
        window.close()
    }
}
