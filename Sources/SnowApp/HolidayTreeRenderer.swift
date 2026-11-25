import AppKit
import SpriteKit

/// Original vector artwork; no bitmap, checkerboard or watermark from the reference.
final class HolidayTreeRenderer {
    let root = SKNode()
    private struct TreeNodes {
        let root = SKNode()
        var lights: [SKSpriteNode] = []
        let star: SKSpriteNode
        init(index: Int) {
            let textures = HolidayTreeRenderer.textures
            root.name = "tree.instance.\(index)"
            func sprite(_ texture: SKTexture, name: String, z: CGFloat) -> SKSpriteNode {
                let node = SKSpriteNode(texture: texture); node.name = name
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.size = HolidayTree.renderBounds.size; node.position.y = HolidayTree.renderBounds.minY
                node.zPosition = z; return node
            }
            star = sprite(textures[4], name: "tree.star", z: 0.04)
            root.addChild(sprite(textures[0], name: "tree.body", z: 0))
            for index in 0..<3 {
                let node = sprite(textures[index + 1], name: "tree.lamp", z: CGFloat(index + 1) * 0.01)
                root.addChild(node); lights.append(node)
            }
            root.addChild(star)
        }
    }
    private var trees: [TreeNodes] = []
    /// Bake the original vector art once. All five trees and every display share
    /// five small layers; the scene changes transforms and 20 light alphas only.
    private static let textures: [SKTexture] = {
        let artwork = HolidayTreeArtwork(), bounds = HolidayTree.renderBounds
        let view = SKView(frame: CGRect(origin: .zero, size: bounds.size))
        view.allowsTransparency = true; view.ignoresSiblingOrder = true
        let scene = SKScene(size: bounds.size); scene.backgroundColor = .clear
        let source = SKNode(); source.position = CGPoint(x: -bounds.minX, y: -bounds.minY); scene.addChild(source)
        view.presentScene(scene)
        let textures = ([artwork.art] + artwork.lamps + [artwork.star]).map { layer -> SKTexture in
            source.addChild(layer)
            let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: bounds.size)) ?? SKTexture()
            layer.removeFromParent(); texture.filteringMode = .linear; return texture
        }
        view.presentScene(nil); return textures
    }()
    static func vectorSVG() -> String { HolidayTreeArtwork().svg }
    static func vectorPreview() -> CGImage? {
        let bounds = HolidayTree.renderBounds, scale: CGFloat = 3
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let view = SKView(frame: CGRect(origin: .zero, size: size)); view.allowsTransparency = true
        let scene = SKScene(size: size); scene.backgroundColor = .clear
        let group = SKNode(); group.setScale(scale)
        group.position = .init(x: -bounds.minX * scale, y: -bounds.minY * scale); scene.addChild(group)
        let artwork = HolidayTreeArtwork()
        for (index, layer) in ([artwork.art] + artwork.lamps + [artwork.star]).enumerated() {
            layer.zPosition = CGFloat(index) * 10; group.addChild(layer)
        }
        view.presentScene(scene); defer { view.presentScene(nil) }
        return view.texture(from: scene, crop: CGRect(origin: .zero, size: size))?.cgImage()
    }
    init() { root.isHidden = true; root.name = "holiday.trees" }
    func draw(_ tree: HolidayTree, size: CGSize, time: Double, settings: SnowSettings, reduceMotion: Bool, ground: SnowProfile? = nil) {
        let poses = tree.appearances(in: size, ground: ground)
        root.isHidden = !tree.isVisible || poses.isEmpty
        guard !root.isHidden else { return }
        if trees.isEmpty {
            trees = (0..<HolidayTree.treeCount).map { TreeNodes(index: $0) }
            trees.forEach { root.addChild($0.root) }
        }
        var lighting = settings; lighting.garland = .twinkle
        for pose in poses {
            let nodes = trees[pose.id]
            nodes.root.position = pose.position
            nodes.root.xScale = pose.xScale; nodes.root.yScale = pose.yScale; nodes.root.alpha = pose.opacity
            for (index, light) in nodes.lights.enumerated() {
                light.alpha = pose.lightsOpacity * GarlandLighting.alpha(time: time, index: pose.id * 7 + index * 3, settings: lighting, reduceMotion: reduceMotion)
            }
            nodes.star.alpha = pose.lightsOpacity * GarlandLighting.alpha(time: time, index: 29 + pose.id * 11, settings: lighting, reduceMotion: reduceMotion)
        }
    }
}

private final class HolidayTreeArtwork {
    let art = SKNode()
    let lamps = [SKNode(), SKNode(), SKNode()]
    let star = SKNode()
    private static let colors = [0xFFB173, 0xDC4565, 0xADE3E1, 0xF4DED0, 0x739CC9].map { SnowArt.color(UInt32($0)) }

