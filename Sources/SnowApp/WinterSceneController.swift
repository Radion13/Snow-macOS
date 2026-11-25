import AppKit
import SpriteKit

/// Original procedural artwork. Only this app's scene is rendered; the wallpaper is untouched.
final class WinterIllustration: SKScene {
    var motionEnabled = true
    private var clock = SimulationClock()
    private var elapsed: Double = 0
    private var smoke: [SKShapeNode] = []
    private var lights: [SKShapeNode] = []
    private var smokeOrigin = CGPoint.zero
    init(size: CGSize, kind: WinterScene) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SnowArt.color(0x152C42)
        SnowArt.rect(CGRect(origin: .zero, size: size), color: backgroundColor, in: self).zPosition = -1
        let art = SKNode(); let scale = max(size.width / 1440, size.height / 900)
        art.setScale(scale); art.position = CGPoint(x: (size.width - 1440 * scale) / 2, y: (size.height - 900 * scale) / 2)
        addChild(art)
        for index in 0..<90 {
            let x = CGFloat((index * 337 + 97) % 1440), y = CGFloat(360 + (index * 173) % 520)
            SnowArt.circle(CGPoint(x: x, y: y), radius: index % 5 == 0 ? 1.5 : 0.8,
                           color: NSColor.white.withAlphaComponent(CGFloat(0.15 + Double(index % 6) / 14)), in: art)
        }
        SnowArt.circle(CGPoint(x: 1110, y: 714), radius: 49, color: SnowArt.color(0xBFD2D6), in: art)
        SnowArt.circle(CGPoint(x: 1127, y: 730), radius: 43, color: SnowArt.color(0x152C42), in: art)
        SnowArt.polygon([.init(x: 0, y: 250), .init(x: 170, y: 580), .init(x: 370, y: 360), .init(x: 600, y: 650),
                         .init(x: 850, y: 370), .init(x: 1170, y: 590), .init(x: 1440, y: 310), .init(x: 1440, y: 0), .zero], color: SnowArt.color(0x284359), in: art)
        for index in 0..<28 {
            let x = CGFloat(index) * 58 - 50
            tree(at: CGPoint(x: x, y: 170 + CGFloat(index % 3) * 12), height: 170 + CGFloat((index * 47) % 120), in: art)
        }
        let hill = CGMutablePath(); hill.move(to: .zero); hill.addLine(to: CGPoint(x: 0, y: 205))
        hill.addCurve(to: CGPoint(x: 1440, y: 190), control1: CGPoint(x: 500, y: 330), control2: CGPoint(x: 1000, y: 90))
        hill.addLine(to: CGPoint(x: 1440, y: 0)); hill.closeSubpath()
        let ground = SKShapeNode(path: hill); ground.fillColor = SnowArt.color(0xB4CBD8); ground.strokeColor = .clear; art.addChild(ground)
        if kind == .porch { porch(in: art) } else { cabin(in: art) }
        for index in 0..<8 {
            let node = SKShapeNode(circleOfRadius: CGFloat(9 + index * 2))
            node.fillColor = NSColor.white.withAlphaComponent(0.12); node.strokeColor = .clear
            node.position = smokeOrigin; node.alpha = 0
            art.addChild(node); smoke.append(node)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private func tree(at point: CGPoint, height: CGFloat, in parent: SKNode) {
        SnowArt.rect(CGRect(x: point.x - 5, y: point.y, width: 10, height: height * 0.6), color: SnowArt.color(0x2D3C40), in: parent)
        for level in 0..<3 {
            let base = point.y + height * CGFloat(level) * 0.19
            let halfWidth = height * (0.28 - CGFloat(level) * 0.045)
            SnowArt.polygon([.init(x: point.x - halfWidth, y: base), .init(x: point.x, y: base + height * 0.62), .init(x: point.x + halfWidth, y: base)], color: SnowArt.color(0x183D44), in: parent)
            SnowArt.polygon([.init(x: point.x - halfWidth * 0.6, y: base + height * 0.25), .init(x: point.x, y: base + height * 0.62), .init(x: point.x + halfWidth * 0.6, y: base + height * 0.25)], color: SnowArt.color(0x9AB9C6), in: parent)
        }
    }
    private func window(_ rect: CGRect, in parent: SKNode) {
        let glass = SnowArt.rect(rect, color: SnowArt.color(0xF0C178), radius: 2, in: parent); lights.append(glass)
        SnowArt.rect(CGRect(x: rect.midX - 2, y: rect.minY, width: 4, height: rect.height), color: SnowArt.color(0x604D43), in: parent)
        SnowArt.rect(CGRect(x: rect.minX, y: rect.midY - 2, width: rect.width, height: 4), color: SnowArt.color(0x604D43), in: parent)
        SnowArt.rect(CGRect(x: rect.minX - 4, y: rect.minY - 4, width: rect.width + 8, height: 5), color: SnowArt.color(0xD4E3E7), radius: 2, in: parent)
    }
    private func cabin(in parent: SKNode) {
        SnowArt.rect(CGRect(x: 490, y: 190, width: 410, height: 215), color: SnowArt.color(0x665044), radius: 4, in: parent)
        for y in stride(from: 205, to: 400, by: 18) { SnowArt.rect(CGRect(x: 490, y: y, width: 410, height: 3), color: SnowArt.color(0x463F3B), in: parent) }
        SnowArt.rect(CGRect(x: 800, y: 420, width: 38, height: 120), color: SnowArt.color(0x746B66), in: parent)
        SnowArt.polygon([.init(x: 450, y: 390), .init(x: 695, y: 570), .init(x: 940, y: 390)], color: SnowArt.color(0x253947), in: parent)
        SnowArt.polygon([.init(x: 441, y: 410), .init(x: 695, y: 581), .init(x: 949, y: 410), .init(x: 920, y: 399), .init(x: 695, y: 551), .init(x: 470, y: 399)], color: SnowArt.color(0xD6E3E9), in: parent)
        SnowArt.rect(CGRect(x: 660, y: 192, width: 75, height: 137), color: SnowArt.color(0x354448), radius: 3, in: parent)
        SnowArt.circle(CGPoint(x: 722, y: 255), radius: 3, color: SnowArt.color(0xE5BF77), in: parent)
        window(CGRect(x: 530, y: 265, width: 78, height: 80), in: parent)
        window(CGRect(x: 790, y: 265, width: 78, height: 80), in: parent)
        SnowArt.rect(CGRect(x: 635, y: 181, width: 123, height: 13), color: SnowArt.color(0xDDE6E9), radius: 4, in: parent)
        tree(at: CGPoint(x: 360, y: 150), height: 380, in: parent)
        tree(at: CGPoint(x: 1050, y: 150), height: 420, in: parent)
        smokeOrigin = CGPoint(x: 819, y: 545)
    }
    private func porch(in parent: SKNode) {
        SnowArt.rect(CGRect(x: 300, y: 140, width: 840, height: 620), color: SnowArt.color(0x695448), in: parent)
        for x in stride(from: 300, to: 1140, by: 60) { SnowArt.rect(CGRect(x: x, y: 140, width: 4, height: 620), color: SnowArt.color(0x51473F), in: parent) }
        SnowArt.rect(CGRect(x: 580, y: 170, width: 270, height: 440), color: SnowArt.color(0x263F46), radius: 4, in: parent)
        SnowArt.rect(CGRect(x: 604, y: 195, width: 222, height: 389), color: SnowArt.color(0x36515A), radius: 3, in: parent)
        SnowArt.circle(CGPoint(x: 804, y: 350), radius: 6, color: SnowArt.color(0xD9B373), in: parent)
        let wreath = SKShapeNode(circleOfRadius: 46); wreath.position = CGPoint(x: 715, y: 475)
        wreath.strokeColor = SnowArt.color(0x2B6852); wreath.lineWidth = 22; wreath.fillColor = .clear; parent.addChild(wreath)
        for index in 0..<10 {
            let angle = Double(index) * .pi / 5
            SnowArt.circle(CGPoint(x: 715 + cos(angle) * 46, y: 475 + sin(angle) * 46), radius: 5, color: SnowArt.color(0xC65D49), in: parent)
        }
        window(CGRect(x: 370, y: 370, width: 130, height: 150), in: parent)
        window(CGRect(x: 930, y: 370, width: 130, height: 150), in: parent)
        SnowArt.polygon([.init(x: 240, y: 685), .init(x: 710, y: 848), .init(x: 1200, y: 685)], color: SnowArt.color(0xD4E4EA), in: parent)
        for (index, width) in [440, 540, 640].enumerated() {
            SnowArt.rect(CGRect(x: 720 - width / 2, y: 140 - index * 32, width: width, height: 28), color: SnowArt.color(0xC4D9E0), radius: 4, in: parent)
        }
        tree(at: CGPoint(x: 260, y: 110), height: 390, in: parent)
        tree(at: CGPoint(x: 1180, y: 110), height: 350, in: parent)
        smokeOrigin = CGPoint(x: 1160, y: 815)
    }
    override func update(_ currentTime: TimeInterval) {
        let dt = clock.advance(to: currentTime)
        if motionEnabled { elapsed += dt }
        for (index, node) in smoke.enumerated() {
            let phase = (elapsed * 0.14 + Double(index) / 8).truncatingRemainder(dividingBy: 1)
            node.position = CGPoint(x: smokeOrigin.x + phase * 60 + sin(phase * 8) * 10, y: smokeOrigin.y + phase * 100)
            node.alpha = CGFloat((1 - phase) * 0.7); node.setScale(CGFloat(0.5 + phase))
        }
        for (index, node) in lights.enumerated() { node.alpha = CGFloat(0.94 + 0.06 * sin(elapsed * 0.7 + Double(index))) }
    }
}

final class WinterSceneController {
    private(set) var window: NSWindow?
    private var view: SKView?
    private var kind = WinterScene.none
    func configure(kind: WinterScene, frame: CGRect, reduceMotion: Bool) {
        if kind == .none { close(); return }
        if self.kind != kind || window?.frame != frame {
            close(); self.kind = kind
            let window = SnowOverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.isOpaque = true; window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenNone]
            window.isExcludedFromWindowsMenu = true
            let view = SKView(frame: CGRect(origin: .zero, size: frame.size)); view.ignoresSiblingOrder = true
            view.presentScene(WinterIllustration(size: frame.size, kind: kind)); window.contentView = view
            self.window = window; self.view = view; window.orderFrontRegardless()
        }
        (view?.scene as? WinterIllustration)?.motionEnabled = !reduceMotion
        view?.preferredFramesPerSecond = reduceMotion ? 1 : 15
    }
    func apply(_ state: PauseState) {
        view?.isPaused = state.isPaused
        if state.isHidden { window?.orderOut(nil) }
        else if window?.isVisible == false { window?.orderFrontRegardless() }
    }
    func close() { view?.isPaused = true; view?.presentScene(nil); window?.close(); window = nil; view = nil; kind = .none }
}
