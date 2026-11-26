import AppKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers

/// Opt-in native input fixture using the exact production NSView and SnowScene.
/// It exposes only this fixture's game state, never input from other applications.
@MainActor
final class NativeInputLab: NSObject {
    private let window: NSWindow
    let scene = SnowScene(size: CGSize(width: 960, height: 520), seed: 123)
    private let status = NSTextField(labelWithString: "")
    private let view = SnowSKView(frame: CGRect(x: 0, y: 0, width: 960, height: 520))
    override init() {
        window = NSWindow(contentRect: CGRect(x: 180, y: 180, width: 960, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Проверка мыши — Снег"; window.isReleasedWhenClosed = false; window.level = .floating
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
        status.frame = CGRect(x: 18, y: 551, width: 924, height: 38); status.maximumNumberOfLines = 2
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular); content.addSubview(status)
        let fill = NSButton(title: "Добавить снег", target: self, action: #selector(fillSnow))
        fill.frame = CGRect(x: 18, y: 522, width: 150, height: 28); content.addSubview(fill)
        let clear = NSButton(title: "Очистить", target: self, action: #selector(clearGame))
        clear.frame = CGRect(x: 180, y: 522, width: 120, height: 28); content.addSubview(clear)
        let tools = NSPopUpButton(frame: CGRect(x: 320, y: 522, width: 240, height: 28))
        tools.addItems(withTitles: SnowTool.visibleCases.map { tr("tool." + $0.rawValue) })
        tools.selectItem(at: SnowTool.visibleCases.firstIndex(of: .snowball) ?? 0)
        tools.target = self; tools.action = #selector(changeTool(_:)); content.addSubview(tools)
        content.addSubview(view); window.contentView = content
        view.allowsTransparency = false
        scene.backgroundColor = SnowArt.color(0x183344)
        scene.settings = { var s = SnowSettings(); s.decorativeSweep = false; return s }
        scene.simulation.synchronize(surfaces: [], settings: scene.settings(), liveWindowIDs: [])
        scene.onGameChanged = { [weak self] in self?.refreshStatus() }
        scene.exitInteraction = { [weak self] in self?.scene.setInteraction(false, tool: .snowball); self?.refreshStatus() }
        view.onEscape = scene.exitInteraction
        view.preferredFramesPerSecond = 30; view.presentScene(scene)
        scene.setInteraction(true, tool: .snowball)
        fillSnow()
    }
    func show() { window.center(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view) }
    @objc private func fillSnow() {
        for x in stride(from: CGFloat(0), through: 960, by: 8) { scene.simulation.depositSnow(on: SurfaceGeometry.bottomID, at: x, amount: 96) }
        scene.redrawSurfaces(); refreshStatus()
    }
    @objc private func clearGame() { scene.simulation.clear(); scene.redrawSurfaces(); refreshStatus() }
    @objc private func changeTool(_ sender: NSPopUpButton) {
        guard SnowTool.visibleCases.indices.contains(sender.indexOfSelectedItem) else { return }
        scene.setInteraction(true, tool: SnowTool.visibleCases[sender.indexOfSelectedItem]); refreshStatus()
    }
    private func refreshStatus() {
        let balls = scene.simulation.game.balls
        let poses = balls.map { "\($0.id):r\(Int($0.radius))@(\(Int($0.position.x)),\(Int($0.position.y)))" }.joined(separator: " ")
        let impulse = scene.simulation.game.lastReleaseVelocity
        let text = "Ввод \(scene.inputDowns)/\(scene.inputDrags)/\(scene.inputUps) · Шары \(balls.count) · Пятна \(scene.simulation.game.impacts.count) · Горсти \(balls.filter(\.isLooseSnow).count) · Игра \(scene.interactionEnabled) · Бросок \(Int(impulse.dx)),\(Int(impulse.dy))\n\(poses)"
        if status.stringValue != text { status.stringValue = text; status.setAccessibilityValue(text) }
    }
}

/// Opt-in controlled comparison, with the production scene at 30 Hz. Preferences
/// belong to the fixture; no user setting is written by this benchmark.
@MainActor
final class SnowMaterialLab {
    private let scene = SnowScene(size: CGSize(width: 1180, height: 700), seed: 123)
    private let view = SKView(frame: CGRect(x: 0, y: 0, width: 1180, height: 700))
    private let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 1180, height: 700),
                                  styleMask: [.titled], backing: .buffered, defer: false)
    private var preferences = SnowSettings()
    private var results: [[String: Any]] = []
    private var firstFrame = 0
    private var started: TimeInterval = 0
    init() {
        preferences.snowAppearance = .simple; preferences.decorativeSweep = false
        preferences.quality = .economical; preferences.respectReduceMotion = false
        scene.settings = { [weak self] in self?.preferences ?? .init() }
        scene.backgroundColor = SnowArt.color(0x183344)
        var surfaces: [SnowSurface] = []
        for index in 0..<9 {
            let frame = CGRect(x: 15 + (index % 3) * 390, y: 210 + (index / 3) * 160, width: 370, height: 115)
            let surface = SnowSurface(id: UInt32(900 + index), frame: frame, visible: [.init(0, 370)])
            surfaces.append(surface)
            SnowArt.rect(frame, color: SnowArt.color(0x293D4B), radius: surface.cornerRadius, in: scene).zPosition = -1
        }
        scene.simulation.synchronize(surfaces: surfaces, settings: preferences, liveWindowIDs: Set(surfaces.map(\.id)))
        for surface in scene.simulation.surfaces {
            for x in stride(from: CGFloat(0), through: surface.length, by: 4) { scene.simulation.depositSnow(on: surface.id, at: x, amount: 100) }
        }
        var balls: [Snowball] = []
        for column in 0..<3 {
            var top: CGFloat = 48
            for (level, radius) in [CGFloat(36), 25, 17].enumerated() {
                let id = UInt64(960_000 + column * 3 + level)
                var ball = Snowball(id: id, radius: radius, position: CGPoint(x: CGFloat(230 + column * 360), y: top + radius))
                ball.surfaceID = SurfaceGeometry.bottomID; ball.localX = ball.position.x; ball.anchorHeight = top + radius
                ball.supportID = level == 0 ? nil : id - 1; balls.append(ball); top += radius * 2
            }
        }
        let source = SnowGame(balls: balls)
        _ = source.transfer(on: SurfaceGeometry.bottomID, to: scene.simulation.game, matching: { _ in true })
        scene.redrawSurfaces()
        window.isReleasedWhenClosed = false; window.contentView = view
        view.preferredFramesPerSecond = 30; view.presentScene(scene)
    }
    func show() {
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        runPhase(0)
    }
    private func runPhase(_ phase: Int) {
        let appearance: SnowAppearance = phase == 1 ? .textured : .simple
        preferences.snowAppearance = appearance; scene.redrawSurfaces()
        window.title = "Сравнение нагрузки · " + tr("snow.appearance." + appearance.rawValue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
            firstFrame = scene.updateCount; started = ProcessInfo.processInfo.systemUptime
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) { [self] in
            let seconds = ProcessInfo.processInfo.systemUptime - started
            results.append(["phase": phase, "appearance": appearance.rawValue,
                            "update_fps": Double(scene.updateCount - firstFrame) / seconds])
            if phase < 2 { runPhase(phase + 1) }
            else {
                if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]),
                   let text = String(data: data, encoding: .utf8) { print(text) }
                window.orderOut(nil); NSApp.terminate(nil)
            }
        }
    }
}

