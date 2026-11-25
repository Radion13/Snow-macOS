import AppKit
import SpriteKit

enum SnowArt {
    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        .init(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
              blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
    @discardableResult static func rect(_ rect: CGRect, color: NSColor, radius: CGFloat = 0, in parent: SKNode) -> SKShapeNode {
        let node = SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = color; node.strokeColor = .clear; parent.addChild(node); return node
    }
    @discardableResult static func circle(_ center: CGPoint, radius: CGFloat, color: NSColor, in parent: SKNode) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = center; node.fillColor = color; node.strokeColor = .clear; parent.addChild(node); return node
    }
    @discardableResult static func polygon(_ points: [CGPoint], color: NSColor, in parent: SKNode) -> SKShapeNode {
        let path = CGMutablePath(); path.addLines(between: points); path.closeSubpath()
        let node = SKShapeNode(path: path); node.fillColor = color; node.strokeColor = .clear; parent.addChild(node); return node
    }
    static func cleaner(_ character: CleanerCharacter, blade: NSImage?) -> SKNode {
        TractorArt.make(character, blade: blade)
    }
}

final class SnowDecorationRenderer {
    let root = SKNode()
    var windows: [WindowSnapshot] = []
    private var balls: [UInt64: (SKCropNode, CGFloat, Bool, Bool, SnowAppearance)] = [:]
    private var impactNodes: [UInt64: SKSpriteNode] = [:]
    private let cleaner = SKNode()
    private var cleanerSignature = ""
    private var bladeImage: NSImage?
    private var rearWheel: SKNode?
    private var frontWheel: SKNode?
    private var bucketSnow: SKNode?
    let screenGarland = ScreenGarlandRenderer()
    init() { root.zPosition = 5; root.addChild(cleaner); screenGarland.root.zPosition = 70; root.addChild(screenGarland.root); reloadAssets() }
    func reloadAssets() {
        bladeImage = SnowAppFeatures.bladeImages ? ImportedAssets.image(for: .blade) : nil
        cleanerSignature = ""
    }
    func drawGame(_ game: SnowGame, surfaces: [SnowSurface], reduceMotion: Bool = false, appearance: SnowAppearance = .simple) {
        let heads = Set(game.snowmen.compactMap(\.last))
        let ids = Set(game.balls.map(\.id))
        for id in balls.keys where !ids.contains(id) { balls.removeValue(forKey: id)?.0.removeFromParent() }
        for ball in game.balls {
            let head = heads.contains(ball.id)
            if balls[ball.id] == nil || abs(balls[ball.id]!.1 - ball.radius) > 0.15 || balls[ball.id]!.2 != head || balls[ball.id]!.3 != ball.isLooseSnow || balls[ball.id]!.4 != appearance {
                balls.removeValue(forKey: ball.id)?.0.removeFromParent()
                let crop = SKCropNode(); let art = SKNode(); crop.addChild(art)
                if appearance == .textured {
                    let snow = SKSpriteNode(texture: SnowMaterialArt.ballTexture(loose: ball.isLooseSnow))
                    snow.name = "snow.ball.material"
                    snow.size = CGSize(width: ball.radius * SnowMaterialArt.ballExtent, height: ball.radius * SnowMaterialArt.ballExtent)
                    art.addChild(snow)
                } else {
                    let snow = SnowArt.circle(.zero, radius: ball.radius, color: SnowArt.color(0xEDF5F7), in: art)
                    snow.strokeColor = SnowArt.color(0xA1BDCC); snow.lineWidth = 0.8
                    if ball.isLooseSnow {
                        for offset: CGPoint in [.init(x: -0.6, y: 0), .init(x: 0.5, y: 0.2), .init(x: 0.1, y: 0.6), .init(x: 0.1, y: -0.5)] {
                            SnowArt.circle(CGPoint(x: offset.x * ball.radius, y: offset.y * ball.radius), radius: ball.radius * 0.55,
                                           color: .white, in: art).zPosition = 1
                        }
                    }
                    SnowArt.circle(CGPoint(x: -ball.radius * 0.25, y: ball.radius * 0.22), radius: ball.radius * 0.65,
                                   color: NSColor.white.withAlphaComponent(0.6), in: art).zPosition = ball.isLooseSnow ? 2 : 1
                }
                if head {
                    if appearance == .textured {
                        let r = ball.radius
                        let scarf = SKNode(); scarf.name = "snowman.scarf"; scarf.zPosition = 3
                        let tail = SKNode(); tail.name = "snowman.scarf.tail"
                        tail.position = CGPoint(x: -r * 0.30, y: -r * 0.91); scarf.addChild(tail)
                        SnowArt.rect(CGRect(x: -r * 0.14, y: -r * 0.75, width: r * 0.28, height: r * 0.86),
                                     color: SnowArt.color(0xDF4C4F), radius: r * 0.04, in: tail)
                        for y: CGFloat in [-0.48, -0.61] {
                            SnowArt.rect(CGRect(x: -r * 0.14, y: r * y, width: r * 0.28, height: r * 0.06),
                                         color: SnowArt.color(0xF4DDCC), in: tail).zPosition = 1
                        }
                        let band = CGMutablePath()
                        band.move(to: CGPoint(x: -r * 0.78, y: -r * 0.72))
                        band.addCurve(to: CGPoint(x: r * 0.78, y: -r * 0.72),
                                      control1: CGPoint(x: -r * 0.30, y: -r * 0.84), control2: CGPoint(x: r * 0.30, y: -r * 0.84))
                        band.addCurve(to: CGPoint(x: r * 0.72, y: -r * 0.96),
                                      control1: CGPoint(x: r * 0.90, y: -r * 0.77), control2: CGPoint(x: r * 0.86, y: -r * 0.93))
                        band.addCurve(to: CGPoint(x: -r * 0.72, y: -r * 0.96),
                                      control1: CGPoint(x: r * 0.25, y: -r * 1.08), control2: CGPoint(x: -r * 0.25, y: -r * 1.08))
                        band.addCurve(to: CGPoint(x: -r * 0.78, y: -r * 0.72),
                                      control1: CGPoint(x: -r * 0.86, y: -r * 0.93), control2: CGPoint(x: -r * 0.90, y: -r * 0.77))
                        band.closeSubpath()
                        let collar = SKShapeNode(path: band); collar.name = "snowman.scarf.collar"
                        collar.fillColor = SnowArt.color(0xBD343B); collar.strokeColor = .clear
                        collar.zPosition = 1; scarf.addChild(collar)
                        SnowArt.circle(CGPoint(x: -r * 0.30, y: -r * 0.90), radius: r * 0.15,
                                       color: SnowArt.color(0xD43F46), in: scarf).zPosition = 2
                        art.addChild(scarf)
                    }
                    let bucket = SKNode(); bucket.name = "snowman.bucket"
                    bucket.zPosition = 4
                    bucket.position.y = ball.radius * 0.78; bucket.zRotation = -0.1
                    let r = ball.radius
                    let body = SnowArt.polygon([.init(x: -r * 0.82, y: 0), .init(x: r * 0.82, y: 0),
                                                .init(x: r * 0.58, y: r * 0.95), .init(x: -r * 0.58, y: r * 0.95)],
                                               color: SnowArt.color(0x809EAE), in: bucket)
                    body.strokeColor = SnowArt.color(0x405B6B); body.lineWidth = 0.8
                    SnowArt.polygon([.init(x: -r * 0.62, y: r * 0.12), .init(x: -r * 0.32, y: r * 0.12),
                                     .init(x: -r * 0.27, y: r * 0.82), .init(x: -r * 0.45, y: r * 0.82)],
                                    color: SnowArt.color(0xCEE0E6), in: bucket)
                    SnowArt.rect(CGRect(x: -r * 0.9, y: -r * 0.04, width: r * 1.8, height: max(2, r * 0.13)),
                                 color: SnowArt.color(0xB3CAD4), radius: 1, in: bucket)
                    // Only the exposed side of the handle is drawn. Its ends
                    // sit behind the opaque bucket, even with sibling batching.
                    let handlePath = CGMutablePath()
                    handlePath.move(to: CGPoint(x: -r * 0.50, y: r * 0.76))
                    handlePath.addCurve(to: CGPoint(x: -r * 0.62, y: r * 0.10),
                                        control1: CGPoint(x: -r * 1.03, y: r * 1.05),
                                        control2: CGPoint(x: -r * 1.08, y: r * 0.08))
                    let handle = SKShapeNode(path: handlePath); handle.name = "snowman.bucket.handle"
                    handle.zPosition = -1; handle.strokeColor = SnowArt.color(0x405B6B)
                    handle.lineWidth = 1; handle.fillColor = .clear; bucket.addChild(handle)
                    art.addChild(bucket)
                    // The production view batches equal-depth sprites/shapes.
                    // Explicit depth keeps the face above both snow materials.
                    let face = SKNode(); face.name = "snowman.face"; face.zPosition = 5; art.addChild(face)
                    for x: CGFloat in [-0.28, 0.28] {
                        let eye = SnowArt.circle(CGPoint(x: x * r, y: r * 0.25), radius: max(1.4, r * 0.08), color: SnowArt.color(0x293F4A), in: face)
                        eye.name = x < 0 ? "snowman.eye.left" : "snowman.eye.right"
                    }
                    let nose = SnowArt.polygon([.init(x: -r * 0.06, y: r * 0.06), .init(x: r * 0.82, y: -r * 0.04),
                                               .init(x: -r * 0.06, y: -r * 0.23)], color: SnowArt.color(0xDA833C), in: face)
                    nose.name = "snowman.nose"; nose.zPosition = 1
                    for x: CGFloat in [-0.32, -0.16, 0, 0.16, 0.32] {
                        let mouth = SnowArt.circle(CGPoint(x: x * r, y: r * (-0.44 + abs(x) * 0.3125)), radius: max(0.8, r * 0.055), color: SnowArt.color(0x293F4A), in: face)
                        mouth.name = "snowman.mouth"
                    }
                } else if !ball.isLooseSnow {
                    let marker = SnowArt.circle(CGPoint(x: 0, y: -2), radius: 1.6, color: SnowArt.color(0x405A68), in: art)
                    marker.name = "snow.ball.centerMarker"; marker.zPosition = 3; marker.alpha = 0
                }
                root.addChild(crop); balls[ball.id] = (crop, ball.radius, head, ball.isLooseSnow, appearance)
            }
            guard let node = balls[ball.id]?.0 else { continue }
            node.position = ball.position
            node.setScale(reduceMotion ? 1 : ball.approachScale)
            node.zPosition = ball.glassFlight == nil ? (head ? 2 : 0) : 80
            let surface = surfaces.first { $0.id == ball.surfaceID }
            node.isHidden = ball.surfaceID != nil && (surface == nil || !surface!.visible.contains { $0.contains(ball.localX) })
            let scarfDepth: CGFloat = head && appearance == .textured ? ball.radius * 0.65 : 0
            let bounds = CGRect(x: ball.position.x - ball.radius - 2, y: ball.position.y - ball.radius - 2 - scarfDepth,
                                width: ball.radius * 2 + 4, height: ball.radius * (head ? 2.9 : 2) + 4 + scarfDepth)
            let visible = ball.surfaceID.map { SurfaceGeometry.visibleParts(of: bounds, on: $0, windows: windows) } ?? [bounds]
            let path = CGMutablePath()
            for rect in visible { path.addRect(rect.offsetBy(dx: -ball.position.x, dy: -ball.position.y)) }
            let mask = (node.maskNode as? SKShapeNode) ?? SKShapeNode()
            mask.path = path; mask.fillColor = .white; mask.strokeColor = .clear; node.maskNode = mask
        }
        let liveImpacts = Set(game.impacts.map(\.id))
        for id in impactNodes.keys where !liveImpacts.contains(id) { impactNodes.removeValue(forKey: id)?.removeFromParent() }
        for impact in game.impacts {
            if impactNodes[impact.id] == nil {
                let sprite = SKSpriteNode(texture: SnowImpactArt.texture(variant: impact.variant))
                sprite.name = "snow.impact"; sprite.zPosition = 85; root.addChild(sprite); impactNodes[impact.id] = sprite
            }
            let sprite = impactNodes[impact.id]!
            sprite.position = impact.position
            sprite.size = CGSize(width: impact.radius * SnowImpactArt.textureExtent, height: impact.radius * SnowImpactArt.textureExtent)
            sprite.alpha = impact.opacity; sprite.setScale(reduceMotion ? 1 : impact.spread)
        }
    }
    func drawCleaner(_ model: SnowCleaner, settings: SnowSettings) {
        cleaner.isHidden = model.x == nil
        guard let x = model.x else { return }
        let useBladeImage = SnowAppFeatures.bladeImages && settings.useBladeImage
        let signature = model.character.rawValue + String(useBladeImage)
        if cleanerSignature != signature {
            cleaner.removeAllChildren()
            cleaner.addChild(SnowArt.cleaner(model.character, blade: useBladeImage ? bladeImage : nil))
            rearWheel = cleaner.childNode(withName: "//cleaner.wheel.rear")
            frontWheel = cleaner.childNode(withName: "//cleaner.wheel.front")
            bucketSnow = cleaner.childNode(withName: "//cleaner.bucket.snow")
            cleanerSignature = signature
        }
        cleaner.position = CGPoint(x: x, y: 0)
        let reduceMotion = settings.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        rearWheel?.zRotation = reduceMotion ? 0 : CleanerGeometry.wheelRotation(distance: model.travelled, radius: CleanerGeometry.rearWheelRadius)
        frontWheel?.zRotation = reduceMotion ? 0 : CleanerGeometry.wheelRotation(distance: model.travelled, radius: CleanerGeometry.frontWheelRadius)
        bucketSnow?.isHidden = model.snowLoad <= 0
        bucketSnow?.yScale = 0.25 + model.snowLoad * 0.75
    }
    func configureGarland(size: CGSize, settings: SnowSettings) {
        screenGarland.configure(size: size, settings: settings)
    }
    func animateGarland(time: Double, settings: SnowSettings, reduceMotion: Bool) {
        screenGarland.animate(time: time, settings: settings, reduceMotion: reduceMotion)
    }
}
