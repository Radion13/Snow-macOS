import AppKit
import SpriteKit
import simd

/// Original, stationary snow material. One tile and two ball textures are shared
/// across displays. No per-frame image generation, lights or additional particles.
enum SnowMaterialArt {
    static let ballExtent: CGFloat = 256.0 / 120.0
    private static let tileSize = 256
    private static func lattice(_ x: Int, _ y: Int, period: Int) -> Double {
        let a = UInt64((x % period + period) % period), b = UInt64((y % period + period) % period)
        var n = a &* 0x9E3779B1 &+ b &* 0x85EBCA77 &+ 41
        n = (n ^ (n >> 13)) &* 0xC2B2AE3D
        return Double(n & 65535) / 65535
    }
    private static func noise(_ x: Double, _ y: Double, period: Int) -> Double {
        let ix = Int(floor(x)), iy = Int(floor(y))
        let fx = x - floor(x), fy = y - floor(y)
        let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
        let a = lattice(ix, iy, period: period), b = lattice(ix + 1, iy, period: period)
        let c = lattice(ix, iy + 1, period: period), d = lattice(ix + 1, iy + 1, period: period)
        return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v
    }
    private static func height(_ x: Double, _ y: Double) -> Double {
        noise(x / 32, y / 32, period: 8) * 0.48 + noise(x / 12.8, y / 12.8, period: 20) * 0.32 +
        noise(x / 4, y / 4, period: 64) * 0.20
    }
    private static let grains: [Double] = {
        (0..<(tileSize * tileSize)).map { index in
            let x = Double(index % tileSize), y = Double(index / tileSize)
            let relief = (height(x - 1, y + 1) - height(x + 1, y - 1)) * 1.05
            let fine = (lattice(Int(x), Int(y), period: 256) - 0.5) * 0.012
            return min(1, max(0.78, 0.92 + relief + (height(x, y) - 0.5) * 0.10 + fine))
        }
    }()
    private static func image(_ pixel: (Int, Int) -> (Double, Double, Double, Double)) -> CGImage {
        var data = [UInt8](repeating: 0, count: tileSize * tileSize * 4)
        for y in 0..<tileSize {
            for x in 0..<tileSize {
                let (r, g, b, a) = pixel(x, y), index = (y * tileSize + x) * 4
                for (channel, value) in [r * a, g * a, b * a, a].enumerated() {
                    data[index + channel] = UInt8((min(1, max(0, value)) * 255).rounded())
                }
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(width: tileSize, height: tileSize, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: tileSize * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }
    private static let grainTexture: SKTexture = {
        let texture = SKTexture(cgImage: image { x, y in
            let g = grains[y * tileSize + x]; return (g, g, g, 1)
        })
        texture.filteringMode = .linear; return texture
    }()
    private static let fill: SKShader = {
        let shader = SKShader(source: """
        void main() {
            vec2 p = v_tex_coord * a_extent + a_origin;
            float grain = texture2D(u_texture, fract(p / 96.0)).r;
            float along = dot(p, vec2(a_up.y, abs(a_up.x)));
            float dx = max(0.0, a_band.x - min(along, a_band.y - along));
            float base = sqrt(max(0.0, a_band.x * a_band.x - dx * dx)) - a_band.x;
            float up = (dot(p, a_up) - base) / max(1.0, a_band.z);
            float light = smoothstep(0.0, 0.88, up);
            vec3 snow = mix(vec3(0.77, 0.83, 0.90), vec3(0.995, 0.998, 1.0), light);
            snow += (grain - 0.92) * 0.65;
            gl_FragColor = vec4(clamp(snow, 0.0, 1.0), 1.0) * SKDefaultShading().a;
        }
        """)
        shader.attributes = [SKAttribute(name: "a_extent", type: .vectorFloat2),
                             SKAttribute(name: "a_origin", type: .vectorFloat2),
                             SKAttribute(name: "a_up", type: .vectorFloat2),
                             SKAttribute(name: "a_band", type: .vectorFloat4)]
        return shader
    }()
    static func apply(to node: SKShapeNode, surface: SnowSurface, appearance: SnowAppearance) {
        node.strokeColor = .clear; node.isAntialiased = true
        guard appearance == .textured else {
            node.fillShader = nil; node.fillTexture = nil
            node.fillColor = NSColor(white: 0.98, alpha: 0.97); return
        }
        node.fillColor = NSColor.white.withAlphaComponent(0.97)
        node.fillTexture = grainTexture; node.fillShader = fill
        let bounds = node.path?.boundingBoxOfPath ?? .zero
        node.setValue(SKAttributeValue(vectorFloat2: SIMD2(Float(bounds.width), Float(bounds.height))), forAttribute: "a_extent")
        let origin = CGPoint(x: surface.orientation == .rightEdge ? surface.frame.maxX : surface.frame.minX,
                             y: surface.orientation == .top ? surface.baseline : surface.frame.minY)
        node.setValue(SKAttributeValue(vectorFloat2: SIMD2(Float(bounds.minX - origin.x), Float(bounds.minY - origin.y))), forAttribute: "a_origin")
        let up: SIMD2<Float>
        switch surface.orientation { case .top: up = SIMD2(0, 1); case .leftEdge: up = SIMD2(-1, 0); case .rightEdge: up = SIMD2(1, 0) }
        node.setValue(SKAttributeValue(vectorFloat2: up), forAttribute: "a_up")
        let thickness: CGFloat
        switch surface.orientation {
        case .top: thickness = bounds.maxY - surface.baseline
        case .leftEdge: thickness = surface.frame.minX - bounds.minX
        case .rightEdge: thickness = bounds.maxX - surface.frame.maxX
        }
        node.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(surface.cornerRadius), Float(surface.length), Float(thickness), 0)), forAttribute: "a_band")
    }
    private static func ballImage(loose: Bool) -> CGImage {
        image { x, y in
            let nx = (Double(x) - 127.5) / 120, ny = (127.5 - Double(y)) / 120
            let angle = atan2(ny, nx)
            let edge = loose ? 0.91 + 0.06 * sin(angle * 7) + 0.025 * cos(angle * 11) : 1
            let distance = hypot(nx, ny) / edge
            let alpha = min(1, max(0, (1 - distance) * 120))
            let z = sqrt(max(0, 1 - distance * distance))
            let diffuse = max(0, -nx * 0.42 + ny * 0.56 + z * 0.72)
            let grain = grains[y * tileSize + x]
            let shade = min(1, max(0.72, 0.83 + 0.17 * pow(diffuse, 0.7) - 0.06 * (1 - z) + (grain - 0.92) * 0.45))
            return (shade * 0.97, shade * 0.99, min(1, shade + 0.025), alpha)
        }
    }
    private static let packedBall = SKTexture(cgImage: ballImage(loose: false))
    private static let looseBall = SKTexture(cgImage: ballImage(loose: true))
    static func ballTexture(loose: Bool) -> SKTexture { loose ? looseBall : packedBall }
}
