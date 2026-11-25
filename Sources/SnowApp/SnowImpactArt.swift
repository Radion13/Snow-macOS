import AppKit
import SpriteKit

/// Original snow-on-glass artwork. Nine small textures are shared by all marks;
/// the scene only animates their scale and opacity, never rebuilds their paths.
enum SnowImpactArt {
    static let textureExtent: CGFloat = 3.4
    private static var textures: [Int: SKTexture] = [:]

    static func texture(variant: Int) -> SKTexture {
        let key = ((variant % 9) + 9) % 9
        if let texture = textures[key] { return texture }
        let texture = SKTexture(cgImage: image(variant: key))
        texture.filteringMode = .linear; textures[key] = texture
        return texture
    }

    static func image(variant: Int) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: 384, height: 384, bitsPerComponent: 8,
                                bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setAllowsAntialiasing(true); context.setShouldAntialias(true)
        context.translateBy(x: 192, y: 192)
        context.scaleBy(x: 384 / textureExtent, y: 384 / textureExtent)
        var seed = UInt64(variant + 1) &* 0x9E3779B97F4A7C15
        func unit() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 11) / CGFloat(UInt64(1) << 53)
        }
        struct Blob { var x: CGFloat; var y: CGFloat; var rx: CGFloat; var ry: CGFloat }
        let blobs: [Blob]
        switch variant {
        case 1: blobs = [.init(x: -0.22, y: 0.30, rx: 0.62, ry: 0.62), .init(x: 0.28, y: -0.40, rx: 0.52, ry: 0.48)]
        case 2: blobs = [.init(x: -0.12, y: -0.12, rx: 0.52, ry: 0.83), .init(x: 0.22, y: 0.42, rx: 0.47, ry: 0.40)]
        case 3: blobs = [.init(x: -0.19, y: 0.10, rx: 0.65, ry: 0.73), .init(x: 0.34, y: -0.21, rx: 0.44, ry: 0.50)]
        case 4: blobs = [.init(x: 0, y: 0, rx: 0.83, ry: 0.79)]
        case 5: blobs = [.init(x: 0, y: 0, rx: 0.68, ry: 0.89)]
        case 6: blobs = [.init(x: -0.28, y: -0.32, rx: 0.52, ry: 0.65), .init(x: 0.22, y: 0.28, rx: 0.64, ry: 0.64)]
        case 7: blobs = [.init(x: 0.22, y: 0.37, rx: 0.52, ry: 0.49), .init(x: -0.23, y: -0.36, rx: 0.60, ry: 0.64)]
        case 8: blobs = [.init(x: 0.02, y: -0.08, rx: 0.75, ry: 0.65)]
        default: blobs = [.init(x: 0, y: 0, rx: 0.72, ry: 0.78)]
        }
        let rotation = CGFloat(variant) * 0.29 - 0.3
        func rotated(_ point: CGPoint) -> CGPoint {
            .init(x: point.x * cos(rotation) - point.y * sin(rotation),
                  y: point.x * sin(rotation) + point.y * cos(rotation))
        }
        let body = CGMutablePath()
        for blob in blobs {
            let phase = unit() * .pi * 2
            let spikes = (0..<7).map { _ in (unit() * .pi * 2, 0.16 + unit() * 0.48, 0.045 + unit() * 0.055) }
            let points = (0..<96).map { index -> CGPoint in
                let angle = CGFloat(index) / 96 * .pi * 2
                var radius = 1 + 0.055 * sin(angle * 7 + phase) + 0.035 * sin(angle * 17 - phase)
                for (whereAt, height, width) in spikes {
                    let delta = atan2(sin(angle - whereAt), cos(angle - whereAt))
                    radius += height * exp(-delta * delta / (width * width))
                }
                return rotated(CGPoint(x: blob.x + cos(angle) * blob.rx * radius,
                                       y: blob.y + sin(angle) * blob.ry * radius))
            }
            body.move(to: points[0])
            for index in points.indices {
                let p0 = points[(index + points.count - 1) % points.count], p1 = points[index]
                let p2 = points[(index + 1) % points.count], p3 = points[(index + 2) % points.count]
                body.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                              control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
            }
            body.closeSubpath()
        }
        func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
            CGColor(colorSpace: space, components: [red, green, blue, alpha])!
        }
        func gradient(_ colors: [CGColor], at locations: [CGFloat]) -> CGGradient {
            CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
        }
        // A subtle contact shadow and a cool edge make the snow look pressed
        // against a sheet of glass without drawing or damaging any real window.
        context.saveGState(); context.translateBy(x: 0.014, y: -0.023)
        context.addPath(body); context.setFillColor(color(0.35, 0.48, 0.51, 0.18)); context.fillPath(); context.restoreGState()
        context.saveGState(); context.addPath(body); context.clip()
        context.drawLinearGradient(gradient([color(1, 1, 1), color(0.96, 0.99, 0.99), color(0.81, 0.89, 0.90)], at: [0, 0.56, 1]),
                                   start: CGPoint(x: -0.55, y: 0.8), end: CGPoint(x: 0.65, y: -0.8), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        for blob in blobs {
            for index in 0..<4 {
                let shade = rotated(CGPoint(x: blob.x + blob.rx * (0.1 + CGFloat(index % 2) * 0.37),
                                             y: blob.y + blob.ry * (0.32 - CGFloat(index) * 0.27)))
                context.saveGState(); context.translateBy(x: shade.x, y: shade.y)
                context.scaleBy(x: blob.rx * 0.46, y: blob.ry * 0.52)
                context.drawRadialGradient(gradient([color(0.58, 0.73, 0.75, 0.24), color(0.75, 0.85, 0.86, 0)], at: [0, 1]),
                                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1,
                                           options: [.drawsAfterEndLocation]); context.restoreGState()
                let light = rotated(CGPoint(x: blob.x - blob.rx * 0.2, y: blob.y + blob.ry * 0.27))
                context.saveGState(); context.translateBy(x: light.x, y: light.y); context.scaleBy(x: blob.rx * 0.68, y: blob.ry * 0.67)
                context.drawRadialGradient(gradient([color(1, 1, 1, 0.74), color(1, 1, 1, 0)], at: [0, 1]),
                                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1,
                                           options: []); context.restoreGState()
            }
        }
        context.restoreGState()
        for index in 0..<(5 + variant % 4) {
            let angle = CGFloat(index) * 2.399 + unit() * 0.6
            let distance = 1.18 + unit() * 0.28, radius = 0.035 + unit() * 0.055
            let center = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            context.saveGState(); context.translateBy(x: center.x, y: center.y); context.rotate(by: angle - .pi / 2)
            context.addEllipse(in: CGRect(x: -radius, y: -radius * 1.25, width: radius * 2, height: radius * 2.5)); context.clip()
            context.drawLinearGradient(gradient([color(1, 1, 1), color(0.84, 0.93, 0.94)], at: [0, 1]),
                                       start: CGPoint(x: -radius, y: radius), end: CGPoint(x: radius, y: -radius), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
            context.restoreGState()
        }
        return context.makeImage()!
    }
}
