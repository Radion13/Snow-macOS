import AppKit
import SpriteKit

/// Original lamps and stars drawn from paths, using the supplied pictures as style
/// references. The reference bitmaps and their watermarks are never shipped.
final class ScreenGarlandRenderer {
    let root = SKNode()
    private var bulbs: [SKNode] = []
    private var signature = ""
    private static var images: [String: NSImage] = [:]
    private static var textures: [String: SKTexture] = [:]
    private static func texture(style: GarlandStyle, color: NSColor, halo: Bool) -> SKTexture {
        let key = "\(halo)-\(style.rawValue)-\(color.description)"
        if let cached = textures[key] { return cached }
        let texture = SKTexture(image: halo ? glowImage(color: color) : lampImage(style: style, color: color))
        textures[key] = texture; return texture
    }

    static func colors(_ palette: GarlandPalette) -> [NSColor] {
        let hex: [UInt32]
        switch palette {
        case .warm: hex = [0xFFD15E, 0xFFAA55, 0xFFECAE, 0xFFF1CE, 0xF6C06A]
        case .festive: hex = [0xFF493A, 0x89EE36, 0xFFD23D, 0x55DFFF, 0xCE6DFF]
        case .icy: hex = [0x658EFF, 0x68E8F0, 0xE9FAFF, 0x8EC9FF, 0xB2B4FA]
        }
        return hex.map { SnowArt.color($0) }
    }
    private static func starPath(in rect: CGRect) -> NSBezierPath {
        let points: [CGPoint] = (0..<10).map { index in
            let angle = .pi / 2 + CGFloat(index) * .pi / 5
            let radius = min(rect.width, rect.height) * (index % 2 == 0 ? 0.5 : 0.27)
            return CGPoint(x: rect.midX + cos(angle) * radius, y: rect.midY + sin(angle) * radius)
        }
        let path = NSBezierPath()
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: midpoint(points[9], points[0]))
        for index in 0..<10 {
            let end = midpoint(points[index], points[(index + 1) % 10])
            let start = midpoint(points[(index + 9) % 10], points[index])
            let control = points[index]
            path.curve(to: end,
                       controlPoint1: CGPoint(x: start.x + (control.x - start.x) * 0.7, y: start.y + (control.y - start.y) * 0.7),
                       controlPoint2: CGPoint(x: end.x + (control.x - end.x) * 0.7, y: end.y + (control.y - end.y) * 0.7))
        }
        path.close(); return path
    }
    static func lampImage(style: GarlandStyle, color: NSColor) -> NSImage {
        let key = "body-\(style.rawValue)-\(color.description)"
        if let cached = images[key] { return cached }
        let size = CGSize(width: 64, height: 96)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = style == .stars ? CGRect(x: 3, y: 19, width: 58, height: 58) : CGRect(x: 12, y: 5, width: 40, height: 86)
            let path = style == .stars ? starPath(in: body) : NSBezierPath(ovalIn: body)
            NSGraphicsContext.saveGraphicsState(); path.addClip()
            if style == .stars, let context = NSGraphicsContext.current?.cgContext {
                let stops = [NSColor.white.cgColor, color.blended(withFraction: 0.25, of: .white)!.cgColor,
                             color.cgColor, color.blended(withFraction: 0.25, of: .black)!.cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops, locations: [0, 0.25, 0.65, 1])!
                let center = CGPoint(x: body.midX, y: body.midY)
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: body.width * 0.52, options: .drawsAfterEndLocation)
            } else {
                let gradient = NSGradient(colorsAndLocations: (color.blended(withFraction: 0.3, of: .black)!, 0),
                                          (color, 0.2), (.white, 0.5), (color, 0.8), (color.blended(withFraction: 0.3, of: .black)!, 1))!
                gradient.draw(in: path, angle: 0)
            }
            NSGraphicsContext.restoreGraphicsState()
            if style == .glow {
                NSColor.white.withAlphaComponent(0.75).setStroke(); path.lineWidth = 2; path.stroke()
                let shine = NSBezierPath(ovalIn: CGRect(x: 23, y: 30, width: 8, height: 43))
                NSColor.white.withAlphaComponent(0.65).setFill(); shine.fill()
            }
            return true
        }
        images[key] = image; return image
    }
    static func glowImage(color: NSColor) -> NSImage {
        let key = "glow-" + color.description
        if let cached = images[key] { return cached }
        let image = NSImage(size: CGSize(width: 96, height: 96), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let stops = [CGFloat(0.7), 0.4, 0.13, 0.018, 0].map { color.withAlphaComponent($0).cgColor } as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops, locations: [0, 0.15, 0.35, 0.65, 1])!
            let center = CGPoint(x: rect.midX, y: rect.midY)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: rect.width / 2, options: [])
            return true
        }
        images[key] = image; return image
    }
    func configure(size: CGSize, settings: SnowSettings) {
        root.isHidden = settings.garland == .off
        guard !root.isHidden else { return }
        let next = "\(size.width):\(size.height):\(settings.garlandStyle.rawValue):\(settings.garlandPalette.rawValue)"
        guard signature != next else { return }
        signature = next; root.removeAllChildren(); bulbs.removeAll()
        let style = settings.garlandStyle
        for points in GarlandLayout.wires(style: style, size: size) {
            let path = CGMutablePath(); path.addLines(between: points)
            let wire = SKShapeNode(path: path)
            wire.strokeColor = style == .classic ? SnowArt.color(0x4F9984) : NSColor(white: 0.94, alpha: 0.92)
            wire.lineWidth = style == .classic ? 1.5 : 1
            wire.zPosition = 0; root.addChild(wire)
        }
        let palette = Self.colors(settings.garlandPalette)
        for light in GarlandLayout.lights(style: style, size: size) {
            let color = palette[light.colorIndex % palette.count]
            let node = SKNode(); node.position = light.position; node.zRotation = light.rotation; node.zPosition = 2
            let halo = SKSpriteNode(texture: Self.texture(style: style, color: color, halo: true))
            let haloSize = max(light.size.width, light.size.height) * (style == .glow ? 4.2 : 1.8)
            halo.size = CGSize(width: haloSize, height: haloSize); halo.zPosition = -1
            halo.alpha = style == .classic ? 0.3 : 0.9; node.addChild(halo)
            let bulb = SKSpriteNode(texture: Self.texture(style: style, color: color, halo: false))
            // Stars use a square crop in the 64×96 source; compensating here keeps
            // their actual silhouette round and proportional to the hanging bulbs.
            bulb.size = style == .stars ? CGSize(width: light.size.width * 64 / 58, height: light.size.height * 96 / 58) : light.size
            bulb.zPosition = 2; node.addChild(bulb)
            if style != .stars {
                SnowArt.rect(CGRect(x: -2, y: light.size.height / 2 - 1, width: 4, height: 4), color: NSColor(white: 0.92, alpha: 1), in: node).zPosition = 3
            } else {
                let cord = CGMutablePath(); cord.move(to: light.attachment); cord.addLine(to: CGPoint(x: light.position.x, y: light.position.y + light.size.height * 0.4))
                let line = SKShapeNode(path: cord); line.strokeColor = NSColor(white: 0.95, alpha: 0.9); line.lineWidth = 0.7; root.addChild(line)
            }
            root.addChild(node); bulbs.append(node)
        }
    }
    func animate(time: Double, settings: SnowSettings, reduceMotion: Bool) {
        guard !root.isHidden else { return }
        for (index, bulb) in bulbs.enumerated() {
            bulb.alpha = CGFloat(GarlandLighting.alpha(time: time, index: index, settings: settings, reduceMotion: reduceMotion))
        }
    }
    static func preview(style: GarlandStyle, palette: GarlandPalette = .festive) -> NSImage {
        let key = "preview-\(style.rawValue)-\(palette.rawValue)"
        if let cached = images[key] { return cached }
        let size = CGSize(width: 170, height: 84)
        let image = NSImage(size: size, flipped: false) { rect in
            SnowArt.color(0x101A23).setFill(); NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            let scale: CGFloat = 0.38
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
            let logicalSize = CGSize(width: size.width / scale, height: 102)
            let offset = NSAffineTransform(); offset.translateX(by: 0, yBy: (size.height / scale - logicalSize.height) / 2); offset.concat()
            for points in GarlandLayout.wires(style: style, size: logicalSize) {
                let wire = NSBezierPath(); wire.move(to: points[0]); points.dropFirst().forEach { wire.line(to: $0) }
                (style == .classic ? SnowArt.color(0x4F9984) : NSColor.white).setStroke(); wire.lineWidth = 1.5; wire.stroke()
            }
            let lampColors = Self.colors(palette)
            for light in GarlandLayout.lights(style: style, size: logicalSize) {
                let color = lampColors[light.colorIndex % lampColors.count]
                let halo = max(light.size.width, light.size.height) * (style == .glow ? 4 : 1.8)
                glowImage(color: color).draw(in: CGRect(x: light.position.x - halo / 2, y: light.position.y - halo / 2, width: halo, height: halo))
                let body = lampImage(style: style, color: color)
                let drawSize = style == .stars ? CGSize(width: light.size.width * 64 / 58, height: light.size.height * 96 / 58) : light.size
                NSGraphicsContext.saveGraphicsState()
                let placement = NSAffineTransform(); placement.translateX(by: light.position.x, yBy: light.position.y); placement.rotate(byRadians: light.rotation); placement.concat()
                body.draw(in: CGRect(x: -drawSize.width / 2, y: -drawSize.height / 2, width: drawSize.width, height: drawSize.height))
                NSGraphicsContext.restoreGraphicsState()
            }
            NSGraphicsContext.restoreGraphicsState(); return true
        }
        images[key] = image; return image
    }
}
