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
    private var ballVariants: [UInt64: SnowmanVariant] = [:]
    private var ballBounds: [UInt64: CGRect] = [:]
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
        let variants = game.snowmanVariants()
        let groups = Dictionary(uniqueKeysWithValues: game.snowmen.compactMap { group -> (UInt64, [UInt64])? in
            guard let head = group.last else { return nil }; return (head, group)
        })
        let heads = Set(variants.keys), ids = Set(game.balls.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: game.balls.map { ($0.id, $0) })
        for id in balls.keys where !ids.contains(id) {
            balls.removeValue(forKey: id)?.0.removeFromParent()
            ballVariants.removeValue(forKey: id); ballBounds.removeValue(forKey: id)
        }
        for ball in game.balls {
            let head = heads.contains(ball.id), variant = variants[ball.id]
            if balls[ball.id] == nil || abs(balls[ball.id]!.1 - ball.radius) > 0.15 || balls[ball.id]!.2 != head ||
                balls[ball.id]!.3 != ball.isLooseSnow || balls[ball.id]!.4 != appearance || ballVariants[ball.id] != variant {
                balls.removeValue(forKey: ball.id)?.0.removeFromParent()
                let crop = SKCropNode(), art = SKNode(); crop.addChild(art)
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
                if let variant, let group = groups[ball.id], let base = byID[group[0]], let middle = byID[group[1]] {
                    art.addChild(SnowmanArt.make(head: ball, middle: middle, base: base, variant: variant, appearance: appearance))
                } else if !ball.isLooseSnow {
                    let marker = SnowArt.circle(CGPoint(x: 0, y: -2), radius: 1.6, color: SnowArt.color(0x405A68), in: art)
                    marker.name = "snow.ball.centerMarker"; marker.zPosition = 3; marker.alpha = 0
                }
                ballBounds[ball.id] = art.calculateAccumulatedFrame().insetBy(dx: -2, dy: -2)
                ballVariants[ball.id] = variant
                root.addChild(crop); balls[ball.id] = (crop, ball.radius, head, ball.isLooseSnow, appearance)
            }
            guard let node = balls[ball.id]?.0 else { continue }
            node.position = ball.position
            node.setScale(reduceMotion ? 1 : ball.approachScale)
            node.zPosition = ball.glassFlight == nil ? (head ? 2 : 0) : 80
            let surface = surfaces.first { $0.id == ball.surfaceID }
            node.isHidden = ball.surfaceID != nil && (surface == nil || !surface!.visible.contains { $0.contains(ball.localX) })
            let local = ballBounds[ball.id] ?? CGRect(x: -ball.radius - 2, y: -ball.radius - 2, width: ball.radius * 2 + 4, height: ball.radius * 2 + 4)
            let bounds = local.offsetBy(dx: ball.position.x, dy: ball.position.y)
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
