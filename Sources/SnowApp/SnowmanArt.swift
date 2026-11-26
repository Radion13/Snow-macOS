import AppKit
import SpriteKit

/// Accessories use the same small vector shapes and snow materials as the game.
enum SnowmanArt {
    private static let coal: UInt32 = 0x293F4A
    private static let red: UInt32 = 0xD85D52
    private static let redShade: UInt32 = 0xB94743
    private static let blue: UInt32 = 0x559AB6
    private static let blueShade: UInt32 = 0x397B99
    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    @discardableResult private static func fill(_ path: CGPath, scale: CGFloat = 1, color: UInt32,
                                               in parent: SKNode, z: CGFloat = 0, name: String? = nil) -> SKShapeNode {
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        let node = SKShapeNode(path: path.copy(using: &transform)!)
        node.fillColor = SnowArt.color(color); node.strokeColor = .clear
        node.name = name; node.zPosition = z; parent.addChild(node); return node
    }
    @discardableResult private static func line(_ path: CGPath, color: UInt32, width: CGFloat,
                                               in parent: SKNode, z: CGFloat = 0, name: String? = nil) -> SKShapeNode {
        let node = SKShapeNode(path: path); node.strokeColor = SnowArt.color(color)
        node.fillColor = .clear; node.lineWidth = width; node.zPosition = z
        node.name = name; parent.addChild(node); return node
    }
    private static func ellipse(_ rect: CGRect, color: UInt32, in parent: SKNode, z: CGFloat = 0,
                                outline: UInt32? = nil) {
        let node = SKShapeNode(ellipseIn: rect); node.fillColor = SnowArt.color(color)
        node.strokeColor = outline.map { SnowArt.color($0) } ?? .clear
        node.lineWidth = 0.6; node.zPosition = z; parent.addChild(node)
    }
    static func make(head: Snowball, middle: Snowball, base: Snowball,
                     variant: SnowmanVariant, appearance: SnowAppearance) -> SKNode {
        let root = SKNode(); root.name = "snowman.variant.\(variant.rawValue)"
        let r = head.radius
        let m = p(middle.position.x - head.position.x, middle.position.y - head.position.y)
        let b = p(base.position.x - head.position.x, base.position.y - head.position.y)
        for ball in [middle, base] {
            let center = p(ball.position.x - head.position.x, ball.position.y - head.position.y)
            for y: CGFloat in [0.20, -0.30] {
                let button = SnowArt.circle(p(center.x - (variant == .waving ? ball.radius * 0.09 : 0), center.y + y * ball.radius),
                                            radius: max(1.3, ball.radius * 0.072), color: SnowArt.color(coal), in: root)
                button.zPosition = 2; button.name = "snowman.button"
                SnowArt.circle(p(button.position.x - 0.4, button.position.y + 0.5), radius: max(0.35, ball.radius * 0.018),
                               color: SnowArt.color(0x8CA3B0), in: root).zPosition = 3
            }
        }
        if variant != .winterBroom {
            for side: CGFloat in [-1, 1] {
                let foot = SKNode(); foot.position = p(b.x + side * base.radius * 0.56, b.y - base.radius + 2.5)
                foot.zPosition = 3; foot.zRotation = side * 0.10; foot.name = "snowman.foot"
                ellipse(CGRect(x: -base.radius * 0.39, y: -base.radius * 0.12, width: base.radius * 0.78, height: base.radius * 0.27),
                        color: 0xDCEBF2, in: foot, outline: 0xA5C0D0)
                ellipse(CGRect(x: -base.radius * 0.31, y: -base.radius * 0.02, width: base.radius * 0.53, height: base.radius * 0.16),
                        color: 0xF3F9FB, in: foot, z: 1)
                root.addChild(foot)
            }
        }
        let leftShoulder = p(m.x - middle.radius * 0.88, m.y + middle.radius * 0.20)
        let rightShoulder = p(m.x + middle.radius * 0.88, m.y + middle.radius * 0.20)
        let leftHand: CGPoint, rightHand: CGPoint
        switch variant {
        case .festive:
            leftHand = p(b.x - base.radius * 1.18, m.y - middle.radius * 0.64)
            rightHand = p(b.x + base.radius * 1.13, m.y - middle.radius * 0.57)
        case .winterBroom:
            leftHand = p(b.x - base.radius * 1.28, m.y + middle.radius * 1.28)
            rightHand = p(b.x + base.radius * 1.13, m.y + middle.radius * 0.48)
        case .classicBucket:
            leftHand = p(b.x - base.radius * 1.15, m.y - middle.radius * 0.47)
            rightHand = p(b.x + base.radius * 1.19, m.y + middle.radius * 0.55)
        case .waving:
            leftHand = p(b.x - base.radius * 1.14, m.y - middle.radius * 0.66)
            rightHand = p(b.x + base.radius * 1.16, r * 0.30)
        }
        arm(from: leftShoulder, to: leftHand, radius: r, forks: variant != .waving, in: root)
        arm(from: rightShoulder, to: rightHand, radius: r, forks: variant != .waving, in: root)
        switch variant {
        case .festive:
            santaHat(radius: r, waving: false, in: root)
            heldBall(at: p(rightHand.x, rightHand.y + r * 0.30), radius: r * 0.52, appearance: appearance, in: root)
        case .winterBroom:
            knittedHat(radius: r, in: root)
            broom(at: rightHand, bottom: b.y - base.radius + 2, radius: r, in: root)
        case .classicBucket:
            bucket(radius: r, in: root)
            heldBall(at: p(rightHand.x, rightHand.y + r * 0.40), radius: r * 0.55, appearance: appearance, in: root)
        case .waving:
            santaHat(radius: r, waving: true, in: root)
            mitten(at: leftHand, radius: r, rotation: -0.65, in: root)
            mitten(at: rightHand, radius: r, rotation: 0.15, in: root)
        }
        scarf(radius: r, variant: variant, in: root)
        face(radius: r, variant: variant, in: root)
        return root
    }
    private static func face(radius r: CGFloat, variant: SnowmanVariant, in parent: SKNode) {
        let face = SKNode(); face.name = "snowman.face"; face.zPosition = 9; parent.addChild(face)
        for side: CGFloat in [-1, 1] {
            let cheek = SnowArt.circle(p(side * r * 0.57, -r * 0.09), radius: r * 0.145,
                                      color: SnowArt.color(0xE5A7B1, alpha: 0.64), in: face)
            cheek.zPosition = 0
            let eye = SnowArt.circle(p(side * r * 0.28, r * 0.25), radius: max(1.3, r * 0.08), color: SnowArt.color(coal), in: face)
            eye.zPosition = 2; eye.name = side < 0 ? "snowman.eye.left" : "snowman.eye.right"
            SnowArt.circle(p(eye.position.x - r * 0.035, eye.position.y + r * 0.035), radius: r * 0.014,
                           color: SnowArt.color(0xEAF4F7), in: face).zPosition = 3
        }
        let tip = variant == .festive ? p(r * 0.38, -r * 0.34) : p(r * 0.82, -r * 0.04)
        let nose = SnowArt.polygon([p(-r * 0.06, r * 0.06), tip, p(-r * 0.06, -r * 0.23)],
                                  color: SnowArt.color(0xDF8B43), in: face)
        nose.name = "snowman.nose"; nose.zPosition = 4
        let smile = CGMutablePath(); smile.move(to: p(-r * 0.35, -r * 0.25))
        smile.addQuadCurve(to: p(r * 0.35, -r * 0.25), control: p(0, -r * 0.63))
        line(smile, color: coal, width: max(1.4, r * 0.075), in: face, z: 2, name: "snowman.mouth")
        for side: CGFloat in [-1, 1] {
            SnowArt.circle(p(side * r * 0.35, -r * 0.25), radius: max(0.7, r * 0.0375), color: SnowArt.color(coal), in: face).zPosition = 2
        }
    }
    private static func arm(from start: CGPoint, to end: CGPoint, radius r: CGFloat, forks: Bool, in parent: SKNode) {
        let arm = CGMutablePath(); arm.move(to: start)
        arm.addQuadCurve(to: end, control: p(end.x * 0.75 + start.x * 0.25, start.y + (end.y - start.y) * 0.28))
        line(arm, color: 0x454F56, width: max(1.15, r * 0.085), in: parent, z: -3,
             name: end.x < start.x ? "snowman.arm.left" : "snowman.arm.right")
        if forks {
            let sign: CGFloat = end.x < start.x ? -1 : 1
            for offset: CGFloat in [-0.20, 0.20] {
                let twig = CGMutablePath(); twig.move(to: p(end.x - sign * r * 0.18, end.y + (end.y < start.y ? r * 0.18 : -r * 0.18)))
                twig.addLine(to: p(end.x + sign * r * 0.24, end.y + r * offset))
                line(twig, color: 0x454F56, width: max(0.8, r * 0.045), in: parent, z: -3)
            }
        }
    }
    private static func heldBall(at point: CGPoint, radius: CGFloat, appearance: SnowAppearance, in parent: SKNode) {
        let ball = SKNode(); ball.position = point; ball.zPosition = 4; ball.name = "snowman.heldSnowball"; parent.addChild(ball)
        if appearance == .textured {
            let snow = SKSpriteNode(texture: SnowMaterialArt.ballTexture(loose: false))
            snow.size = CGSize(width: radius * SnowMaterialArt.ballExtent, height: radius * SnowMaterialArt.ballExtent)
            ball.addChild(snow)
        } else {
            let body = SnowArt.circle(.zero, radius: radius, color: SnowArt.color(0xDFEDF4), in: ball)
            body.strokeColor = SnowArt.color(0xA5BECD); body.lineWidth = 0.6
            SnowArt.circle(p(-radius * 0.24, radius * 0.23), radius: radius * 0.66, color: SnowArt.color(0xF7FBFC), in: ball).zPosition = 1
        }
    }
    private static func santaHat(radius r: CGFloat, waving: Bool, in parent: SKNode) {
        let hat = SKNode(); hat.name = "snowman.hat.santa"; hat.zPosition = 6; hat.zRotation = waving ? 0.08 : -0.06; parent.addChild(hat)
        let path = CGMutablePath(); path.move(to: p(-0.76, 1.02))
        if waving {
            path.addCurve(to: p(-0.20, 1.99), control1: p(-0.91, 1.56), control2: p(-0.74, 2.02))
            path.addQuadCurve(to: p(0.65, 1.64), control: p(0.42, 2.04))
            path.addQuadCurve(to: p(0.81, 1.02), control: p(0.86, 1.30))
        } else {
            path.addCurve(to: p(0.55, 2.11), control1: p(-0.24, 1.74), control2: p(0.36, 2.11))
            path.addQuadCurve(to: p(0.86, 1.35), control: p(0.75, 1.93))
            path.addQuadCurve(to: p(0.69, 1.02), control: p(0.87, 1.13))
        }
        path.closeSubpath(); fill(path, scale: r, color: red, in: hat)
        let shade = CGMutablePath(); shade.move(to: p(0.36, 1.11)); shade.addQuadCurve(to: p(0.55, waving ? 1.88 : 2.05), control: p(0.57, 1.57))
        shade.addQuadCurve(to: p(0.81, 1.02), control: p(0.91, 1.49)); shade.closeSubpath()
        fill(shade, scale: r, color: redShade, in: hat, z: 1)
        furBand(radius: r, in: hat)
        let pom = waving ? p(-0.23 * r, 2.02 * r) : p(0.55 * r, 2.12 * r)
        SnowArt.circle(pom, radius: r * 0.25, color: SnowArt.color(0xC5D9E4), in: hat).zPosition = 2
        SnowArt.circle(p(pom.x - r * 0.04, pom.y + r * 0.04), radius: r * 0.23, color: SnowArt.color(0xF5FAFC), in: hat).zPosition = 3
    }
    private static func furBand(radius r: CGFloat, in parent: SKNode) {
        let band = CGMutablePath(); band.move(to: p(-0.88, 0.72))
        band.addQuadCurve(to: p(-0.78, 1.12), control: p(-1.00, 0.98))
        band.addQuadCurve(to: p(0.80, 1.12), control: p(0, 1.31))
        band.addQuadCurve(to: p(0.89, 0.73), control: p(1.02, 0.98))
        band.addQuadCurve(to: p(-0.88, 0.72), control: p(0, 0.94)); band.closeSubpath()
        let node = fill(band, scale: r, color: 0xF3F9FB, in: parent, z: 4, name: "snowman.hat.fur")
        node.strokeColor = SnowArt.color(0xBACFDD); node.lineWidth = 0.6
        let seam = CGMutablePath(); seam.move(to: p(-r * 0.75, r * 0.76)); seam.addQuadCurve(to: p(r * 0.76, r * 0.77), control: p(0, r * 1.00))
        line(seam, color: 0xD5E4EC, width: r * 0.065, in: parent, z: 5)
    }
    private static func knittedHat(radius r: CGFloat, in parent: SKNode) {
        let hat = SKNode(); hat.name = "snowman.hat.knitted"; hat.zPosition = 6; parent.addChild(hat)
        let dome = CGMutablePath(); dome.move(to: p(-0.82, 1.01))
        dome.addCurve(to: p(0, 1.90), control1: p(-0.75, 1.60), control2: p(-0.43, 1.91))
        dome.addCurve(to: p(0.84, 1.01), control1: p(0.51, 1.91), control2: p(0.75, 1.57)); dome.closeSubpath()
        fill(dome, scale: r, color: blue, in: hat)
        let stripe = CGMutablePath(); stripe.move(to: p(-r * 0.70, r * 1.38)); stripe.addLine(to: p(r * 0.70, r * 1.38))
        line(stripe, color: 0xD85750, width: r * 0.055, in: hat, z: 1)
        for index in 0..<6 {
            let x = -0.70 + CGFloat(index) * 0.235
            let motif = CGMutablePath(); motif.move(to: p(x * r, 1.40 * r)); motif.addLine(to: p((x + 0.115) * r, 1.60 * r)); motif.addLine(to: p((x + 0.23) * r, 1.40 * r))
            line(motif, color: 0xD85750, width: max(0.65, r * 0.035), in: hat, z: 2)
        }
        SnowArt.circle(p(0, r * 1.99), radius: r * 0.245, color: SnowArt.color(0xD3E3EC), in: hat).zPosition = 1
        SnowArt.circle(p(-r * 0.04, r * 2.04), radius: r * 0.21, color: SnowArt.color(0xF6FBFC), in: hat).zPosition = 2
        furBand(radius: r, in: hat)
    }
    private static func bucket(radius r: CGFloat, in parent: SKNode) {
        let bucket = SKNode(); bucket.name = "snowman.bucket"; bucket.zPosition = 6
        bucket.position.y = r * 0.78; bucket.zRotation = -0.10; parent.addChild(bucket)
        let body = SnowArt.polygon([p(-r * 0.82, 0), p(r * 0.82, 0), p(r * 0.58, r * 0.95), p(-r * 0.58, r * 0.95)], color: SnowArt.color(0x8B9CA7), in: bucket)
        body.strokeColor = SnowArt.color(0x5C7586); body.lineWidth = 0.7
        SnowArt.polygon([p(r * 0.38, r * 0.03), p(r * 0.82, 0), p(r * 0.58, r * 0.95), p(r * 0.31, r * 0.95)], color: SnowArt.color(0x6B8291), in: bucket).zPosition = 1
        SnowArt.polygon([p(-r * 0.62, r * 0.12), p(-r * 0.32, r * 0.12), p(-r * 0.27, r * 0.82), p(-r * 0.45, r * 0.82)], color: SnowArt.color(0xCEDDE4), in: bucket).zPosition = 2
        SnowArt.rect(CGRect(x: -r * 0.90, y: -r * 0.04, width: r * 1.80, height: max(2, r * 0.13)), color: SnowArt.color(0xB9CEDA), radius: 1, in: bucket).zPosition = 3
        let handle = CGMutablePath(); handle.move(to: p(-r * 0.50, r * 0.76))
        handle.addCurve(to: p(-r * 0.62, r * 0.10), control1: p(-r * 1.03, r * 1.05), control2: p(-r * 1.08, r * 0.08))
        line(handle, color: 0x5C7586, width: 1, in: bucket, z: -1, name: "snowman.bucket.handle")
    }
    private static func scarf(radius r: CGFloat, variant: SnowmanVariant, in parent: SKNode) {
        let blueScarf = variant == .winterBroom || variant == .classicBucket
        let main = blueScarf ? blue : red, shade = blueScarf ? blueShade : redShade
        let scarf = SKNode(); scarf.name = "snowman.scarf"; scarf.zPosition = 7; parent.addChild(scarf)
        let tail = SKNode(); tail.name = "snowman.scarf.tail"
        tail.position = p((variant == .festive || variant == .waving ? 0.52 : -0.30) * r, -r * 0.91); scarf.addChild(tail)
        let path = CGMutablePath()
        if variant == .festive {
            path.move(to: p(-0.12, 0.10)); path.addQuadCurve(to: p(2.25, 0.35), control: p(1.1, 0.47))
            path.addQuadCurve(to: p(2.37, -0.47), control: p(2.16, -0.05))
            path.addQuadCurve(to: p(-0.15, -0.36), control: p(1.15, -0.70)); path.closeSubpath()
        } else if variant == .waving {
            path.move(to: p(-0.18, 0.10)); path.addLine(to: p(0.34, 0.05))
            path.addCurve(to: p(0.59, -2.84), control1: p(0.48, -0.97), control2: p(0.90, -2.30))
            path.addQuadCurve(to: p(-0.17, -2.96), control: p(0.13, -3.00))
            path.addQuadCurve(to: p(-0.18, 0.10), control: p(-0.48, -1.55)); path.closeSubpath()
        } else {
            path.move(to: p(-0.22, 0.10)); path.addLine(to: p(0.23, 0.10))
            path.addQuadCurve(to: p(0.22, -3.02), control: p(0.12, -1.60))
            path.addLine(to: p(-0.25, -3.02)); path.addQuadCurve(to: p(-0.22, 0.10), control: p(-0.30, -1.60)); path.closeSubpath()
        }
        fill(path, scale: r, color: main, in: tail)
        if variant == .festive {
            for spot in [p(0.47, -0.03), p(0.97, 0.09), p(1.40, -0.27), p(1.90, 0.12), p(2.08, -0.26)] {
                SnowArt.circle(p(spot.x * r, spot.y * r), radius: r * 0.065, color: SnowArt.color(0xF5E7DF), in: tail).zPosition = 1
            }
        } else if blueScarf {
            for y: CGFloat in [-2.45, -2.65] {
                SnowArt.rect(CGRect(x: -r * 0.22, y: y * r, width: r * 0.45, height: r * 0.065), color: SnowArt.color(variant == .winterBroom ? 0xD65B51 : 0x83C0D2), in: tail).zPosition = 1
            }
            for index in 0..<6 {
                let fringe = CGMutablePath(); let x = (-0.22 + CGFloat(index) * 0.085) * r
                fringe.move(to: p(x, -3 * r)); fringe.addLine(to: p(x, -3.22 * r))
                line(fringe, color: variant == .winterBroom ? 0xCE514A : blueShade, width: max(0.6, r * 0.045), in: tail, z: 1)
            }
        }
        if variant == .classicBucket {
            let second = SnowArt.rect(CGRect(x: r * 0.28, y: -r * 3.20, width: r * 0.38, height: r * 2.30), color: SnowArt.color(blue), radius: r * 0.05, in: scarf)
            second.name = "snowman.scarf.secondTail"
            for y: CGFloat in [-2.75, -2.95] {
                SnowArt.rect(CGRect(x: r * 0.28, y: y * r, width: r * 0.38, height: r * 0.06), color: SnowArt.color(0x83C0D2), in: scarf).zPosition = 1
            }
        }
        let band = CGMutablePath(); band.move(to: p(-0.78, -0.72))
        band.addCurve(to: p(0.78, -0.72), control1: p(-0.30, -0.84), control2: p(0.30, -0.84))
        band.addCurve(to: p(0.72, -0.96), control1: p(0.90, -0.77), control2: p(0.86, -0.93))
        band.addCurve(to: p(-0.72, -0.96), control1: p(0.25, -1.08), control2: p(-0.25, -1.08))
        band.addCurve(to: p(-0.78, -0.72), control1: p(-0.86, -0.93), control2: p(-0.90, -0.77)); band.closeSubpath()
        fill(band, scale: r, color: shade, in: scarf, z: 1, name: "snowman.scarf.collar")
        SnowArt.circle(p(tail.position.x, -r * 0.90), radius: r * 0.15, color: SnowArt.color(main), in: scarf).zPosition = 2
    }
    private static func mitten(at point: CGPoint, radius r: CGFloat, rotation: CGFloat, in parent: SKNode) {
        let mitten = SKNode(); mitten.name = "snowman.mitten"; mitten.position = point; mitten.zRotation = rotation; mitten.zPosition = 4; parent.addChild(mitten)
        let shape = CGMutablePath(); shape.move(to: p(-0.24, -0.20)); shape.addLine(to: p(0.22, -0.20))
        shape.addCurve(to: p(0.29, 0.68), control1: p(0.47, 0.06), control2: p(0.48, 0.53))
        shape.addCurve(to: p(-0.20, 0.48), control1: p(0.12, 0.90), control2: p(-0.25, 0.78))
        shape.addQuadCurve(to: p(-0.46, 0.35), control: p(-0.37, 0.68))
        shape.addQuadCurve(to: p(-0.24, -0.20), control: p(-0.65, 0.12)); shape.closeSubpath()
        fill(shape, scale: r, color: red, in: mitten)
        SnowArt.rect(CGRect(x: -r * 0.27, y: -r * 0.28, width: r * 0.53, height: r * 0.20), color: SnowArt.color(redShade), radius: r * 0.05, in: mitten).zPosition = 1
        ellipse(CGRect(x: -r * 0.06, y: r * 0.25, width: r * 0.23, height: r * 0.36), color: 0xED8B77, in: mitten, z: 1)
    }
    private static func broom(at grip: CGPoint, bottom: CGFloat, radius r: CGFloat, in parent: SKNode) {
        let broom = SKNode(); broom.name = "snowman.broom"; broom.position = grip; broom.zPosition = -4; parent.addChild(broom)
        let shaft = CGMutablePath(); shaft.move(to: p(r * 0.36, bottom - grip.y)); shaft.addLine(to: p(-r * 0.22, r * 3.1))
        line(shaft, color: 0x505558, width: r * 0.13, in: broom)
        let brush = CGMutablePath(); brush.move(to: p(-0.54, 2.84)); brush.addLine(to: p(0.16, 2.84))
        brush.addQuadCurve(to: p(0.62, 4.68), control: p(0.58, 3.78)); brush.addQuadCurve(to: p(-1.13, 4.62), control: p(-0.13, 4.89))
        brush.addQuadCurve(to: p(-0.54, 2.84), control: p(-0.95, 3.62)); brush.closeSubpath()
        fill(brush, scale: r, color: 0x929A9F, in: broom, z: 1)
        for index in 0..<9 {
            let x = -1.03 + CGFloat(index) * 0.20
            let straw = CGMutablePath(); straw.move(to: p((x + 0.02) * r, (4.58 + CGFloat(index % 3) * 0.07) * r))
            straw.addQuadCurve(to: p((-0.50 + CGFloat(index) * 0.07) * r, 2.89 * r), control: p(x * r, 3.78 * r))
            line(straw, color: index.isMultiple(of: 2) ? 0x56626B : 0xC7CFD1, width: max(0.65, r * 0.048), in: broom, z: 2)
        }
        for y: CGFloat in [2.94, 3.04, 3.14] {
            let tie = CGMutablePath(); tie.move(to: p(-r * 0.58, y * r)); tie.addLine(to: p(r * 0.21, (y + 0.05) * r))
            line(tie, color: 0xD7AE56, width: max(0.8, r * 0.055), in: broom, z: 3)
        }
    }
    private static func fixture(_ variant: SnowmanVariant) -> (SnowGame, SnowSurface) {
        let surface = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: 300, height: 300), visible: [.init(0, 300)], isBottom: true)
        var top: CGFloat = 30
        let balls = [CGFloat(40), 28, 19].enumerated().map { index, radius -> Snowball in
            var ball = Snowball(id: UInt64(9_000_000 + index), radius: radius, position: p(150, top + radius))
            ball.surfaceID = surface.id; ball.localX = 150; ball.anchorHeight = top + radius
            ball.supportID = index == 0 ? nil : ball.id - 1; top += radius * 2
            return ball
        }
        return (SnowGame(balls: balls, variantCycle: SnowmanVariantCycle(start: variant.rawValue)), surface)
    }
    static func validationChecks() -> [String: Bool] {
        var checks: [String: Bool] = [:]
        for variant in SnowmanVariant.allCases {
            let (game, surface) = fixture(variant), renderer = SnowDecorationRenderer()
            let original = game.snowmanVariants()
            for appearance in SnowAppearance.allCases {
                renderer.drawGame(game, surfaces: [surface], reduceMotion: true, appearance: appearance)
                let scene = SKScene(size: surface.frame.size); scene.backgroundColor = SnowArt.color(0x183344)
                scene.addChild(renderer.root)
                let view = SKView(frame: surface.frame); view.ignoresSiblingOrder = true; view.presentScene(scene)
                var visible = false
                if let texture = view.texture(from: scene, crop: surface.frame), let head = game.balls.last {
                    let image = NSBitmapImageRep(cgImage: texture.cgImage())
                    func color(_ x: CGFloat, _ y: CGFloat) -> NSColor {
                        let point = p(head.position.x + x * head.radius, head.position.y + y * head.radius)
                        let px = min(image.pixelsWide - 1, max(0, Int(point.x / scene.size.width * CGFloat(image.pixelsWide))))
                        let py = min(image.pixelsHigh - 1, max(0, Int((scene.size.height - point.y) / scene.size.height * CGFloat(image.pixelsHigh))))
                        return image.colorAt(x: px, y: py)!.usingColorSpace(.sRGB)!
                    }
                    func dark(_ c: NSColor) -> Bool { c.redComponent < 0.45 && c.greenComponent < 0.5 && c.blueComponent < 0.55 }
                    let nose = color(0.08, -0.12)
                    visible = dark(color(-0.28, 0.25)) && dark(color(0.28, 0.25)) && dark(color(0, -0.44))
                        && nose.redComponent > 0.6 && nose.greenComponent > 0.3 && nose.blueComponent < 0.5
                    if !visible { fputs("Snowman face pixels: \(variant.rawValue) \(appearance.rawValue), left=\(color(-0.28, 0.25)), right=\(color(0.28, 0.25)), mouth=\(color(0, -0.44)), nose=\(nose)\n", stderr) }
                }
                var mittens = 0
                renderer.root.enumerateChildNodes(withName: "//snowman.mitten") { _, _ in mittens += 1 }
                let accessories: Bool
                switch variant {
                case .festive: accessories = renderer.root.childNode(withName: "//snowman.hat.santa") != nil && renderer.root.childNode(withName: "//snowman.heldSnowball") != nil
                case .winterBroom: accessories = renderer.root.childNode(withName: "//snowman.hat.knitted") != nil && renderer.root.childNode(withName: "//snowman.broom") != nil
                case .classicBucket: accessories = renderer.root.childNode(withName: "//snowman.bucket") != nil && renderer.root.childNode(withName: "//snowman.heldSnowball") != nil
                case .waving: accessories = renderer.root.childNode(withName: "//snowman.hat.santa") != nil && mittens == 2
                }
                checks["snowmanVariant.\(variant.rawValue).\(appearance.rawValue)"] = visible && accessories
                    && renderer.root.childNode(withName: "//snowman.scarf") != nil
                    && game.snowmanVariants() == original
                if !visible || !accessories {
                    fputs("Snowman render detail: variant=\(variant.rawValue), appearance=\(appearance.rawValue), face=\(visible), accessories=\(accessories), mittens=\(mittens)\n", stderr)
                }
                renderer.root.removeFromParent(); view.presentScene(nil)
            }
            let face = renderer.root.childNode(withName: "//snowman.face")
            renderer.drawGame(game, surfaces: [surface], reduceMotion: true, appearance: .textured)
            checks["snowmanVariantStable.\(variant.rawValue)"] = game.snowmanVariants() == original
                && face === renderer.root.childNode(withName: "//snowman.face")
        }
        return checks
    }
    static func renderPreviews(to directory: URL) throws -> [String: Bool] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let size = CGSize(width: 1200, height: 360), scene = SKScene(size: CGSize(width: 1200, height: 360))
        scene.backgroundColor = SnowArt.color(0x101215)
        for variant in SnowmanVariant.allCases {
            let x = CGFloat(variant.rawValue) * 300
            let card = SnowArt.rect(CGRect(x: x + 8, y: 8, width: 284, height: 344), color: SnowArt.color(0x191D23), radius: 18, in: scene)
            card.strokeColor = SnowArt.color(0x343B45); card.lineWidth = 0.8
            let shadow = SKShapeNode(ellipseIn: CGRect(x: x + 95, y: 37, width: 110, height: 10))
            shadow.fillColor = SnowArt.color(0xA8C9D9, alpha: 0.13); shadow.strokeColor = .clear; shadow.zPosition = 1; scene.addChild(shadow)
            let (game, surface) = fixture(variant), renderer = SnowDecorationRenderer()
            renderer.drawGame(game, surfaces: [surface], reduceMotion: true, appearance: .textured)
            renderer.root.setScale(1.30); renderer.root.position = p(x + 150 - 150 * 1.30, 42 - 30 * 1.30)
            scene.addChild(renderer.root)
            let label = SKLabelNode(fontNamed: NSFont.systemFont(ofSize: 15, weight: .medium).fontName)
            label.text = tr("snowman.variant.\(variant.rawValue)"); label.fontSize = 15
            label.fontColor = SnowArt.color(0xD0DBE2); label.position = p(x + 150, 17); label.zPosition = 20
            scene.addChild(label)
        }
        let view = SKView(frame: CGRect(origin: .zero, size: size)); view.ignoresSiblingOrder = true; view.presentScene(scene)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { throw ImportFailure.invalidImage }
        try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snowmen.png"), options: .atomic)
        for variant in SnowmanVariant.allCases {
            let crop = CGRect(x: CGFloat(variant.rawValue) * 300, y: 0, width: 300, height: 360)
            guard let texture = view.texture(from: scene, crop: crop) else { throw ImportFailure.invalidImage }
            try ImportedAssets.png(texture.cgImage()).write(to: directory.appendingPathComponent("snowman-\(variant.rawValue).png"), options: .atomic)
        }
        view.presentScene(nil)
        return validationChecks()
    }
}
