import AppKit
import SpriteKit

/// Original crystal drawings, rasterized once and shared by every display.
/// Styling changes the existing sprite only; radius and physics stay untouched.
enum SnowflakeArt {
    static let variantCount = 8
    static let simpleTexture: SKTexture = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let gradient = NSGradient(colors: [.white, NSColor.white.withAlphaComponent(0.75), .clear])!
            gradient.draw(in: NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)), relativeCenterPosition: .zero)
            return true
        }
        return SKTexture(image: image)
    }()
    private static let images = (0..<variantCount).map { image(variant: $0) }
    private static let textures: [SKTexture] = images.map {
        let texture = SKTexture(cgImage: $0); texture.filteringMode = .linear; return texture
    }
    private static let previews: [NSImage] = images.map { source in
        NSImage(size: CGSize(width: 48, height: 48), flipped: false) { rect in
            SnowArt.color(0x183344).setFill(); NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            NSImage(cgImage: source, size: CGSize(width: 64, height: 64)).draw(in: rect.insetBy(dx: 5, dy: 5))
            return true
        }
    }
    static func texture(variant: Int) -> SKTexture { textures[(variant % variantCount + variantCount) % variantCount] }
    static func preview(variant: Int) -> NSImage { previews[(variant % variantCount + variantCount) % variantCount] }

    static func apply(to node: SKSpriteNode, particle: SnowParticle, settings: SnowSettings, time: Double, reduceMotion: Bool) {
        let loose = particle.scattered || particle.carriedArea > 0
        let patterned = settings.snowflakeStyle == .patterned && !loose
        let texture = patterned ? texture(variant: Int((particle.flakeSeed >> 16) % UInt32(variantCount))) : simpleTexture
        if node.texture !== texture { node.texture = texture }
        let multiplier = settings.snowflakeSize.isFinite ? min(3, max(0.5, settings.snowflakeSize)) : 1
        let diameter = particle.radius * (patterned ? 8 : 2.7) * (loose ? 1 : multiplier)
        node.size = CGSize(width: diameter, height: diameter)
        if patterned {
            let phase = Double(particle.flakeSeed & 65535) / 65536 * .pi * 2
            let spin = (particle.flakeSeed & 1 == 0 ? 1.0 : -1.0) * (0.06 + Double(particle.flakeSeed >> 24) / 255 * 0.12)
            node.zRotation = CGFloat(phase + (reduceMotion || !time.isFinite ? 0 : time * spin))
        } else { node.zRotation = 0 }
    }

    private static func image(variant: Int) -> CGImage {
        let context = CGContext(data: nil, width: 192, height: 192, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: 3, y: 3); context.translateBy(x: 32, y: 32)
        context.setAllowsAntialiasing(true); context.setShouldAntialias(true)
        context.setLineCap(.round); context.setLineJoin(.round)
        func stroke(_ alpha: CGFloat = 0.92, width: CGFloat = 1.05) {
            context.setStrokeColor(NSColor.white.withAlphaComponent(alpha).cgColor); context.setLineWidth(width); context.strokePath()
        }
        func line(_ a: CGPoint, _ b: CGPoint) { context.move(to: a); context.addLine(to: b) }
        func points(_ count: Int, radius: CGFloat, offset: CGFloat = .pi / 2) -> [CGPoint] {
            (0..<count).map { i in
                let angle = offset + CGFloat(i) * .pi * 2 / CGFloat(count)
                return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        func polygon(_ vertices: [CGPoint], fill: CGFloat = 0) {
            context.beginPath(); context.addLines(between: vertices); context.closePath()
            if fill > 0 {
                context.setFillColor(NSColor.white.withAlphaComponent(fill).cgColor)
                context.drawPath(using: .fillStroke)
            } else { context.strokePath() }
        }
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor); context.setLineWidth(0.85)
        switch variant {
        case 0, 3, 7:
            let branches: [CGFloat] = variant == 0 ? [8, 15, 21] : (variant == 3 ? [11, 20] : [9, 17])
            for arm in 0..<6 {
                context.saveGState(); context.rotate(by: CGFloat(arm) * .pi / 3)
                context.beginPath(); line(.zero, CGPoint(x: 0, y: 26))
                for y in branches {
                    let reach: CGFloat = variant == 3 ? 3.1 : (26 - y) * 0.34 + 1.4
                    line(CGPoint(x: 0, y: y), CGPoint(x: -reach, y: y + reach * 0.85))
                    line(CGPoint(x: 0, y: y), CGPoint(x: reach, y: y + reach * 0.85))
                }
                stroke(variant == 3 ? 0.82 : 0.95, width: variant == 3 ? 0.8 : 1.1)
                if variant == 7 {
                    context.rotate(by: .pi / 6); context.beginPath(); line(.zero, CGPoint(x: 0, y: 16)); stroke(0.7, width: 0.8)
                }
                context.restoreGState()
            }
        case 1:
            let vertices = (0..<12).map { i -> CGPoint in
                let angle = .pi / 2 + CGFloat(i) * .pi / 6, r: CGFloat = i % 2 == 0 ? 26 : 10
                return CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            }
            polygon(vertices, fill: 0.13)
            for vertex in points(6, radius: 26) { context.beginPath(); line(.zero, vertex); stroke(0.7, width: 0.75) }
            polygon(points(6, radius: 10))
        case 2:
            polygon(points(6, radius: 25), fill: 0.1)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor); polygon(points(6, radius: 20))
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            context.setFillColor(NSColor.white.withAlphaComponent(0.8).cgColor); context.fillEllipse(in: CGRect(x: -2, y: -2, width: 4, height: 4))
        case 4:
            for arm in 0..<6 {
                context.saveGState(); context.rotate(by: CGFloat(arm) * .pi / 3)
                context.beginPath(); line(.zero, CGPoint(x: 0, y: 18)); stroke(0.9, width: 1.15)
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor); context.setLineWidth(0.8)
                polygon([.init(x: 0, y: 16), .init(x: -3.5, y: 21), .init(x: 0, y: 26), .init(x: 3.5, y: 21)], fill: 0.28)
                context.restoreGState()
            }
        case 5:
            let colors = [CGColor(red: 1, green: 1, blue: 1, alpha: 0.3), CGColor(red: 1, green: 1, blue: 1, alpha: 0)]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 16, options: [])
            let vertices = (0..<8).map { i -> CGPoint in
                let angle = CGFloat(i) * .pi / 4, r: CGFloat = i % 2 == 0 ? 27 : 3
                return CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            }
            polygon(vertices, fill: 0.65)
            for vertex in points(4, radius: 11, offset: .pi / 4) { context.beginPath(); line(.zero, vertex); stroke(0.5, width: 0.65) }
        default:
            let hex = points(6, radius: 25)
            polygon(hex, fill: 0.06)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.65).cgColor); context.setLineWidth(0.7)
            polygon([hex[0], hex[2], hex[4]]); polygon([hex[1], hex[3], hex[5]])
            polygon(points(6, radius: 13))
            for vertex in hex { context.beginPath(); line(.zero, vertex); stroke(0.55, width: 0.65) }
        }
        return context.makeImage()!
    }
}
