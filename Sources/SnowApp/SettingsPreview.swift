import AppKit
import SwiftUI
import SpriteKit

@MainActor
enum SettingsVisualChecks {
    static func render(to directory: URL) throws -> [String: Bool] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let domain = "local.snow.ui-preview." + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain)!
        let previousLanguage = AppLocalization.shared.language
        let previousPreference = UserDefaults.standard.object(forKey: AppLocalization.preferenceKey)
        let store = SettingsStore(defaults: defaults)
        defer {
            store.selectLanguage(previousLanguage)
            if let previousPreference { UserDefaults.standard.set(previousPreference, forKey: AppLocalization.preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLocalization.preferenceKey) }
            defaults.removePersistentDomain(forName: domain)
        }
        store.selectLanguage(.russian)
        store.value.snowflakeStyle = .patterned; store.value.snowAppearance = .textured; store.value.snowflakeSize = 1.2
        store.value.windowHeight = 16; store.value.garland = .twinkle; store.value.garlandPalette = .warm
        store.value.garlandBrightness = 0.7; store.value.garlandBlinkIntensity = 0.35
        store.value.accumulateOnDock = true
        store.displayList = [(1, tr("ui.check.builtIn")), (2, tr("ui.check.external"))]
        var checks: [String: Bool] = [:]
        for pane in SettingsPane.visibleCases {
            store.selectedPane = pane
            let view = NSHostingView(rootView: SettingsView(store: store))
            let window = prepare(view, size: CGSize(width: 1040, height: 660))
            try save(view, to: directory.appendingPathComponent(pane.rawValue + ".png"))
            checks["ui.render." + pane.rawValue] = view.bounds.size == CGSize(width: 1040, height: 660)
            if pane == .snow, let control = sliders(in: view).first {
                control.doubleValue = 1.7; _ = control.sendAction(control.action, to: control.target)
                let persisted = SnowSettings.load(defaults.data(forKey: SettingsStore.key))
                checks["ui.nativeSliderPersists"] = abs(store.value.snowflakeSize - 1.7) < 0.001 && abs(persisted.snowflakeSize - 1.7) < 0.001
                store.value.snowflakeSize = 1.2
            }
            if pane == .garlands {
                var modesPass = true
                for mode in GarlandMode.allCases {
                    let selected = choose(tr("garland." + mode.rawValue), in: "garland.mode", view: view)
                    modesPass = modesPass && selected && store.value.garland == mode
                        && SnowSettings.load(defaults.data(forKey: SettingsStore.key)).garland == mode
                }
                checks["ui.garlandModeNativeActionsPersist"] = modesPass
                store.value.garland = .twinkle
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
                var palettesPass = true
                for palette in GarlandPalette.allCases {
                    let selected = choose(tr("palette." + palette.rawValue), in: "garland.palette", view: view)
                    palettesPass = palettesPass && selected && store.value.garlandPalette == palette
                        && SnowSettings.load(defaults.data(forKey: SettingsStore.key)).garlandPalette == palette
                }
                checks["ui.garlandPaletteNativeActionsPersist"] = palettesPass
            }
            window.orderOut(nil); window.contentView = nil
        }
        let popover = NSHostingView(rootView: StatusPopoverView(store: store))
        let popoverWindow = prepare(popover, size: CGSize(width: SnowPopoverLayout.width, height: popover.fittingSize.height))
        try save(popover, to: directory.appendingPathComponent("menu.png"))
        let nativeControls = sliders(in: popover).map { $0 as NSView }
            + descendants(in: popover, of: SnowPopupButton.self).map { $0 as NSView }
        checks["ui.scaledNativeControlFrames"] = !nativeControls.isEmpty && nativeControls.allSatisfy { control in
            let frame = popover.convert(control.bounds, from: control)
            return abs(frame.width - control.bounds.width * SnowPopoverLayout.scale) < 0.5
                && abs(frame.height - control.bounds.height * SnowPopoverLayout.scale) < 0.5
        }
        checks["ui.scaledNativeControlHitTargets"] = !nativeControls.isEmpty && nativeControls.allSatisfy { control in
            let frame = popover.convert(control.bounds, from: control)
            let point = popover.convert(CGPoint(x: frame.midX, y: frame.midY), to: popover.superview)
            let hit = popover.hitTest(point)
            let matches = hit === control || hit?.isDescendant(of: control) == true
            if !matches { fputs("Native hit mismatch: \(type(of: control)), frame \(frame), hit \(String(describing: hit))\n", stderr) }
            return matches
        }
        if let control = sliders(in: popover).last {
            control.doubleValue = 23.3; _ = control.sendAction(control.action, to: control.target)
            checks["ui.quickSliderUsesSameStore"] = store.value.wind == 23 && SnowSettings.load(defaults.data(forKey: SettingsStore.key)).wind == 23
            store.value.wind = 0
        }
        popoverWindow.orderOut(nil); popoverWindow.contentView = nil
        var started: [SnowTool] = []
        store.onPlay = { started.append(store.selectedTool) }
        store.play(with: .mitten); store.play(with: .snowball)
        checks["ui.toolSelectionStartsImmediately"] = started == [.mitten, .snowball]
        store.play(with: .shovel)
        store.play(with: .delete)
        store.effectPaused = true; store.play(with: .mitten); store.effectPaused = false
        store.effectsHidden = true; store.play(with: .mitten); store.effectsHidden = false
        checks["ui.hiddenAndPausedToolsCannotStart"] = started == [.mitten, .snowball]
        checks["ui.hiddenToolsAndImplementationsRetained"] = SnowTool.visibleCases == [.mitten, .snowball] && SnowTool.allCases.contains(.shovel) && SnowTool.allCases.contains(.delete)
        store.onPlay = nil
        let short = NSHostingView(rootView: StatusPopoverView(store: store, viewportHeight: 240))
        let shortWindow = prepare(short, size: CGSize(width: SnowPopoverLayout.width, height: 240))
        try save(short, to: directory.appendingPathComponent("menu-short.png"))
        if let scroll = descendants(in: short, of: NSScrollView.self).first(where: { ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height + 1 }) {
            checks["ui.shortPopoverScrolls"] = true
            let bottom = max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height)
            scroll.contentView.scroll(to: CGPoint(x: 0, y: bottom)); scroll.reflectScrolledClipView(scroll.contentView)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
            try save(short, to: directory.appendingPathComponent("menu-short-bottom.png"))
        } else { checks["ui.shortPopoverScrolls"] = false }
        shortWindow.orderOut(nil); shortWindow.contentView = nil
        let screens = [CGRect(x: 0, y: 24, width: 683, height: 340), CGRect(x: 0, y: 24, width: 1366, height: 700), CGRect(x: -1920, y: -100, width: 1920, height: 1000)]
        checks["ui.popoverFitsSmallAndSecondaryScreens"] = screens.allSatisfy { screen in
            let height = SnowPopoverLayout.contentHeight(visibleFrame: screen, anchor: CGRect(x: screen.maxX - 90, y: screen.maxY, width: 22, height: 22))
            let proposed = CGRect(x: screen.maxX - 150, y: screen.maxY - height, width: SnowPopoverLayout.width + 28, height: height + 32)
            return screen.insetBy(dx: 6, dy: 6).contains(SnowPopoverLayout.constrain(proposed, to: screen))
        }
        store.selectLanguage(.english); store.selectedPane = .snow
        let english = NSHostingView(rootView: SettingsView(store: store))
        let englishWindow = prepare(english, size: CGSize(width: 1040, height: 660))
        try save(english, to: directory.appendingPathComponent("snow-en.png"))
        englishWindow.orderOut(nil); englishWindow.contentView = nil
        return checks
    }
    private static func prepare(_ view: NSView, size: CGSize) -> NSWindow {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view; view.setFrameSize(size)
        window.orderFront(nil); view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        view.layoutSubtreeIfNeeded()
        return window
    }
    private static func save(_ view: NSView, to url: URL) throws {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ImportFailure.invalidImage }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw ImportFailure.invalidImage }
        try data.write(to: url, options: .atomic)
    }
    private static func sliders(in view: NSView) -> [NSSlider] {
        (view as? NSSlider).map { [$0] } ?? view.subviews.flatMap { sliders(in: $0) }
    }
    private static func descendants<T: NSView>(in view: NSView, of type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(in: $0, of: type) }
    }
    private static func choose(_ title: String, in identifier: String, view: NSView) -> Bool {
        guard let button = descendants(in: view, of: SnowPopupButton.self).first(where: { $0.identifier?.rawValue == identifier }),
              button.isEnabled, let item = button.menu?.items.first(where: { !$0.isHidden && $0.title == title }), let action = item.action else { return false }
        let sent = NSApp.sendAction(action, to: item.target, from: item)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
        return sent && button.displayTitle == title
    }
}