    init() { buildArt() }

    @discardableResult
    private func shape(_ path: CGPath, color: UInt32, in parent: SKNode, z: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: path); node.fillColor = SnowArt.color(color)
        node.strokeColor = .clear; node.zPosition = z; parent.addChild(node); return node
    }

    private func buildArt() {
        // A flared burgundy trunk, tucked under one continuous scalloped crown.
        let trunk = CGMutablePath(); trunk.move(to: .init(x: -12, y: 45))
        trunk.addCurve(to: .init(x: -16, y: 11), control1: .init(x: -11, y: 28), control2: .init(x: -12, y: 18))
        trunk.addLine(to: .init(x: -29, y: 2)); trunk.addQuadCurve(to: .init(x: 29, y: 2), control: .init(x: 0, y: -4))
        trunk.addLine(to: .init(x: 15, y: 12)); trunk.addCurve(to: .init(x: 12, y: 45), control1: .init(x: 11, y: 20), control2: .init(x: 11, y: 30))
        trunk.closeSubpath(); shape(trunk, color: 0x8B4953, in: art)
        SnowArt.polygon([.init(x: -29, y: 2), .init(x: -12, y: 2), .init(x: -6, y: 16)], color: SnowArt.color(0x713745), in: art).zPosition = 0.1
        SnowArt.polygon([.init(x: 2, y: 2), .init(x: 15, y: 3), .init(x: 2, y: 23)], color: SnowArt.color(0x7B3D49), in: art).zPosition = 0.1

        let crown = CGMutablePath(); crown.move(to: .init(x: 0, y: 236))
        crown.addCurve(to: .init(x: -36, y: 185), control1: .init(x: -11, y: 216), control2: .init(x: -29, y: 198))
        crown.addCurve(to: .init(x: -23, y: 181), control1: .init(x: -42, y: 175), control2: .init(x: -31, y: 179))
        crown.addCurve(to: .init(x: -49, y: 150), control1: .init(x: -34, y: 168), control2: .init(x: -47, y: 158))
        crown.addCurve(to: .init(x: -35, y: 145), control1: .init(x: -55, y: 139), control2: .init(x: -42, y: 142))
        crown.addCurve(to: .init(x: -62, y: 115), control1: .init(x: -46, y: 133), control2: .init(x: -59, y: 125))
        crown.addCurve(to: .init(x: -47, y: 110), control1: .init(x: -68, y: 104), control2: .init(x: -53, y: 107))
        crown.addCurve(to: .init(x: -78, y: 80), control1: .init(x: -60, y: 99), control2: .init(x: -74, y: 91))
        crown.addCurve(to: .init(x: -62, y: 75), control1: .init(x: -85, y: 67), control2: .init(x: -69, y: 72))
        crown.addCurve(to: .init(x: -87, y: 43), control1: .init(x: -74, y: 63), control2: .init(x: -87, y: 55))
        crown.addCurve(to: .init(x: -65, y: 38), control1: .init(x: -92, y: 28), control2: .init(x: -74, y: 32))
        crown.addCurve(to: .init(x: -49, y: 34), control1: .init(x: -66, y: 27), control2: .init(x: -55, y: 27))
        crown.addCurve(to: .init(x: -28, y: 33), control1: .init(x: -50, y: 20), control2: .init(x: -36, y: 24))
        crown.addQuadCurve(to: .init(x: -22, y: 29), control: .init(x: -25, y: 23))
        crown.addQuadCurve(to: .init(x: 2, y: 29), control: .init(x: -9, y: 17))
        crown.addCurve(to: .init(x: 18, y: 25), control1: .init(x: 8, y: 20), control2: .init(x: 15, y: 20))
        crown.addQuadCurve(to: .init(x: 27, y: 34), control: .init(x: 24, y: 26))
        crown.addCurve(to: .init(x: 48, y: 34), control1: .init(x: 38, y: 23), control2: .init(x: 50, y: 23))
        crown.addCurve(to: .init(x: 65, y: 38), control1: .init(x: 58, y: 27), control2: .init(x: 68, y: 29))
        crown.addCurve(to: .init(x: 87, y: 43), control1: .init(x: 79, y: 31), control2: .init(x: 93, y: 30))
        crown.addCurve(to: .init(x: 62, y: 75), control1: .init(x: 88, y: 55), control2: .init(x: 73, y: 63))
        crown.addCurve(to: .init(x: 78, y: 80), control1: .init(x: 71, y: 71), control2: .init(x: 84, y: 67))
        crown.addCurve(to: .init(x: 47, y: 110), control1: .init(x: 75, y: 91), control2: .init(x: 60, y: 99))
        crown.addCurve(to: .init(x: 62, y: 115), control1: .init(x: 54, y: 107), control2: .init(x: 68, y: 104))
        crown.addCurve(to: .init(x: 35, y: 145), control1: .init(x: 59, y: 126), control2: .init(x: 45, y: 135))
        crown.addCurve(to: .init(x: 49, y: 150), control1: .init(x: 43, y: 141), control2: .init(x: 55, y: 139))
        crown.addCurve(to: .init(x: 23, y: 181), control1: .init(x: 47, y: 160), control2: .init(x: 34, y: 168))
        crown.addCurve(to: .init(x: 36, y: 185), control1: .init(x: 31, y: 179), control2: .init(x: 42, y: 175))
        crown.addCurve(to: .init(x: 0, y: 236), control1: .init(x: 30, y: 198), control2: .init(x: 10, y: 219))
        crown.closeSubpath(); shape(crown, color: 0x3B886C, in: art, z: 1)

        // Sparse curved needle marks keep the flat illustration legible at 100 pt.
        for (x, y, angle) in [(CGFloat(-8), CGFloat(196), CGFloat(-0.7)), (17, 167, 0.2), (-22, 149, -0.2),
                              (28, 128, 0.5), (-40, 99, -0.3), (37, 78, 0.4), (-9, 83, 0.2), (-51, 48, -0.5), (62, 52, 0.4)] {
            let path = CGMutablePath(); path.move(to: .init(x: -2, y: 7))
            path.addCurve(to: .init(x: 0, y: -4), control1: .init(x: -9, y: -3), control2: .init(x: -6, y: -9))
            path.addQuadCurve(to: .init(x: 4, y: -5), control: .init(x: 7, y: -11))
            let mark = SKShapeNode(path: path); mark.strokeColor = SnowArt.color(0x276F54)
            mark.fillColor = .clear; mark.lineWidth = 1.1; mark.lineCap = .round
            mark.position = .init(x: x, y: y); mark.zRotation = angle; mark.alpha = 0.45; mark.zPosition = 2; art.addChild(mark)
        }
        let ornaments: [(CGFloat, CGFloat, UInt32)] = [(0, 221, 0xDB4565), (-2, 164, 0xFFB173), (-38, 157, 0xF8E8DA),
            (11, 128, 0xADE3E1), (-16, 100, 0xDB4565), (44, 99, 0xFFB173), (-61, 87, 0xFFB173),
            (8, 66, 0xDB4565), (-34, 47, 0xADE3E1), (46, 46, 0xF8E8DA)]
        for (x, y, color) in ornaments {
            SnowArt.circle(CGPoint(x: x, y: y), radius: 2.6, color: SnowArt.color(color), in: art).zPosition = 3
        }
        let wires: [[CGPoint]] = [
            [.init(x: -28, y: 174), .init(x: -7, y: 181), .init(x: 13, y: 195), .init(x: 16, y: 211)],
            [.init(x: -52, y: 119), .init(x: -17, y: 125), .init(x: 22, y: 150), .init(x: 31, y: 168)],
            [.init(x: -69, y: 62), .init(x: -22, y: 71), .init(x: 32, y: 100), .init(x: 45, y: 132)],
            [.init(x: -22, y: 36), .init(x: 15, y: 40), .init(x: 55, y: 65), .init(x: 63, y: 92)]
        ]
        for (row, points) in wires.enumerated() {
            func point(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                return .init(x: u*u*u*points[0].x + 3*u*u*t*points[1].x + 3*u*t*t*points[2].x + t*t*t*points[3].x,
                             y: u*u*u*points[0].y + 3*u*u*t*points[1].y + 3*u*t*t*points[2].y + t*t*t*points[3].y)
            }
            let path = CGMutablePath(); path.move(to: points[0]); path.addCurve(to: points[3], control1: points[1], control2: points[2])
            let wire = SKShapeNode(path: path); wire.strokeColor = SnowArt.color(0xF2DDCA); wire.lineWidth = 1.25
            wire.lineCap = .round; wire.zPosition = 4; art.addChild(wire)
            for index in 0..<5 {
                let t = (CGFloat(index) + 0.5) / 5
                let lamp = SKNode(); lamp.position = point(t)
                let colorIndex = (row * 3 + index) % Self.colors.count
                let tangent = CGPoint(x: point(min(1, t + 0.01)).x - point(max(0, t - 0.01)).x,
                                      y: point(min(1, t + 0.01)).y - point(max(0, t - 0.01)).y)
                let bulb = SKShapeNode(ellipseOf: CGSize(width: 6.3, height: 11.2))
                bulb.zRotation = atan2(tangent.y, tangent.x); bulb.fillColor = Self.colors[colorIndex]
                bulb.strokeColor = .clear; lamp.addChild(bulb)
                lamps[(row * 3 + index) % 3].addChild(lamp)
            }
        }
        star.name = "tree.star"; star.position = CGPoint(x: 0, y: 246)
        let points = (0..<10).map { index -> CGPoint in
            let angle = .pi / 2 + CGFloat(index) * .pi / 5
            let radius: CGFloat = index % 2 == 0 ? 21 : 10.5
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        let outline = CGMutablePath()
        for index in points.indices {
            let p = points[index], previous = points[(index + 9) % 10], next = points[(index + 1) % 10]
            let before = CGPoint(x: p.x + (previous.x - p.x) * 0.08, y: p.y + (previous.y - p.y) * 0.08)
            let after = CGPoint(x: p.x + (next.x - p.x) * 0.08, y: p.y + (next.y - p.y) * 0.08)
            if index == 0 { outline.move(to: before) } else { outline.addLine(to: before) }
            outline.addQuadCurve(to: after, control: p)
        }
        outline.closeSubpath(); shape(outline, color: 0xF6A260, in: star)
        let insetPoints = points.map { CGPoint(x: $0.x * 0.95, y: $0.y * 0.95) }
        let facets: [UInt32] = [0xFFB677, 0xF3A05C, 0xFFBD82, 0xEF9650, 0xFAB072, 0xEA8F49, 0xFFBA7C, 0xF5A260, 0xFFC28B, 0xEE984F]
        for index in points.indices {
            SnowArt.polygon([.zero, insetPoints[index], insetPoints[(index + 1) % points.count]], color: SnowArt.color(facets[index]), in: star).zPosition = 1
        }
    }

    /// Export the actual drawing paths, not a second hand-maintained SVG asset.
    var svg: String {
        func number(_ n: CGFloat) -> String { String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), Double(n)) }
        func color(_ c: NSColor) -> String {
            let c = c.usingColorSpace(.sRGB)!
            return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
        }
        func pathData(_ path: CGPath) -> String {
            var commands: [String] = []
            func point(_ p: CGPoint) -> String { number(p.x) + " " + number(p.y) }
            path.applyWithBlock { pointer in
                let e = pointer.pointee
                switch e.type {
                case .moveToPoint: commands.append("M" + point(e.points[0]))
                case .addLineToPoint: commands.append("L" + point(e.points[0]))
                case .addQuadCurveToPoint: commands.append("Q" + point(e.points[0]) + " " + point(e.points[1]))
                case .addCurveToPoint: commands.append("C" + point(e.points[0]) + " " + point(e.points[1]) + " " + point(e.points[2]))
                case .closeSubpath: commands.append("Z")
                @unknown default: break
                }
            }
            return commands.joined(separator: " ")
        }
        func nodeSVG(_ node: SKNode) -> String {
            let transform = "translate(\(number(node.position.x)) \(number(node.position.y))) rotate(\(number(node.zRotation * 180 / .pi))) scale(\(number(node.xScale)) \(number(node.yScale)))"
            var content = ""
            if let shape = node as? SKShapeNode, let path = shape.path {
                let fill = shape.fillColor.alphaComponent > 0 ? color(shape.fillColor) : "none"
                let stroke = shape.strokeColor.alphaComponent > 0 ? color(shape.strokeColor) : "none"
                content = "<path d=\"\(pathData(path))\" fill=\"\(fill)\" fill-opacity=\"\(number(shape.fillColor.alphaComponent))\" stroke=\"\(stroke)\" stroke-opacity=\"\(number(shape.strokeColor.alphaComponent))\" stroke-width=\"\(number(shape.lineWidth))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
            }
            let children = node.children.enumerated().sorted { a, b in
                a.element.zPosition == b.element.zPosition ? a.offset < b.offset : a.element.zPosition < b.element.zPosition
            }
            content += children.map { nodeSVG($0.element) }.joined()
            return "<g transform=\"\(transform)\" opacity=\"\(number(node.alpha))\">\(content)</g>"
        }
        let bounds = HolidayTree.renderBounds
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(number(bounds.minX)) \(number(-bounds.maxY)) \(number(bounds.width)) \(number(bounds.height))\" width=\"384\" height=\"580\"><title>Holiday tree — vector artwork</title><g transform=\"scale(1 -1)\">" + ([art] + lamps + [star]).map(nodeSVG).joined() + "</g></svg>"
    }
}