@MainActor
enum FeatureChecks {
    private static func snowmanFixture() -> (SnowGame, SnowSurface, [UInt32: SnowProfile]) {
        let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: 480, height: 300), visible: [.init(0, 480)], isBottom: true)
        var profile = SnowProfile(width: 480, maximum: 48)
        for x in stride(from: CGFloat(0), through: 480, by: 8) { profile.deposit(at: x, amount: 96) }
        var balls: [Snowball] = []; var top: CGFloat = 48
        for (index, radius) in [CGFloat(36), 25, 17].enumerated() {
            let id = UInt64(800_000 + index)
            var ball = Snowball(id: id, radius: radius, position: CGPoint(x: 240, y: top + radius))
            ball.surfaceID = floor.id; ball.localX = 240; ball.anchorHeight = top + radius
            ball.supportID = index == 0 ? nil : id - 1; balls.append(ball); top += radius * 2
        }
        return (SnowGame(balls: balls, variantCycle: SnowmanVariantCycle(start: SnowmanVariant.classicBucket.rawValue)), floor, [floor.id: profile])
    }
    static func renderPreviews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for kind in [WinterScene.cabin, .porch] {
            let size = CGSize(width: 1280, height: 800)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = WinterIllustration(size: size, kind: kind)
            view.presentScene(scene)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent(kind.rawValue + ".png"), options: .atomic)
            view.presentScene(nil)
        }
        var previews: [(GarlandStyle, NSImage)] = []
        for style in GarlandStyle.allCases {
            let size = CGSize(width: 1400, height: 110)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = SKScene(size: size)
            SnowArt.rect(CGRect(origin: .zero, size: size), color: SnowArt.color(0x0C1117), in: scene)
            let garland = ScreenGarlandRenderer(); var settings = SnowSettings(); settings.garland = .steady; settings.garlandStyle = style
            settings.garlandBrightness = 1
            garland.configure(size: size, settings: settings); garland.animate(time: 0, settings: settings, reduceMotion: true)
            garland.root.zPosition = 1; scene.addChild(garland.root); view.presentScene(scene)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            let image = texture.cgImage()
            try ImportedAssets.png(image).write(to: directory.appendingPathComponent("garland-" + style.rawValue + ".png"), options: .atomic)
            previews.append((style, NSImage(cgImage: image, size: size))); view.presentScene(nil)
        }
        let sheet = NSImage(size: CGSize(width: 1400, height: 420), flipped: false) { rect in
            SnowArt.color(0x0C1117).setFill(); rect.fill()
            for (index, entry) in previews.enumerated() {
                let y = CGFloat(2 - index) * 140
                entry.1.draw(in: CGRect(x: 0, y: y + 28, width: 1400, height: 110))
                (tr("garland.style." + entry.0.rawValue) as NSString).draw(at: CGPoint(x: 20, y: y + 5), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.white])
            }
            return true
        }
        if let image = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try ImportedAssets.png(image).write(to: directory.appendingPathComponent("garlands.png"), options: .atomic)
        }
        let (game, floor, snow) = snowmanFixture()
        var profiles = snow
        for cleared in [false, true] {
            if cleared {
                profiles[floor.id]?.clear()
                for _ in 0..<180 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size) }
            }
            let view = SKView(frame: CGRect(origin: .zero, size: floor.frame.size))
            let scene = SKScene(size: floor.frame.size)
            SnowArt.rect(floor.frame, color: SnowArt.color(0x183344), in: scene)
            if !cleared { SnowArt.rect(CGRect(x: 0, y: 0, width: 480, height: 48), color: .white, in: scene) }
            let renderer = SnowDecorationRenderer(); renderer.drawGame(game, surfaces: [floor]); scene.addChild(renderer.root)
            view.presentScene(scene)
            guard let texture = view.texture(from: scene, crop: floor.frame) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent(cleared ? "snowman-after.png" : "snowman-before.png"), options: .atomic)
            view.presentScene(nil)
        }
        try HolidayTreeRenderer.vectorSVG().write(to: directory.appendingPathComponent("tree-vector.svg"), atomically: true, encoding: .utf8)
        guard let treeImage = HolidayTreeRenderer.vectorPreview() else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(treeImage).write(to: directory.appendingPathComponent("tree-vector.png"), options: .atomic)
        for (name, steps) in [("trees-sprout", 12), ("trees-growing", 40), ("trees", 90)] {
            let size = CGSize(width: 1280, height: 300)
            let (view, scene, renderer, ground) = treePreview(size: size)
            var tree = HolidayTree(seed: 2026); tree.grow(reduceMotion: false)
            for _ in 0..<steps { tree.step(delta: 1.0 / 60, reduceMotion: false) }
            var settings = SnowSettings(); settings.garlandBrightness = 1
            renderer.draw(tree, size: size, time: 1, settings: settings, reduceMotion: false, ground: ground)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
            view.presentScene(nil)
        }
        var layoutTree = HolidayTree(seed: 2026)
        var seenLayouts: Set<[CGFloat]> = []
        for _ in 0..<120 {
            let size = CGSize(width: 1280, height: 300)
            layoutTree.grow(reduceMotion: true)
            guard seenLayouts.insert(layoutTree.appearances(in: size).map(\.position.x)).inserted else { continue }
            let layout = seenLayouts.count
            let (view, scene, renderer, ground) = treePreview(size: size)
            renderer.draw(layoutTree, size: size, time: 1, settings: SnowSettings(), reduceMotion: true, ground: ground)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("trees-layout-\(layout).png"), options: .atomic)
            view.presentScene(nil)
            if seenLayouts.count == HolidayTree.layoutCount { break }
        }
        guard seenLayouts.count == HolidayTree.layoutCount else { throw ImportFailure.invalidImage }
        try renderTreeAnimation(to: directory)
        try renderSnowPreview(to: directory)
        try renderCleaners(to: directory)
        try renderGlassImpacts(to: directory)
        try renderWindowCorners(to: directory)
        try renderSnowAppearances(to: directory)
        try renderSnowmanDetails(to: directory)
        try renderEdgePush(to: directory)
        try renderSnowflakes(to: directory)
    }
    private static func renderSnowflakes(to directory: URL) throws {
        let size = CGSize(width: 1280, height: 720)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); view.ignoresSiblingOrder = true
        let scene = SKScene(size: size); scene.backgroundColor = SnowArt.color(0x142B3D)
        func label(_ text: String, at point: CGPoint, font: CGFloat = 22) {
            let node = SKLabelNode(fontNamed: "HelveticaNeue-Medium"); node.text = text; node.fontSize = font
            node.horizontalAlignmentMode = .left; node.position = point; scene.addChild(node)
        }
        label("Узорные снежинки · 8 форм", at: CGPoint(x: 40, y: 666), font: 28)
        func sample(_ style: SnowflakeStyle, scale: Double, variant: Int, at point: CGPoint) {
            var settings = SnowSettings(); settings.snowflakeStyle = style; settings.snowflakeSize = scale
            let particle = SnowParticle(x: point.x, y: point.y, speed: 0, drift: 0, radius: 3, alpha: 1, life: 120, scattered: false,
                                        flakeSeed: UInt32(variant) << 16)
            let node = SKSpriteNode(); SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 0, reduceMotion: true)
            node.position = point; scene.addChild(node)
        }
        for index in 0..<SnowflakeArt.variantCount {
            sample(.patterned, scale: 3, variant: index, at: CGPoint(x: 160 + (index % 4) * 310, y: 552 - (index / 4) * 156))
        }
        label("Размер снежинок · простые и узорные", at: CGPoint(x: 40, y: 248))
        for (index, scale) in [0.5, 1.0, 2.0, 3.0].enumerated() {
            let x = CGFloat(160 + index * 310)
            sample(.simple, scale: scale, variant: 0, at: CGPoint(x: x - 35, y: 146))
            sample(.patterned, scale: scale, variant: 0, at: CGPoint(x: x + 35, y: 146))
            label("\(Int(scale * 100))%", at: CGPoint(x: x - 28, y: 64), font: 18)
        }
        view.presentScene(scene)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snowflakes.png"), options: .atomic)
        view.presentScene(nil)

        let field = SnowScene(size: CGSize(width: 1280, height: 640), seed: 123)
        var settings = SnowSettings(); settings.snowflakeStyle = .patterned; settings.weather = .light
        settings.accumulateAtBottom = false; settings.accumulateOnWindows = false; settings.decorativeSweep = false
        field.settings = { settings }; field.isRunning = false; field.backgroundColor = SnowArt.color(0x142B3D)
        field.simulation.synchronize(surfaces: [], settings: settings, liveWindowIDs: [])
        for _ in 0..<900 { field.simulation.step(delta: 1.0 / 30, settings: settings, budget: field.budget) }
        field.redrawSurfaces()
        let fieldView = SKView(frame: CGRect(origin: .zero, size: field.size)); fieldView.ignoresSiblingOrder = true; fieldView.presentScene(field)
        guard let fieldTexture = fieldView.texture(from: field, crop: CGRect(origin: .zero, size: field.size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(fieldTexture.cgImage()).write(to: directory.appendingPathComponent("snowflakes-patterned.png"), options: .atomic)
        fieldView.presentScene(nil)
    }
    private static func edgePushFixture() -> (SnowScene, SnowSurface, SnowSettings) {
        let size = CGSize(width: 800, height: 600), scene = SnowScene(size: CGSize(width: 800, height: 600), seed: 123)
        var settings = SnowSettings(); settings.decorativeSweep = false
        scene.settings = { settings }; scene.isRunning = false; scene.backgroundColor = SnowArt.color(0x183344)
        let source = SnowSurface(id: 810, frame: CGRect(x: 140, y: 240, width: 500, height: 180), visible: [.init(0, 500)])
        let lower = SnowSurface(id: 811, frame: CGRect(x: 0, y: 70, width: size.width, height: 140), visible: [.init(0, 140), .init(640, 800)])
        for surface in [lower, source] {
            let body = SnowArt.rect(surface.frame, color: SnowArt.color(0x293D4B), radius: surface.cornerRadius, in: scene)
            body.zPosition = -10
        }
        scene.simulation.synchronize(surfaces: [source, lower], settings: settings, liveWindowIDs: [source.id, lower.id])
        for x in stride(from: CGFloat(0), through: source.length, by: 4) { scene.simulation.depositSnow(on: source.id, at: x, amount: 100) }
        scene.redrawSurfaces()
        return (scene, source, settings)
    }
    private static func renderEdgePush(to directory: URL) throws {
        let (scene, source, settings) = edgePushFixture()
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size)); view.ignoresSiblingOrder = true; view.presentScene(scene)
        defer { view.presentScene(nil) }
        let pointer = SnowArt.polygon([.zero, .init(x: 0, y: -20), .init(x: 6, y: -14), .init(x: 11, y: -26),
                                       .init(x: 15, y: -23), .init(x: 9, y: -12), .init(x: 20, y: -12)], color: SnowArt.color(0x78D7FF), in: scene)
        pointer.zPosition = 100
        let url = directory.appendingPathComponent("edge-push.gif"), frames = 104
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil) else { throw ImportFailure.invalidImage }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let budget = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: false)
        // Advance only existing carried snow; avoid births in this focused demo.
        let noBirths = RenderBudget(framesPerSecond: budget.framesPerSecond, particleLimit: budget.particleLimit, birthMultiplier: 0)
        var previous = CGPoint(x: source.frame.maxX - 100, y: source.baseline + 8)
        for frame in 0..<frames {
            let progress = min(1, max(0, CGFloat(frame - 8) / 28))
            let point = CGPoint(x: source.frame.maxX - 100 + progress * 118, y: source.baseline + 8)
            if frame >= 8 && frame <= 36 { scene.simulation.sweep(at: point, from: previous, tool: .mitten, limit: budget.particleLimit(for: settings.weather)) }
            previous = point; pointer.position = point
            pointer.alpha = min(1, max(0, 1 - CGFloat(frame - 42) / 10))
            if frame > 0 { scene.simulation.step(delta: 1.0 / 24, settings: settings, budget: noBirths) }
            scene.redrawSurfaces()
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else { throw ImportFailure.invalidImage }
            let image = texture.cgImage()
            if frame == 40 { try ImportedAssets.png(image).write(to: directory.appendingPathComponent("edge-push.png"), options: .atomic) }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        if !CGImageDestinationFinalize(destination) { throw ImportFailure.invalidImage }
    }
    private static func treePreview(size: CGSize) -> (SKView, SKScene, HolidayTreeRenderer, SnowProfile) {
        let view = SKView(frame: CGRect(origin: .zero, size: size)); view.ignoresSiblingOrder = true
        let scene = SKScene(size: size); scene.backgroundColor = SnowArt.color(0x183344)
        let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: size), visible: [.init(0, size.width)], isBottom: true)
        var profile = SnowProfile(width: size.width, maximum: 48, variationSeed: 17)
        for x in stride(from: CGFloat(0), through: size.width, by: 4) { profile.deposit(at: x, amount: 100) }
        let snow = SKShapeNode(path: SnowContour.path(surface: floor, profile: profile, span: floor.visible[0]))
        SnowMaterialArt.apply(to: snow, surface: floor, appearance: .textured); snow.zPosition = 3; scene.addChild(snow)
        let renderer = HolidayTreeRenderer(); renderer.root.zPosition = 2.5; scene.addChild(renderer.root)
        view.presentScene(scene)
        return (view, scene, renderer, profile)
    }
    private static func renderSnowAppearances(to directory: URL) throws {
        let size = CGSize(width: 1280, height: 650)
        let view = SKView(frame: CGRect(origin: .zero, size: size)), scene = SKScene(size: size)
        view.ignoresSiblingOrder = true
        scene.backgroundColor = SnowArt.color(0x162937)
        for (index, appearance) in SnowAppearance.allCases.enumerated() {
            let group = SKNode(); group.position = CGPoint(x: CGFloat(index) * 640 + 20, y: 28); scene.addChild(group)
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            label.text = tr("snow.appearance." + appearance.rawValue); label.fontSize = 24
            label.horizontalAlignmentMode = .left; label.position = CGPoint(x: 20, y: 566); group.addChild(label)
            let window = SnowSurface(id: 41, frame: CGRect(x: 20, y: 290, width: 580, height: 220), visible: [.init(0, 580)])
            let body = SnowArt.rect(window.frame, color: SnowArt.color(0x293D4B), radius: window.cornerRadius, in: group)
            body.strokeColor = SnowArt.color(0x586A77); body.lineWidth = 1
            for (button, color) in [UInt32(0xF47870), 0xEDC76B, 0x76B990].enumerated() {
                SnowArt.circle(CGPoint(x: 44 + CGFloat(button) * 21, y: 486), radius: 6, color: SnowArt.color(color), in: group).zPosition = 1
            }
            var profile = SnowProfile(width: 580, maximum: 24, variationSeed: 42, roundedEdges: true)
            for x in stride(from: CGFloat(0), through: 580, by: 4) { profile.deposit(at: x, amount: 100) }
            let (game, floor, snow) = snowmanFixture()
            for (surface, p) in [(window, profile), (floor, snow[floor.id]!)] {
                let node = SKShapeNode(path: SnowContour.path(surface: surface, profile: p, span: surface.visible[0]))
                SnowMaterialArt.apply(to: node, surface: surface, appearance: appearance); node.zPosition = 3; group.addChild(node)
            }
            let renderer = SnowDecorationRenderer(); renderer.drawGame(game, surfaces: [floor], appearance: appearance)
            group.addChild(renderer.root)
            let ball = Snowball(id: 910_001, radius: 34, position: CGPoint(x: 420, y: 78))
            var loose = Snowball(id: 910_002, radius: 22, position: CGPoint(x: 540, y: 75)); loose.isLooseSnow = true
            let extras = SnowDecorationRenderer(); extras.drawGame(SnowGame(balls: [ball, loose]), surfaces: [], appearance: appearance)
            group.addChild(extras.root)
        }
        view.presentScene(scene)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snow-appearance-comparison.png"), options: .atomic)
        view.presentScene(nil)
    }
    private static func renderSnowmanDetails(to directory: URL) throws {
        let size = CGSize(width: 960, height: 650)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); view.ignoresSiblingOrder = true
        let scene = SKScene(size: size); scene.backgroundColor = SnowArt.color(0x183344)
        for (index, appearance) in SnowAppearance.allCases.enumerated() {
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            label.text = tr("snow.appearance." + appearance.rawValue); label.fontSize = 22
            label.position = CGPoint(x: 240 + index * 480, y: 602); scene.addChild(label)
            let (game, floor, profiles) = snowmanFixture()
            let group = SKNode(); group.setScale(2.5)
            group.position = CGPoint(x: CGFloat(240 + index * 480) - 600, y: 8); scene.addChild(group)
            let snow = SKShapeNode(path: SnowContour.path(surface: floor, profile: profiles[floor.id]!, span: .init(150, 330)))
            SnowMaterialArt.apply(to: snow, surface: floor, appearance: appearance); snow.zPosition = 3; group.addChild(snow)
            let renderer = SnowDecorationRenderer(); renderer.drawGame(game, surfaces: [floor], appearance: appearance)
            group.addChild(renderer.root)
        }
        view.presentScene(scene)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snowman-details.png"), options: .atomic)
        view.presentScene(nil)
    }
    private static func renderWindowCorners(to directory: URL) throws {
        let surface = SnowSurface(id: 42, frame: CGRect(x: 60, y: 40, width: 600, height: 180), visible: [.init(0, 600)])
        var profile = SnowProfile(width: 600, maximum: 18, variationSeed: 42, roundedEdges: true)
        for x in stride(from: CGFloat(0), through: 600, by: 4) { profile.deposit(at: x, amount: 100) }
        for right in [false, true] {
            let size = CGSize(width: 420, height: 260)
            let view = SKView(frame: CGRect(origin: .zero, size: size)); let scene = SKScene(size: size)
            SnowArt.rect(CGRect(origin: .zero, size: size), color: SnowArt.color(0x17404A), in: scene)
            let group = SKNode(); group.setScale(3)
            let left = right ? surface.frame.maxX - 128 : surface.frame.minX - 12
            group.position = CGPoint(x: -left * 3, y: -(surface.baseline - 48) * 3); scene.addChild(group)
            let body = SnowArt.rect(surface.frame, color: SnowArt.color(0xE9EFF2), radius: surface.cornerRadius, in: group)
            body.strokeColor = SnowArt.color(0x91A3AD); body.lineWidth = 0.7
            for (index, color) in [UInt32(0xF47870), 0xEDC76B, 0x76B990].enumerated() {
                SnowArt.circle(CGPoint(x: surface.frame.minX + 28 + CGFloat(index) * 21, y: surface.baseline - 26), radius: 6,
                               color: SnowArt.color(color), in: group).zPosition = 1
            }
            let snow = SKShapeNode(path: SnowContour.path(surface: surface, profile: profile, span: surface.visible[0]))
            snow.fillColor = .white; snow.strokeColor = .clear; snow.zPosition = 2; group.addChild(snow)
            view.presentScene(scene)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent(right ? "window-corner-right.png" : "window-corner-left.png"), options: .atomic)
            view.presentScene(nil)
        }
    }
    private static func renderGlassImpacts(to directory: URL) throws {
        let size = CGSize(width: 960, height: 810)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); let scene = SKScene(size: size)
        SnowArt.rect(CGRect(origin: .zero, size: size), color: SnowArt.color(0x848D91), in: scene)
        for index in 0..<9 {
            let position = CGPoint(x: 160 + (index % 3) * 320, y: 675 - (index / 3) * 270)
            var ball = Snowball(id: UInt64(720_000 + index), radius: 34, position: position)
            ball.glassFlight = GlassFlight(origin: position, target: position)
            let game = SnowGame(balls: [ball])
            for _ in 0..<30 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: size) }
            let renderer = SnowDecorationRenderer(); renderer.drawGame(game, surfaces: [])
            scene.addChild(renderer.root)
        }
        view.presentScene(scene)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snow-impacts.png"), options: .atomic)
        view.presentScene(nil)

        let filmSize = CGSize(width: 640, height: 420)
        let filmView = SKView(frame: CGRect(origin: .zero, size: filmSize))
        let film = WinterIllustration(size: filmSize, kind: .cabin)
        var ball = Snowball(id: 720_101, radius: 26, position: CGPoint(x: 160, y: 150))
        ball.glassFlight = GlassFlight(origin: ball.position, target: CGPoint(x: 385, y: 240))
        let game = SnowGame(balls: [ball]); let renderer = SnowDecorationRenderer(); film.addChild(renderer.root)
        filmView.presentScene(film); defer { filmView.presentScene(nil) }
        guard let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("snow-impact.gif") as CFURL,
                                                                UTType.gif.identifier as CFString, 144, nil) else { throw ImportFailure.invalidImage }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<144 {
            if frame > 0 { game.step(delta: 1.0 / 24, surfaces: [], profiles: [:], size: filmSize) }
            renderer.drawGame(game, surfaces: [])
            guard let texture = filmView.texture(from: film, crop: CGRect(origin: .zero, size: filmSize)) else { throw ImportFailure.invalidImage }
            let image = texture.cgImage()
            if frame == 18 { try ImportedAssets.png(image).write(to: directory.appendingPathComponent("snow-impact.png"), options: .atomic) }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        if !CGImageDestinationFinalize(destination) { throw ImportFailure.invalidImage }
    }
    private static func renderCleaners(to directory: URL) throws {
        let size = CGSize(width: 480, height: 320)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); let scene = SKScene(size: size)
        SnowArt.rect(CGRect(origin: .zero, size: size), color: SnowArt.color(0x183344), in: scene)
        var models: [SnowCleaner] = [], profiles: [SnowProfile?] = [], renderers: [SnowDecorationRenderer] = [], snowNodes: [SKShapeNode] = []
        var settings = SnowSettings(); settings.respectReduceMotion = false
        for (index, character) in CleanerCharacter.allCases.enumerated() {
            let group = SKNode(); group.position.y = index == 0 ? 160 : 0; scene.addChild(group)
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium"); label.text = tr("cleaner." + character.rawValue)
            label.fontSize = 13; label.fontColor = .white; label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: 18, y: 136); label.zPosition = 100; group.addChild(label)
            let model = SnowCleaner(); _ = model.start(character: character); models.append(model)
            var profile = SnowProfile(width: 480, maximum: 48, variationSeed: 42)
            for x in stride(from: CGFloat(0), through: 480, by: 4) { profile.deposit(at: x, amount: 100) }
            profiles.append(profile)
            let snow = SKShapeNode(); snow.fillColor = .white; snow.strokeColor = .clear; snow.zPosition = 1
            group.addChild(snow); snowNodes.append(snow)
            let renderer = SnowDecorationRenderer(); group.addChild(renderer.root); renderers.append(renderer)
        }
        view.presentScene(scene); defer { view.presentScene(nil) }
        let url = directory.appendingPathComponent("cleaners.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 120, nil) else { throw ImportFailure.invalidImage }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: 480, height: 160), visible: [.init(0, 480)], isBottom: true)
        for frame in 0..<120 {
            for index in models.indices {
                if frame > 0 { models[index].step(delta: 1.0 / 24, width: 480, settings: settings, profile: &profiles[index]) }
                renderers[index].drawCleaner(models[index], settings: settings)
                if let profile = profiles[index] { snowNodes[index].path = SnowContour.path(surface: floor, profile: profile, span: floor.visible[0]) }
            }
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            let image = texture.cgImage()
            if frame == 42 { try ImportedAssets.png(image).write(to: directory.appendingPathComponent("cleaners.png"), options: .atomic) }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        if !CGImageDestinationFinalize(destination) { throw ImportFailure.invalidImage }
    }
    private static func renderSnowPreview(to directory: URL) throws {
        let size = CGSize(width: 1000, height: 420)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); let scene = SKScene(size: size)
        SnowArt.rect(CGRect(origin: .zero, size: size), color: SnowArt.color(0x183344), in: scene)
        let window = SnowSurface(id: 42, frame: CGRect(x: 70, y: 120, width: 860, height: 180), visible: [.init(0, 860)])
        SnowArt.rect(window.frame, color: SnowArt.color(0x30363D), radius: window.cornerRadius, in: scene)
        for (index, color) in [UInt32(0xF47870), 0xEDC76B, 0x76B990].enumerated() {
            SnowArt.circle(CGPoint(x: 95 + index * 21, y: 277), radius: 6, color: SnowArt.color(color), in: scene)
        }
        let bottom = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: size), visible: [.init(0, size.width)], isBottom: true)
        for surface in [window, bottom] {
            var profile = SnowProfile(width: surface.length, maximum: surface.isBottom ? 48 : 18,
                                      variationSeed: UInt64(surface.id), roundedEdges: !surface.isBottom)
            for x in stride(from: CGFloat(0), through: surface.length, by: 4) { profile.deposit(at: x, amount: 100) }
            let snow = SKShapeNode(path: SnowContour.path(surface: surface, profile: profile, span: surface.visible[0]))
            snow.fillColor = .white; snow.strokeColor = .clear; snow.zPosition = 1; scene.addChild(snow)
        }
        view.presentScene(scene); defer { view.presentScene(nil) }
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snow-drifts.png"), options: .atomic)
    }
    private static func renderTreeAnimation(to directory: URL) throws {
        let size = CGSize(width: 1000, height: 260)
        let (view, scene, renderer, ground) = treePreview(size: size)
        defer { view.presentScene(nil) }
        let url = directory.appendingPathComponent("trees-growth.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 144, nil) else { throw ImportFailure.invalidImage }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var tree = HolidayTree(seed: 2026); tree.grow(reduceMotion: false)
        var settings = SnowSettings(); settings.garlandBrightness = 1
        for frame in 0..<144 {
            if frame == 72 { tree.remove() }
            if frame == 84 { tree.grow(reduceMotion: false) }
            if frame > 0 { tree.step(delta: 1.0 / 24, reduceMotion: false) }
            renderer.draw(tree, size: size, time: Double(frame) / 24, settings: settings, reduceMotion: false, ground: ground)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
            CGImageDestinationAddImage(destination, texture.cgImage(), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        if !CGImageDestinationFinalize(destination) { throw ImportFailure.invalidImage }
    }
    static func run() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SnowChecks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let context = CGContext(data: nil, width: 2400, height: 1200, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(SnowArt.color(0x2E7765).cgColor); context.fill(CGRect(x: 200, y: 100, width: 2000, height: 1000))
            let image = context.makeImage()!
            for type in [UTType.png, .jpeg, .heic] {
                let url = folder.appendingPathComponent("input." + (type.preferredFilenameExtension ?? "image"))
                if let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    if CGImageDestinationFinalize(destination) {
                        let decoded = try ImportedAssets.decode(url)
                        checks["import." + type.identifier] = decoded.width <= 1024 && decoded.height <= 1024
                    } else { checks["import." + type.identifier] = false }
                } else { checks["import." + type.identifier] = false }
            }
            let pngURL = folder.appendingPathComponent("input.png")
            let decoded = try ImportedAssets.decode(pngURL)
            let saved = folder.appendingPathComponent("saved")
            try ImportedAssets.save(decoded, as: .blade, directory: saved)
            let stored = saved.appendingPathComponent("blade.png")
            let original = try Data(contentsOf: stored)
            let invalid = folder.appendingPathComponent("invalid.png")
            try Data("invalid image".utf8).write(to: invalid)
            checks["corruptImageRejected"] = (try? ImportedAssets.decode(invalid)) == nil
            let oversized = folder.appendingPathComponent("large.png")
            try Data(repeating: 0, count: ImageImportPolicy.maximumBytes + 1).write(to: oversized)
            checks["oversizedImageRejected"] = (try? ImportedAssets.decode(oversized)) == nil
            checks["badImportPreservesPreviousImage"] = try Data(contentsOf: stored) == original
            try FileManager.default.removeItem(at: pngURL)
            checks["importIsIndependentOfOriginal"] = NSImage(contentsOf: stored) != nil
            let rejected = (try? ImportedAssets.save(image, as: .blade, directory: saved)) == nil
            let afterRejected = try Data(contentsOf: stored)
            checks["oversizedDecodedImageNotStored"] = rejected && afterRejected == original
        } catch { checks["importFixtureCompleted"] = false }
        for kind in [WinterScene.cabin, .porch] {
            let art = WinterIllustration(size: CGSize(width: 800, height: 600), kind: kind)
            checks["sceneArt." + kind.rawValue] = art.children.map { $0.children.count }.max() ?? 0 > 100
        }
        let sceneController = WinterSceneController()
        sceneController.configure(kind: .cabin, frame: CGRect(x: 0, y: 0, width: 800, height: 600), reduceMotion: true)
        checks["sceneBelowDesktopIconsAndClickThrough"] = sceneController.window?.ignoresMouseEvents == true &&
            (sceneController.window?.level.rawValue ?? 0) < Int(CGWindowLevelForKey(.desktopIconWindow))
        var hidden = PauseState(); hidden.set(.hidden, active: true); sceneController.apply(hidden)
        checks["sceneHidesWithEffects"] = sceneController.window?.isVisible == false
        sceneController.close(); checks["sceneCloses"] = sceneController.window == nil
        let garlands = SnowDecorationRenderer()
        var settings = SnowSettings(); settings.garland = .wave
        garlands.configureGarland(size: CGSize(width: 400, height: 300), settings: settings)
        func alphas() -> [CGFloat] { garlands.root.children.flatMap { $0.children.map(\.alpha) } }
        garlands.animateGarland(time: 0, settings: settings, reduceMotion: true); let frozen = alphas()
        garlands.animateGarland(time: 12, settings: settings, reduceMotion: true)
        checks["reduceMotionMakesGarlandSteady"] = frozen == alphas() && !frozen.isEmpty
        garlands.animateGarland(time: 1, settings: settings, reduceMotion: false)
        checks["waveGarlandAnimates"] = frozen != alphas()
        let lampNodes = garlands.screenGarland.root.children.map { ObjectIdentifier($0) }
        settings.garlandBlinkIntensity = 0
        garlands.animateGarland(time: 0, settings: settings, reduceMotion: false); let constant = alphas()
        garlands.animateGarland(time: 12, settings: settings, reduceMotion: false)
        checks["zeroIntensityMakesGarlandSteady"] = constant == alphas()
        settings.garlandBrightness = 0.25
        garlands.configureGarland(size: CGSize(width: 400, height: 300), settings: settings)
        garlands.animateGarland(time: 12, settings: settings, reduceMotion: false)
        checks["brightnessChangesWithoutRebuildingLamps"] = constant != alphas() &&
            garlands.screenGarland.root.children.map { ObjectIdentifier($0) } == lampNodes
        let (game, floor, profiles) = snowmanFixture()
        let snowman = SnowDecorationRenderer(); snowman.drawGame(game, surfaces: [floor])
        if let bucket = snowman.root.childNode(withName: "//snowman.bucket") {
            var owner: SKNode? = bucket.parent
            while owner != nil && !(owner is SKCropNode) { owner = owner?.parent }
            if let crop = owner as? SKCropNode, let art = crop.children.first, let mask = crop.maskNode {
                checks["bucketFitsSnowmanCrop"] = mask.calculateAccumulatedFrame().contains(art.calculateAccumulatedFrame())
            } else { checks["bucketFitsSnowmanCrop"] = false }
        } else { checks["bucketFitsSnowmanCrop"] = false }
        var cleared = profiles; cleared[floor.id]?.clear()
        for _ in 0..<180 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: cleared, size: floor.frame.size) }
        snowman.drawGame(game, surfaces: [floor])
        checks["fallingSnowmanRetainsBucket"] = snowman.root.childNode(withName: "//snowman.bucket") != nil && game.snowmen.count == 1 && game.balls.first?.position.y == 36
        let treeRenderer = HolidayTreeRenderer(); var tree = HolidayTree(seed: 17); tree.grow(reduceMotion: false)
        let treeSize = CGSize(width: 800, height: 600)
        treeRenderer.draw(tree, size: treeSize, time: 0, settings: settings, reduceMotion: false)
        let firstTree = treeRenderer.root.children.first!
        let smallScale = firstTree.yScale
        tree.step(delta: 0, reduceMotion: true)
        treeRenderer.draw(tree, size: treeSize, time: 0, settings: settings, reduceMotion: false)
        checks["fiveSmallTreesSpreadAcrossBottomIncludingCenter"] = treeRenderer.root.children.count == 5 &&
            treeRenderer.root.children.first!.position.x < 160 && treeRenderer.root.children.last!.position.x > 640 &&
            treeRenderer.root.children.contains { (280...520).contains($0.position.x) } &&
            treeRenderer.root.children.allSatisfy { $0.yScale * HolidayTree.artSize.height <= 125 } && firstTree.yScale > smallScale
        let firstLayout = treeRenderer.root.children.map(\.position.x)
        func treeAlphas() -> [CGFloat] {
            var result: [CGFloat] = []
            treeRenderer.root.enumerateChildNodes(withName: "//tree.lamp") { node, _ in result.append(node.alpha) }
            treeRenderer.root.enumerateChildNodes(withName: "//tree.star") { node, _ in result.append(node.alpha) }
            return result
        }
        settings.garland = .off; settings.garlandBrightness = 1; settings.garlandBlinkIntensity = 0.7
        treeRenderer.draw(tree, size: treeSize, time: 0, settings: settings, reduceMotion: false); let lit = treeAlphas()
        let starAlpha = treeRenderer.root.childNode(withName: "//tree.star")?.alpha
        treeRenderer.draw(tree, size: treeSize, time: 1, settings: settings, reduceMotion: false)
        checks["treeGarlandAndStarBlinkIndependentlyOfScreenGarland"] = lit.count == 20 && lit != treeAlphas() && starAlpha != treeRenderer.root.childNode(withName: "//tree.star")?.alpha
        treeRenderer.draw(tree, size: treeSize, time: 0, settings: settings, reduceMotion: true); let still = treeAlphas()
        treeRenderer.draw(tree, size: treeSize, time: 12, settings: settings, reduceMotion: true)
        checks["treeReduceMotionMakesLightsSteady"] = still == treeAlphas()
        settings.garlandBlinkIntensity = 0
        treeRenderer.draw(tree, size: treeSize, time: 0, settings: settings, reduceMotion: false); let constantTreeLights = treeAlphas()
        treeRenderer.draw(tree, size: treeSize, time: 4, settings: settings, reduceMotion: false)
        checks["allTreeLightsRespectZeroBlinkIntensity"] = constantTreeLights == treeAlphas()
        settings.garlandBrightness = 0
        treeRenderer.draw(tree, size: treeSize, time: 4, settings: settings, reduceMotion: false)
        checks["allTreeLightsRespectZeroBrightness"] = treeAlphas().allSatisfy { $0 == 0 }
        var treeTextures: [SKTexture] = []
        treeRenderer.root.enumerateChildNodes(withName: "//*") { node, _ in
            if let sprite = node as? SKSpriteNode, let texture = sprite.texture { treeTextures.append(texture) }
        }
        checks["fiveTreesShareFiveTextureLayers"] = treeTextures.count == 25 && Set(treeTextures.map(ObjectIdentifier.init)).count == 5
        if let body = treeRenderer.root.childNode(withName: "//tree.body") as? SKSpriteNode, let texture = body.texture {
            let image = NSBitmapImageRep(cgImage: texture.cgImage())
            let leaf = image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2)!.usingColorSpace(.sRGB)!
            checks["treeRasterKeepsArtworkAndTransparentBackground"] = (image.colorAt(x: 0, y: 0)?.alphaComponent ?? 1) == 0 &&
                leaf.greenComponent > leaf.redComponent && leaf.greenComponent > 0.2 && leaf.alphaComponent > 0.9
        } else { checks["treeRasterKeepsArtworkAndTransparentBackground"] = false }
        let treeScene = SnowScene(size: treeSize, seed: 17)
        treeScene.simulation.synchronize(surfaces: [], settings: .init(), liveWindowIDs: [])
        treeScene.redrawSurfaces()
        func maximumTreeDepth(_ node: SKNode) -> CGFloat { node.zPosition + (node.children.map(maximumTreeDepth).max() ?? 0) }
        let treeDepth = maximumTreeDepth(treeRenderer.root) - treeRenderer.root.zPosition
        checks["treeRootsDrawBehindSnowWithoutCapturingInput"] = treeScene.treeRenderer.root.zPosition + treeDepth < (treeScene.childNode(withName: "snow.surface")?.zPosition ?? 0) && !treeScene.treeRenderer.root.isUserInteractionEnabled
        var treeIDs: [ObjectIdentifier] = []
        treeRenderer.root.enumerateChildNodes(withName: "//*") { node, _ in treeIDs.append(ObjectIdentifier(node)) }
        tree.grow(reduceMotion: false); treeRenderer.draw(tree, size: treeSize, time: 12, settings: settings, reduceMotion: false)
        var repeatedIDs: [ObjectIdentifier] = []
        treeRenderer.root.enumerateChildNodes(withName: "//*") { node, _ in repeatedIDs.append(ObjectIdentifier(node)) }
        checks["treeReusesBoundedArtworkOnRepeatedGrowth"] = treeIDs == repeatedIDs && treeIDs.count == 30
        let secondLayout = treeRenderer.root.children.map(\.position.x)
        treeRenderer.draw(tree, size: treeSize, time: 24, settings: settings, reduceMotion: false)
        checks["treePositionsChangeOnlyOnNewGrowth"] = firstLayout != secondLayout && secondLayout == treeRenderer.root.children.map(\.position.x)
        tree.remove(); treeRenderer.draw(tree, size: treeSize, time: 12, settings: settings, reduceMotion: false)
        checks["treeCanBeRemoved"] = treeRenderer.root.isHidden && !treeRenderer.root.hasActions()
        for character in CleanerCharacter.allCases {
            let art = SnowArt.cleaner(character, blade: nil)
            checks["cleanerArt." + character.rawValue] = !art.children.isEmpty
            func maxZ(_ node: SKNode) -> CGFloat { node.zPosition + (node.children.map(maxZ).max() ?? 0) }
            if let cab = art.childNode(withName: "cleaner.cabAndBody"), let wheel = art.childNode(withName: "cleaner.wheel.rear") {
                checks["cleanerGlassBehindWheel." + character.rawValue] = maxZ(cab) < wheel.zPosition
            } else { checks["cleanerGlassBehindWheel." + character.rawValue] = false }
            let renderer = SnowDecorationRenderer(); let model = SnowCleaner(); _ = model.start(character: character)
            var profile: SnowProfile? = SnowProfile(width: 360, maximum: 48)
            for x in stride(from: CGFloat(0), through: 360, by: 4) { profile?.deposit(at: x, amount: 100) }
            var settings = SnowSettings(); settings.respectReduceMotion = false
            renderer.drawCleaner(model, settings: settings)
            let rear = renderer.root.childNode(withName: "//cleaner.wheel.rear")
            let front = renderer.root.childNode(withName: "//cleaner.wheel.front")
            for _ in 0..<80 { model.step(delta: 1.0 / 60, width: 360, settings: settings, profile: &profile) }
            renderer.drawCleaner(model, settings: settings)
            checks["cleanerWheelsAndBucket." + character.rawValue] = rear != nil && front != nil &&
                (front?.zRotation ?? 0) < (rear?.zRotation ?? 0) && (rear?.zRotation ?? 0) < 0 &&
                renderer.root.childNode(withName: "//cleaner.bucket") != nil
            checks["cleanerCollectsWithoutRebuilding." + character.rawValue] = model.snowLoad > 0 &&
                renderer.root.childNode(withName: "//cleaner.bucket.snow")?.isHidden == false &&
                rear === renderer.root.childNode(withName: "//cleaner.wheel.rear")
        }
        checks.merge(glassImpactChecks()) { _, new in new }
        checks.merge(snowMaterialChecks()) { _, new in new }
        checks.merge(snowmanDetailChecks()) { _, new in new }
        checks.merge(SnowmanArt.validationChecks()) { _, new in new }
        checks.merge(edgePushChecks()) { _, new in new }
        checks.merge(snowflakeChecks()) { _, new in new }
        return checks
    }
    private static func snowflakeChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let textures = (0..<SnowflakeArt.variantCount).map { SnowflakeArt.texture(variant: $0) }
        checks["snowflakeArtSharesEightBoundedTextures"] = Set(textures.map(ObjectIdentifier.init)).count == 8 &&
            textures[0] === SnowflakeArt.texture(variant: 8) && textures.allSatisfy { $0.size() == CGSize(width: 192, height: 192) }
        var drawings: Set<Data> = [], validArtwork = true
        for texture in textures {
            let cg = texture.cgImage(), image = NSBitmapImageRep(cgImage: texture.cgImage())
            drawings.insert(cg.dataProvider!.data! as Data)
            var filled = 0
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
                    if (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 { filled += 1 }
                }
            }
            validArtwork = validArtwork && (image.colorAt(x: 0, y: 0)?.alphaComponent == 0) && filled > 8 && filled < 400
        }
        checks["snowflakeArtIsDistinctAndTransparent"] = drawings.count == 8 && validArtwork
        let particle = SnowParticle(x: 120, y: 200, speed: 50, drift: 0, radius: 3, alpha: 1, life: 120, scattered: false, flakeSeed: 3 << 16)
        let node = SKSpriteNode(); var settings = SnowSettings()
        SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 1, reduceMotion: false)
        checks["simpleFlakesKeepOriginalSizeAndTexture"] = node.texture === SnowflakeArt.simpleTexture && abs(node.size.width - 8.1) < 0.001 && node.zRotation == 0
        settings.snowflakeStyle = .patterned
        SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 1, reduceMotion: false)
        let initialTexture = node.texture, initialRotation = node.zRotation
        SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 2, reduceMotion: false)
        checks["flakeShapeStaysStableWhileRotating"] = node.texture === initialTexture && node.zRotation != initialRotation
        SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 1, reduceMotion: true); let still = node.zRotation
        SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 20, reduceMotion: true)
        checks["reduceMotionStopsFlakeRotation"] = node.zRotation == still
        var scalesCorrect = true
        for style in SnowflakeStyle.allCases {
            settings.snowflakeStyle = style; settings.snowflakeSize = 0.5
            SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 0, reduceMotion: true); let small = node.size.width
            settings.snowflakeSize = 3
            SnowflakeArt.apply(to: node, particle: particle, settings: settings, time: 0, reduceMotion: true)
            scalesCorrect = scalesCorrect && abs(node.size.width / small - 6) < 0.001
        }
        checks["flakeSizeScalesBothStyles"] = scalesCorrect
        var loose = particle; loose.scattered = true; loose.carriedArea = 40
        settings.snowflakeStyle = .patterned; settings.snowflakeSize = 3
        SnowflakeArt.apply(to: node, particle: loose, settings: settings, time: 2, reduceMotion: false)
        checks["displacedSnowDoesNotBecomeLargeCrystals"] = node.texture === SnowflakeArt.simpleTexture && abs(node.size.width - 8.1) < 0.001 && node.zRotation == 0

        var preferences = SnowSettings(); preferences.snowAppearance = .textured
        let scene = SnowScene(size: CGSize(width: 640, height: 480), seed: 123)
        scene.settings = { preferences }; scene.isRunning = false
        scene.simulation.synchronize(surfaces: [], settings: preferences, liveWindowIDs: [])
        for _ in 0..<8 { scene.simulation.step(delta: 1.0 / 15, settings: preferences, budget: scene.budget) }
        scene.redrawSurfaces()
        let particles = scene.simulation.particles, profiles = scene.simulation.profiles
        let nodes = scene.children.compactMap { $0.name == "snow.particle" ? $0 as? SKSpriteNode : nil }
        let firstWidth = nodes.first?.size.width ?? 0
        preferences.snowflakeStyle = .patterned; preferences.snowflakeSize = 2; scene.redrawSurfaces()
        let newNodes = scene.children.filter { $0.name == "snow.particle" }
        checks["flakeStyleUpdatesOnPausedSceneWithoutReset"] = !nodes.isEmpty && nodes.map(ObjectIdentifier.init) == newNodes.map(ObjectIdentifier.init) &&
            nodes.allSatisfy { $0.texture !== SnowflakeArt.simpleTexture } && (nodes.first?.size.width ?? 0) > firstWidth &&
            scene.simulation.particles == particles && scene.simulation.profiles == profiles && preferences.snowAppearance == .textured
        preferences.snowflakeStyle = .simple; preferences.snowflakeSize = 1; scene.redrawSurfaces()
        checks["simpleFlakesRestoreOnSameNodes"] = nodes.allSatisfy { $0.texture === SnowflakeArt.simpleTexture && $0.zRotation == 0 } &&
            abs((nodes.first?.size.width ?? 0) - firstWidth) < 0.001
        return checks
    }
    private static func edgePushChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let (scene, source, settings) = edgePushFixture()
        let point = source.point(at: 492, height: scene.simulation.profiles[source.id]!.height(at: 492))
        scene.simulation.sweep(at: point, from: CGPoint(x: point.x - 18, y: point.y), tool: .mitten, limit: 100)
        scene.redrawSurfaces()
        let nodes = scene.children.compactMap { $0.name == "snow.particle" ? $0 as? SKSpriteNode : nil }
        checks["pushedSnowUsesVisibleParticleSprites"] = !nodes.isEmpty && nodes.count == scene.simulation.particles.count && nodes.allSatisfy { !$0.isHidden && $0.alpha > 0.9 }
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size)); view.ignoresSiblingOrder = true; view.presentScene(scene)
        if let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)), let part = scene.simulation.particles.first {
            let image = NSBitmapImageRep(cgImage: texture.cgImage())
            let x = Int(part.x / scene.size.width * CGFloat(image.pixelsWide))
            let y = Int((scene.size.height - part.y) / scene.size.height * CGFloat(image.pixelsHigh))
            let color = image.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
            checks["pushedSnowActuallyRendersOutsideWindowEdge"] = color.redComponent > 0.7 && color.greenComponent > 0.7 && color.blueComponent > 0.7
        } else { checks["pushedSnowActuallyRendersOutsideWindowEdge"] = false }
        let originalY = nodes.first?.position.y ?? 0
        for _ in 0..<8 { scene.simulation.step(delta: 1.0 / 60, settings: settings, budget: .init(framesPerSecond: 30, particleLimit: 200, birthMultiplier: 0)) }
        scene.redrawSurfaces()
        checks["fallingSnowReusesSpritesWhileDescending"] = nodes.first === scene.childNode(withName: "snow.particle") && (nodes.first?.position.y ?? originalY) < originalY
        scene.simulation.clear(); scene.redrawSurfaces()
        checks["clearRemovesDisplacedSnowAndHidesSprites"] = scene.simulation.particles.isEmpty && nodes.allSatisfy(\.isHidden)
        view.presentScene(nil)
        return checks
    }
    private static func snowmanDetailChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        for appearance in SnowAppearance.allCases {
            let (game, floor, _) = snowmanFixture()
            let renderer = SnowDecorationRenderer(); renderer.drawGame(game, surfaces: [floor], appearance: appearance)
            let scene = SKScene(size: floor.frame.size); scene.backgroundColor = SnowArt.color(0x183344)
            scene.addChild(renderer.root)
            let view = SKView(frame: floor.frame); view.ignoresSiblingOrder = true; view.presentScene(scene)
            guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)), let head = game.balls.last,
                  let base = game.balls.first else { checks["snowmanRender." + appearance.rawValue] = false; continue }
            let image = NSBitmapImageRep(cgImage: texture.cgImage())
            func sample(_ point: CGPoint) -> NSColor {
                let x = min(image.pixelsWide - 1, max(0, Int(point.x / scene.size.width * CGFloat(image.pixelsWide))))
                let y = min(image.pixelsHigh - 1, max(0, Int((scene.size.height - point.y) / scene.size.height * CGFloat(image.pixelsHigh))))
                return image.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
            }
            func atHead(_ x: CGFloat, _ y: CGFloat) -> NSColor {
                sample(CGPoint(x: head.position.x + x * head.radius, y: head.position.y + y * head.radius))
            }
            func isCoal(_ color: NSColor) -> Bool { color.redComponent < 0.35 && color.greenComponent < 0.4 && color.blueComponent < 0.45 }
            checks["snowmanEyesVisibleWithBatching." + appearance.rawValue] = isCoal(atHead(-0.28, 0.25)) && isCoal(atHead(0.28, 0.25))
            let nose = atHead(0.3, -0.07)
            checks["snowmanNoseVisibleWithBatching." + appearance.rawValue] = nose.redComponent > 0.65 && nose.greenComponent > 0.35 && nose.blueComponent < 0.4
            checks["snowmanSmileVisibleWithBatching." + appearance.rawValue] = isCoal(atHead(0, -0.44))
            var markers: [SKNode] = []
            renderer.root.enumerateChildNodes(withName: "//snow.ball.centerMarker") { node, _ in markers.append(node) }
            let center = sample(CGPoint(x: base.position.x, y: base.position.y - 2))
            checks["ballMarkersRemainTransparent." + appearance.rawValue] = markers.count == 2 && markers.allSatisfy { $0.alpha == 0 } && center.redComponent > 0.55
            if appearance == .textured {
                let left = atHead(-0.5, -0.86), right = atHead(0.5, -0.86), tail = atHead(-0.30, -1.25)
                func blue(_ color: NSColor) -> Bool { color.redComponent < 0.5 && color.greenComponent > 0.35 && color.blueComponent > 0.45 }
                checks["scarfCollarAndTailVisibleWithBatching"] = blue(left) && blue(right) && blue(tail)
                if let tailNode = renderer.root.childNode(withName: "//snowman.scarf.tail"),
                   let collar = renderer.root.childNode(withName: "//snowman.scarf.collar") as? SKShapeNode {
                    let bounds = collar.path!.boundingBoxOfPath
                    checks["scarfHasLevelSymmetricCollarAndStraightTail"] = abs(bounds.minX + bounds.maxX) < 0.001 && tailNode.zRotation == 0
                } else { checks["scarfHasLevelSymmetricCollarAndStraightTail"] = false }
            }
            view.presentScene(nil)
        }
        return checks
    }
    private static func snowMaterialChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let (game, floor, profiles) = snowmanFixture()
        let path = SnowContour.path(surface: floor, profile: profiles[floor.id]!, span: floor.visible[0])
        let node = SKShapeNode(path: path)
        SnowMaterialArt.apply(to: node, surface: floor, appearance: .textured)
        let shader = node.fillShader, tile = node.fillTexture
        SnowMaterialArt.apply(to: node, surface: floor, appearance: .textured)
        checks["snowMaterialSharesShaderAndTile"] = shader != nil && shader === node.fillShader && tile === node.fillTexture
        SnowMaterialArt.apply(to: node, surface: floor, appearance: .simple)
        checks["simpleSnowRemovesMaterialWithoutChangingContour"] = node.fillShader == nil && node.fillTexture == nil && node.path == path
        checks["snowballsShareBoundedTexture"] = SnowMaterialArt.ballTexture(loose: false) === SnowMaterialArt.ballTexture(loose: false) &&
            SnowMaterialArt.ballTexture(loose: false).size() == CGSize(width: 256, height: 256) &&
            SnowMaterialArt.ballTexture(loose: false) !== SnowMaterialArt.ballTexture(loose: true)
        let renderer = SnowDecorationRenderer()
        renderer.drawGame(game, surfaces: [floor], appearance: .textured)
        let original = renderer.root.childNode(withName: "//snow.ball.material")
        renderer.drawGame(game, surfaces: [floor], appearance: .textured)
        checks["snowMaterialReusesBallNodes"] = original != nil && original === renderer.root.childNode(withName: "//snow.ball.material")
        checks["texturedSnowmanHasScarfAndBucket"] = renderer.root.childNode(withName: "//snowman.scarf") != nil && renderer.root.childNode(withName: "//snowman.bucket") != nil
        renderer.drawGame(game, surfaces: [floor], appearance: .simple)
        checks["snowStyleSwitchPreservesGameAndBucket"] = renderer.root.childNode(withName: "//snow.ball.material") == nil &&
            renderer.root.childNode(withName: "//snowman.scarf") != nil && renderer.root.childNode(withName: "//snowman.bucket") != nil && game.balls.count == 3
        var preferences = SnowSettings(); preferences.snowAppearance = .simple
        let scene = SnowScene(size: floor.frame.size, seed: 17)
        scene.settings = { preferences }; scene.isRunning = false
        scene.simulation.synchronize(surfaces: [], settings: preferences, liveWindowIDs: [])
        _ = scene.simulation.adopt(profiles[floor.id]!, for: floor.id)
        _ = game.transfer(on: floor.id, to: scene.simulation.game, matching: { _ in true })
        let before = scene.simulation.game.balls, snow = scene.simulation.profiles
        scene.redrawSurfaces()
        let cap = scene.childNode(withName: "snow.surface") as? SKShapeNode
        preferences.snowAppearance = .textured; scene.redrawSurfaces()
        checks["snowStyleUpdatesWhilePausedWithoutLosingSnow"] = cap?.fillShader != nil && !scene.isRunning &&
            scene.simulation.profiles == snow && scene.simulation.game.balls == before
        preferences.snowAppearance = .simple; scene.redrawSurfaces()
        checks["simpleStyleRestoresOnSameSurfaceNode"] = cap != nil && cap === scene.childNode(withName: "snow.surface") && cap?.fillShader == nil &&
            scene.simulation.profiles == snow && scene.simulation.game.balls == before
        return checks
    }
    private static func glassImpactChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let size = CGSize(width: 640, height: 420)
        var ball = Snowball(id: 730_001, radius: 24, position: CGPoint(x: 150, y: 150))
        ball.glassFlight = GlassFlight(origin: ball.position, target: CGPoint(x: 350, y: 260))
        let game = SnowGame(balls: [ball]); let renderer = SnowDecorationRenderer()
        for _ in 0..<8 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: size) }
        checks["snowballApproachesGlass"] = game.balls.first?.approachScale ?? 0 > 1 && game.impacts.isEmpty
        for _ in 0..<10 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: size) }
        renderer.drawGame(game, surfaces: [])
        let mark = renderer.root.childNode(withName: "snow.impact")
        checks["glassImpactReplacesBall"] = game.balls.isEmpty && game.impacts.count == 1 && mark != nil
        checks["glassImpactDrawsAboveGarland"] = (mark?.zPosition ?? 0) > renderer.screenGarland.root.zPosition
        for _ in 0..<240 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: size) }
        renderer.drawGame(game, surfaces: [])
        checks["glassMarkFadesWithoutRebuildingSprite"] = mark === renderer.root.childNode(withName: "snow.impact") &&
            (mark?.alpha ?? 1) > 0 && (mark?.alpha ?? 1) < 1
        renderer.drawGame(game, surfaces: [], reduceMotion: true)
        checks["glassReduceMotionDisablesExpansion"] = mark?.xScale == 1 && mark?.yScale == 1
        game.clear(); renderer.drawGame(game, surfaces: [])
        checks["clearRemovesGlassMarks"] = renderer.root.childNode(withName: "snow.impact") == nil
        let textures = (0..<9).map { SnowImpactArt.texture(variant: $0) }
        checks["glassArtTextureCacheBounded"] = Set(textures.map(ObjectIdentifier.init)).count == 9 &&
            textures[0] === SnowImpactArt.texture(variant: 99) && textures.allSatisfy { $0.size() == CGSize(width: 384, height: 384) }
        checks["glassArtHasTransparentBackground"] = (0..<9).allSatisfy { variant in
            let bitmap = NSBitmapImageRep(cgImage: SnowImpactArt.image(variant: variant))
            return bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0 && (bitmap.colorAt(x: 192, y: 192)?.alphaComponent ?? 0) > 0.9
        }
        return checks
    }
}
