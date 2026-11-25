import AppKit
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let bounds = CGRect(x: 74, y: 74, width: 876, height: 876)
        context.addPath(CGPath(roundedRect: bounds, cornerWidth: 195, cornerHeight: 195, transform: nil)); context.clip()
        let colors = [NSColor(srgbRed: 0.07, green: 0.19, blue: 0.26, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.23, green: 0.45, blue: 0.5, alpha: 1).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 74), end: CGPoint(x: 512, y: 950), options: [])
        context.setStrokeColor(NSColor(srgbRed: 0.94, green: 0.98, blue: 0.98, alpha: 1).cgColor)
        context.setLineWidth(29); context.setLineCap(.round); context.setLineJoin(.round)
        for arm in 0..<6 {
            let angle = CGFloat(arm) * .pi / 3 + .pi / 6
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            func point(_ length: CGFloat, _ side: CGFloat = 0) -> CGPoint {
                .init(x: 512 + direction.x * length - direction.y * side, y: 512 + direction.y * length + direction.x * side)
            }
            context.move(to: CGPoint(x: 512, y: 512)); context.addLine(to: point(270)); context.strokePath()
            for length: CGFloat in [135, 215] {
                context.move(to: point(length - 50, 55)); context.addLine(to: point(length)); context.addLine(to: point(length - 50, -55)); context.strokePath()
            }
        }
        context.setFillColor(NSColor.white.withAlphaComponent(0.32).cgColor)
        for point in [CGPoint(x: 220, y: 710), CGPoint(x: 792, y: 290), CGPoint(x: 280, y: 290)] {
            context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: 14, height: 14))
        }
        let suffix = scale == 2 ? "@2x" : ""
        let url = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
    }
}