struct SettingsPreview: View {
    @ObservedObject var store: SettingsStore
    var compact = false
    var body: some View {
        Image(nsImage: SettingsPreviewArt.image(settings: store.value, pane: compact ? .snow : store.activePane, compact: compact, tree: store.treeShown, availableDisplays: store.displayList.map(\.id)))
            .resizable().interpolation(.high)
            .aspectRatio(compact ? 3.5 : 0.80, contentMode: .fit)
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 18))
            .overlay(RoundedRectangle(cornerRadius: compact ? 16 : 18).strokeBorder(.white.opacity(0.27), lineWidth: 1))
            .accessibilityLabel(tr("ui.preview"))
    }
}

/// Small, cached stills reuse the application's own SpriteKit artwork. There is
/// no second simulation, timer, screenshot capture or background render loop.
@MainActor
enum SettingsPreviewArt {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>(); cache.countLimit = 12; return cache
    }()
    static func image(settings: SnowSettings, pane: SettingsPane, compact: Bool, tree: Bool, availableDisplays: [UInt32]) -> NSImage {
        let bytes = (try? JSONEncoder().encode(settings)) ?? Data()
        let key = "\(pane.rawValue)-\(compact)-\(tree)-\(availableDisplays)-" + bytes.base64EncodedString()
        if let cached = cache.object(forKey: key as NSString) { return cached }
        let size = CGSize(width: 280, height: compact ? 80 : 350)
        let scene = SKScene(size: size); scene.backgroundColor = SnowArt.color(0x26272C)
        let dots = CGMutablePath()
        for x in stride(from: CGFloat(8), to: size.width, by: 14) {
            for y in stride(from: CGFloat(8), to: size.height, by: 14) {
                dots.addEllipse(in: CGRect(x: x, y: y, width: 1.8, height: 1.8))
            }
        }
        let grid = SKShapeNode(path: dots); grid.fillColor = SnowArt.color(0x54565D); grid.strokeColor = .clear; grid.alpha = 0.5
        scene.addChild(grid)
        let count = compact ? 9 : (settings.weather == .light ? 24 : (settings.weather == .steady ? 42 : 72))
        for index in 0..<count {
            let x = CGFloat((index * 83 + 31) % 271) + 4
            let y = CGFloat((index * 59 + 21) % Int(size.height - 15)) + 15
            let patterned = settings.snowflakeStyle == .patterned && index % 5 == 0
            let sprite = SKSpriteNode(texture: patterned ? SnowflakeArt.texture(variant: index % 8) : SnowflakeArt.simpleTexture)
            let diameter = CGFloat(patterned ? 14 : (index % 4 == 0 ? 3.5 : 2)) * CGFloat(settings.snowflakeSize)
            sprite.size = CGSize(width: diameter, height: diameter); sprite.position = CGPoint(x: x, y: y)
            sprite.alpha = index % 3 == 0 ? 0.95 : 0.55; sprite.zPosition = 2
            scene.addChild(sprite)
            if pane == .wind && abs(settings.wind) > 5 {
                let tail = CGMutablePath(); tail.move(to: CGPoint(x: x, y: y))
                tail.addLine(to: CGPoint(x: x - CGFloat(settings.wind) * 0.12, y: y + 8))
                let trail = SKShapeNode(path: tail); trail.strokeColor = .white.withAlphaComponent(0.13); trail.lineWidth = 0.7; scene.addChild(trail)
            }
        }
        let floorHeight = CGFloat(settings.accumulateAtBottom ? min(30, settings.bottomHeight * 0.42) : 0)
        if !compact {
            if pane == .play { addSnowman(to: scene, floorHeight: floorHeight, appearance: settings.snowAppearance) }
            else if pane == .cleaner {
                let tractor = TractorArt.make(settings.cleaner, blade: nil)
                tractor.position = CGPoint(x: 135, y: max(10, floorHeight - 3)); tractor.setScale(1.1); tractor.zPosition = 4
                scene.addChild(tractor)
            } else if pane == .displays { addDisplays(to: scene, settings: settings, availableDisplays: availableDisplays) }
            else {
                let rect = CGRect(x: 42, y: 115, width: 196, height: 119)
                let window = SnowArt.rect(rect, color: SnowArt.color(0x292B33), radius: 10, in: scene)
                window.strokeColor = SnowArt.color(0x737681); window.lineWidth = 1
                let rule = SnowArt.rect(CGRect(x: 43, y: 210, width: 194, height: 0.6), color: SnowArt.color(0x636570), in: scene); rule.alpha = 0.6
                for i in 0..<3 { SnowArt.circle(CGPoint(x: 56 + CGFloat(i) * 12, y: 222), radius: 3.5, color: SnowArt.color(0xA5A8B5), in: scene) }
                if settings.accumulateOnWindows {
                    addSnow(width: 196, height: CGFloat(settings.windowHeight * 0.52), origin: CGPoint(x: 42, y: 233), appearance: settings.snowAppearance, in: scene)
                }
                if pane == .accumulation && settings.accumulateOnDock {
                    let dock = SnowArt.rect(CGRect(x: 67, y: 8, width: 146, height: 28), color: SnowArt.color(0x484B57), radius: 10, in: scene)
                    dock.strokeColor = SnowArt.color(0x8A8D98); dock.lineWidth = 0.7
                    for i in 0..<4 { SnowArt.rect(CGRect(x: 79 + CGFloat(i) * 33, y: 14, width: 23, height: 19), color: SnowArt.color(0x747986), radius: 4, in: scene) }
                }
            }
            if pane == .garlands || tree {
                var value = settings
                if tree && pane != .garlands { value.garland = .off }
                let garland = ScreenGarlandRenderer(); garland.configure(size: size, settings: value)
                garland.animate(time: 1.5, settings: value, reduceMotion: false)
                scene.addChild(garland.root)
            }
        }
        if floorHeight > 0 { addSnow(width: size.width, height: compact ? 7 : floorHeight, origin: .zero, appearance: settings.snowAppearance, in: scene) }
        let content = SKNode()
        for child in scene.children { child.removeFromParent(); content.addChild(child) }
        content.setScale(2); scene.addChild(content)
        let pixels = CGSize(width: size.width * 2, height: size.height * 2)
        scene.size = pixels
        let renderer = SKView(frame: CGRect(origin: .zero, size: pixels))
        renderer.presentScene(scene)
        let texture = renderer.texture(from: scene, crop: CGRect(origin: .zero, size: pixels))
        let image = texture.map { NSImage(cgImage: $0.cgImage(), size: size) } ?? NSImage(size: size)
        renderer.presentScene(nil)
        cache.setObject(image, forKey: key as NSString)
        return image
    }
    private static func addSnow(width: CGFloat, height: CGFloat, origin: CGPoint, appearance: SnowAppearance, in scene: SKScene) {
        let surface = SnowSurface(id: 1, frame: CGRect(x: origin.x, y: origin.y, width: width, height: 20), visible: [.init(0, width)], isBottom: true)
        var profile = SnowProfile(width: width, maximum: max(4, height), variationSeed: 42)
        for x in stride(from: CGFloat(0), through: width, by: 3) { profile.deposit(at: x, amount: 100) }
        let path = SnowContour.path(surface: surface, profile: profile, span: .init(0, width))
        let snow = SKShapeNode(path: path); snow.fillColor = SnowArt.color(0xE3E5ED); snow.strokeColor = .white.withAlphaComponent(0.8); snow.lineWidth = 0.6; snow.zPosition = 5
        scene.addChild(snow)
        if appearance == .textured {
            for i in 0..<Int(width / 2) {
                let dot = SnowArt.circle(CGPoint(x: origin.x + CGFloat(i) * 2, y: origin.y + CGFloat((i * 13) % max(1, Int(height))) * 0.75), radius: i % 3 == 0 ? 0.7 : 0.4, color: .white.withAlphaComponent(0.5), in: scene)
                dot.zPosition = 6
            }
        }
    }
    private static func addSnowman(to scene: SKScene, floorHeight: CGFloat, appearance: SnowAppearance) {
        let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: scene.size), visible: [.init(0, scene.size.width)], isBottom: true)
        var balls: [Snowball] = []; var top = max(15, floorHeight)
        for (index, radius) in [CGFloat(31), 22, 15].enumerated() {
            let id = UInt64(8_000_000 + index)
            var ball = Snowball(id: id, radius: radius, position: CGPoint(x: 140, y: top + radius))
            ball.surfaceID = floor.id; ball.localX = 140; ball.anchorHeight = top + radius
            ball.supportID = index == 0 ? nil : id - 1; balls.append(ball); top += radius * 1.84
        }
        let game = SnowGame(balls: balls, variantCycle: SnowmanVariantCycle(start: SnowmanVariant.classicBucket.rawValue)), renderer = SnowDecorationRenderer()
        renderer.drawGame(game, surfaces: [floor], reduceMotion: true, appearance: appearance)
        scene.addChild(renderer.root)
    }
    private static func addDisplays(to scene: SKScene, settings: SnowSettings, availableDisplays: [UInt32]) {
        let displays = Array(availableDisplays.prefix(3))
        for (index, id) in displays.enumerated() {
            let symbol = "display"
            guard let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { continue }
            let image = NSImage(size: CGSize(width: 130, height: 95), flipped: false) { rect in
                source.draw(in: rect)
                NSColor.white.setFill(); rect.fill(using: .sourceAtop)
                return true
            }
            let node = SKSpriteNode(texture: SKTexture(image: image))
            node.color = SnowArt.color(0xC1C5D2); node.colorBlendFactor = 1
            node.size = CGSize(width: 130, height: 95)
            node.position = displays.count == 1 ? CGPoint(x: 140, y: 180) : CGPoint(x: [CGFloat(85), 190, 140][index], y: [CGFloat(130), 200, 270][index])
            node.alpha = settings.allDisplays || settings.displayIDs.contains(id) ? 0.9 : 0.25
            node.zPosition = 3; scene.addChild(node)
        }
    }
}
