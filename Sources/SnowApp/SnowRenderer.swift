import AppKit
import SpriteKit

final class SnowScene: SKScene {
    let simulation: SnowSimulation
    var settings: () -> SnowSettings = { .init() }
    var budget = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: false)
    var isRunning = true
    var interactionEnabled = false
    var tool: SnowTool = .snowball
    var exitInteraction: (() -> Void)?
    var onGameChanged: (() -> Void)?
    private(set) var inputDowns = 0
    private(set) var inputDrags = 0
    private(set) var inputUps = 0
    private(set) var updateCount = 0
    let decorations = SnowDecorationRenderer()
    private(set) var holidayTree = HolidayTree()
    let treeRenderer = HolidayTreeRenderer()
    private var elapsed: Double = 0
    private var lastMessage: String?
    private var messageUntil: Double = 0
    private let notice = SKLabelNode(fontNamed: "-apple-system")
    private var clock = SimulationClock()
    private var sprites: [SKSpriteNode] = []
    private var snowNodes: [SKShapeNode] = []
    private var lastSurfaceRevision: UInt64 = .max
    private var lastAppearance: SnowAppearance?
    private var lastSurfaceDraw: TimeInterval = 0
    private var lastCursor: CGPoint?
    private let hint = SKLabelNode(fontNamed: "-apple-system")
    // Nonzero alpha gives empty pixels a mouse hit region only during explicit play.
    private let inputBacking = SKSpriteNode(color: NSColor.black.withAlphaComponent(0.01), size: .zero)

    init(size: CGSize, seed: UInt64) {
        simulation = SnowSimulation(size: size, seed: seed)
        super.init(size: size)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        scaleMode = .resizeFill
        inputBacking.name = "interaction.backing"
        inputBacking.anchorPoint = .zero; inputBacking.size = size
        inputBacking.zPosition = -100; inputBacking.isHidden = true
        addChild(inputBacking)
        hint.text = tr("interaction.hint")
        hint.fontSize = 15
        hint.fontColor = .white
        hint.position = CGPoint(x: size.width / 2, y: size.height - 44)
        hint.zPosition = 100
        let backing = SKShapeNode(rectOf: CGSize(width: min(650, size.width - 32), height: 38), cornerRadius: 12)
        backing.fillColor = NSColor.black.withAlphaComponent(0.82)
        backing.strokeColor = .clear
        backing.position = CGPoint(x: 0, y: 5)
        backing.zPosition = -1
        hint.addChild(backing)
        hint.isHidden = true
        addChild(hint)
        addChild(decorations.root)
        treeRenderer.root.zPosition = 2.5
        addChild(treeRenderer.root)
        notice.fontSize = 15; notice.fontColor = .white; notice.zPosition = 100
        notice.position = CGPoint(x: size.width / 2, y: size.height - 92)
        let noticeBacking = SKShapeNode(rectOf: CGSize(width: min(620, size.width - 40), height: 34), cornerRadius: 10)
        noticeBacking.fillColor = NSColor.black.withAlphaComponent(0.88); noticeBacking.strokeColor = .clear
        noticeBacking.position.y = 5; noticeBacking.zPosition = -1; notice.addChild(noticeBacking); notice.isHidden = true
        addChild(notice)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func resetClock() { clock.reset(); lastCursor = nil }
    func growTree() {
        holidayTree.grow(reduceMotion: settings().respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        drawTree()
    }
    func removeTree() { holidayTree.remove(); drawTree() }
    private func drawTree() {
        let value = settings()
        treeRenderer.draw(holidayTree, size: size, time: elapsed, settings: value,
                          reduceMotion: value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                          ground: simulation.profiles[SurfaceGeometry.bottomID])
    }
    func setInteraction(_ enabled: Bool, tool: SnowTool) {
        if !enabled || self.tool != tool { simulation.game.endDrag(throwBall: false) }
        interactionEnabled = enabled; self.tool = tool
        inputBacking.isHidden = !enabled
        hint.isHidden = !enabled
        // SpriteKit can expose a hidden label through accessibility. Clear its
        // text as well, so the inactive overlay does not announce game controls.
        refreshLocalization()
        lastCursor = nil
    }
    func refreshLocalization() {
        hint.text = interactionEnabled ? tr("interaction.hint." + tool.rawValue) : nil
        notice.text = lastMessage.map(tr)
    }
    override func didChangeSize(_ oldSize: CGSize) {
        simulation.size = size
        inputBacking.size = size
        hint.position = CGPoint(x: size.width / 2, y: size.height - 44)
        notice.position = CGPoint(x: size.width / 2, y: size.height - 92)
        drawTree()
    }
    override func update(_ currentTime: TimeInterval) {
        updateCount += 1
        guard isRunning else { clock.reset(); return }
        let value = settings()
        let dt = clock.advance(to: currentTime); elapsed += dt
        simulation.step(delta: dt, settings: value, budget: budget,
                        reduceMotion: value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        holidayTree.step(delta: dt, reduceMotion: value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        drawTree()
        if value.decorativeSweep || interactionEnabled {
            if let window = view?.window {
                let global = NSEvent.mouseLocation
                let point = CGPoint(x: global.x - window.frame.minX, y: global.y - window.frame.minY)
                if CGRect(origin: .zero, size: size).contains(point) {
                    if let lastCursor, hypot(point.x - lastCursor.x, point.y - lastCursor.y) > 1,
                       !interactionEnabled || (tool == .mitten && simulation.game.draggedID == nil) {
                        // Bounded interpolation prevents gaps when the pointer moves quickly.
                        let steps = min(8, max(1, Int(hypot(point.x - lastCursor.x, point.y - lastCursor.y) / 12)))
                        for step in 1...steps {
                            let t = CGFloat(step) / CGFloat(steps)
                            let before = CGFloat(step - 1) / CGFloat(steps)
                            simulation.sweep(at: CGPoint(x: lastCursor.x + (point.x - lastCursor.x) * t,
                                                       y: lastCursor.y + (point.y - lastCursor.y) * t),
                                             from: CGPoint(x: lastCursor.x + (point.x - lastCursor.x) * before,
                                                           y: lastCursor.y + (point.y - lastCursor.y) * before),
                                             tool: .mitten, limit: budget.particleLimit(for: value.weather))
                        }
                    }
                    lastCursor = point
                } else { lastCursor = nil }
            }
        }
        drawParticles()
        decorations.drawGame(simulation.game, surfaces: simulation.surfaces,
                             reduceMotion: value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                             appearance: value.snowAppearance)
        decorations.drawCleaner(simulation.cleaner, settings: value)
        decorations.animateGarland(time: elapsed, settings: value,
                                   reduceMotion: value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if simulation.game.message != lastMessage {
            lastMessage = simulation.game.message
            notice.text = lastMessage.map(tr); messageUntil = elapsed + 3
        }
        notice.isHidden = elapsed > messageUntil || !interactionEnabled
        onGameChanged?()
        if currentTime - lastSurfaceDraw >= 0.1 { drawSurfaces(); lastSurfaceDraw = currentTime }
    }
    func redrawSurfaces() {
        drawSurfaces(force: true); drawParticles()
        drawTree()
        decorations.configureGarland(size: size, settings: settings())
        decorations.drawGame(simulation.game, surfaces: simulation.surfaces,
                             reduceMotion: settings().respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                             appearance: settings().snowAppearance)
        decorations.drawCleaner(simulation.cleaner, settings: settings())
        decorations.animateGarland(time: elapsed, settings: settings(), reduceMotion: settings().respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
    private func drawParticles() {
        let particles = simulation.particles
        let value = settings(), limit = budget.particleLimit(for: settings().weather)
        let reduceMotion = value.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        while sprites.count < min(particles.count, limit) {
            let node = SKSpriteNode(texture: SnowflakeArt.simpleTexture)
            node.name = "snow.particle"
            node.zPosition = 2
            addChild(node); sprites.append(node)
        }
        // Drop excess allocated nodes when quality is reduced, not only live simulation particles.
        while sprites.count > limit { sprites.removeLast().removeFromParent() }
        for (index, node) in sprites.enumerated() {
            node.isHidden = index >= particles.count
            guard index < particles.count else { continue }
            let p = particles[index]
            node.position = CGPoint(x: p.x, y: p.y)
            SnowflakeArt.apply(to: node, particle: p, settings: value, time: elapsed, reduceMotion: reduceMotion)
            node.alpha = p.alpha
        }
    }
    private func drawSurfaces(force: Bool = false) {
        let appearance = settings().snowAppearance
        guard force || lastSurfaceRevision != simulation.surfaceRevision || lastAppearance != appearance else { return }
        lastSurfaceRevision = simulation.surfaceRevision
        lastAppearance = appearance
        var paths: [(CGPath, SnowSurface)] = []
        for surface in simulation.surfaces {
            guard let profile = simulation.profiles[surface.id] else { continue }
            for span in surface.visible where span.width > 0 {
                paths.append((SnowContour.path(surface: surface, profile: profile, span: span), surface))
            }
        }
        while snowNodes.count < paths.count {
            let node = SKShapeNode()
            node.name = "snow.surface"
            node.fillColor = NSColor(white: 0.98, alpha: 0.97)
            node.strokeColor = .clear
            node.isAntialiased = true
            node.zPosition = 3
            addChild(node); snowNodes.append(node)
        }
        while snowNodes.count > paths.count { snowNodes.removeLast().removeFromParent() }
        for (index, entry) in paths.enumerated() {
            snowNodes[index].path = entry.0
            SnowMaterialArt.apply(to: snowNodes[index], surface: entry.1, appearance: appearance)
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard interactionEnabled else { return }
        inputDowns += 1
        let point = event.location(in: self)
        switch tool {
        case .snowball: simulation.beginRoll(at: point, time: event.timestamp)
        case .delete: simulation.game.remove(at: point, surfaces: simulation.surfaces)
        case .mitten: simulation.beginHandful(at: point, time: event.timestamp)
        case .shovel: simulation.sweep(at: point, tool: tool, limit: budget.particleLimit)
        }
        redrawSurfaces()
        onGameChanged?()
    }
    override func mouseDragged(with event: NSEvent) {
        guard interactionEnabled else { return }
        inputDrags += 1
        if tool == .snowball || (tool == .mitten && simulation.game.draggedID != nil) {
            simulation.roll(to: event.location(in: self), time: event.timestamp); redrawSurfaces()
        } else if tool == .shovel { simulation.sweep(at: event.location(in: self), tool: tool, limit: budget.particleLimit) }
    }
    override func mouseUp(with event: NSEvent) {
        guard interactionEnabled else { return }
        inputUps += 1
        if tool == .snowball || tool == .mitten { simulation.endRoll(at: event.location(in: self), time: event.timestamp) }
        redrawSurfaces(); onGameChanged?()
    }
    override func rightMouseDown(with event: NSEvent) {
        if interactionEnabled { simulation.game.remove(at: event.location(in: self), surfaces: simulation.surfaces); redrawSurfaces() }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { exitInteraction?() }
        else { super.keyDown(with: event) }
    }
}
