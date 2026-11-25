import AppKit
import SpriteKit

/// Two original vector tractors, inspired by the supplied flat/outlined references.
enum TractorArt {
    @discardableResult private static func shape(_ path: CGPath, color: NSColor, outline: NSColor, width: CGFloat, in parent: SKNode) -> SKShapeNode {
        let node = SKShapeNode(path: path); node.fillColor = color; node.strokeColor = outline
        node.lineWidth = width; node.lineJoin = .round; node.lineCap = .round; parent.addChild(node); return node
    }
    @discardableResult private static func line(_ points: [CGPoint], color: NSColor, width: CGFloat, in parent: SKNode) -> SKShapeNode {
        let path = CGMutablePath(); path.addLines(between: points)
        let node = shape(path, color: .clear, outline: color, width: width, in: parent); node.zPosition = 1; return node
    }
    private static func wheel(radius: CGFloat, retro: Bool, name: String) -> SKNode {
        let node = SKNode(); node.name = name
        let dark = SnowArt.color(retro ? 0x202634 : 0x29495D)
        let tire = SnowArt.circle(.zero, radius: radius, color: SnowArt.color(retro ? 0x8991B5 : 0x2D4F64), in: node)
        tire.strokeColor = dark; tire.lineWidth = retro ? 3 : 1
        let count = retro ? 10 : 22
        for index in 0..<count {
            let tread = SKNode(); let angle = CGFloat(index) * .pi * 2 / CGFloat(count)
            tread.position = CGPoint(x: cos(angle) * (radius - 1.6), y: sin(angle) * (radius - 1.6)); tread.zRotation = angle; tread.zPosition = 1
            SnowArt.rect(CGRect(x: -2.6, y: -1.5, width: retro ? 6 : 4.7, height: 3),
                         color: retro ? dark : SnowArt.color(0x3B6075), radius: 1, in: tread)
            node.addChild(tread)
        }
        let rim = SnowArt.circle(.zero, radius: radius * 0.58, color: SnowArt.color(retro ? 0x717B9E : 0xE0E8EB), in: node)
        rim.zPosition = 2; rim.strokeColor = dark; rim.lineWidth = retro ? 2.8 : 0.7
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2 + 0.3
            SnowArt.circle(CGPoint(x: cos(angle) * radius * 0.39, y: sin(angle) * radius * 0.39), radius: max(1, radius * 0.055),
                           color: SnowArt.color(index == 0 ? 0xE8B46B : (retro ? 0xCFD4E7 : 0x9AAFB9)), in: node).zPosition = 3
        }
        let hub = SnowArt.circle(.zero, radius: radius * 0.22, color: retro ? SnowArt.color(0xE9E8EE) : dark, in: node)
        hub.zPosition = 4; hub.strokeColor = dark; hub.lineWidth = retro ? 2.4 : 0
        return node
    }

    static func make(_ character: CleanerCharacter, blade: NSImage?) -> SKNode {
        let root = SKNode(); root.name = "cleaner.tractor"
        let retro = character == .retro
        let paint = SnowArt.color(retro ? 0xEF627B : 0xE96756)
        let dark = SnowArt.color(retro ? 0x202634 : 0x2C4757)
        let border = retro ? dark : NSColor.clear
        let stroke: CGFloat = retro ? 2.7 : 0
        let body = SKNode(); body.name = "cleaner.cabAndBody"; body.zPosition = 2; root.addChild(body)
        let chassis = SnowArt.polygon([.init(x: -48, y: 15), .init(x: 53, y: 15), .init(x: 55, y: 34),
                                      .init(x: 7, y: 40), .init(x: -44, y: 38)], color: dark, in: body)
        chassis.zPosition = 0
        let hood = CGMutablePath(); hood.move(to: CGPoint(x: -4, y: 24)); hood.addLine(to: CGPoint(x: -4, y: 58))
        hood.addCurve(to: CGPoint(x: 52, y: 47), control1: CGPoint(x: 21, y: 61), control2: CGPoint(x: 45, y: 58))
        hood.addQuadCurve(to: CGPoint(x: 56, y: 25), control: CGPoint(x: 57, y: 44))
        hood.addLine(to: CGPoint(x: 37, y: 17)); hood.closeSubpath()
        shape(hood, color: paint, outline: border, width: stroke, in: body).zPosition = 2
        let cab = CGMutablePath(); cab.addLines(between: [.init(x: -35, y: 43), .init(x: -31, y: 91), .init(x: -4, y: 91), .init(x: 6, y: 42)])
        cab.closeSubpath()
        shape(cab, color: SnowArt.color(retro ? 0xC4DCE6 : 0x3B5C70), outline: retro ? dark : SnowArt.color(0xF8D16A), width: retro ? 3 : 2.7, in: body).zPosition = 3
        if retro {
            line([.init(x: -18, y: 43), .init(x: -18, y: 90)], color: dark, width: 3, in: body)
            let bar = SnowArt.rect(CGRect(x: -19.5, y: 44, width: 3, height: 46), color: paint, in: body); bar.zPosition = 4
            bar.strokeColor = dark; bar.lineWidth = 1.8
            line([.init(x: -29, y: 54), .init(x: -7, y: 80)], color: NSColor.white.withAlphaComponent(0.5), width: 1.6, in: body).zPosition = 4
        } else {
            let shine = SnowArt.polygon([.init(x: -28, y: 86), .init(x: -20, y: 86), .init(x: -24, y: 46), .init(x: -31, y: 46)],
                                        color: NSColor.white.withAlphaComponent(0.12), in: body); shine.zPosition = 4
        }
        let roof = CGMutablePath(); roof.move(to: CGPoint(x: -38, y: 91))
        roof.addQuadCurve(to: CGPoint(x: -33, y: 98), control: CGPoint(x: -39, y: 96))
        roof.addQuadCurve(to: CGPoint(x: 1, y: 98), control: CGPoint(x: -14, y: 100))
        roof.addQuadCurve(to: CGPoint(x: 6, y: 91), control: CGPoint(x: 5, y: 98)); roof.closeSubpath()
        shape(roof, color: retro ? SnowArt.color(0xE5E6F0) : paint, outline: border, width: stroke, in: body).zPosition = 5

        let exhaust = SKNode(); exhaust.zPosition = 1; root.addChild(exhaust)
        if retro {
            let pipe = CGMutablePath(); pipe.move(to: CGPoint(x: 22, y: 57)); pipe.addLine(to: CGPoint(x: 22, y: 85))
            pipe.addQuadCurve(to: CGPoint(x: 29, y: 96), control: CGPoint(x: 21, y: 91)); pipe.addLine(to: CGPoint(x: 37, y: 100))
            shape(pipe, color: .clear, outline: dark, width: 8, in: exhaust)
            shape(pipe, color: .clear, outline: SnowArt.color(0xB8BDD0), width: 3.8, in: exhaust)
            let muffler = SnowArt.rect(CGRect(x: 17.5, y: 59, width: 9, height: 22), color: SnowArt.color(0x7E89AB), radius: 1.4, in: exhaust)
            muffler.zPosition = 2; muffler.strokeColor = dark; muffler.lineWidth = 2
            for x: CGFloat in [14, 25] { line([.init(x: x, y: 44), .init(x: x + 2.2, y: 39)], color: dark, width: 2.7, in: body).zPosition = 4 }
        } else {
            SnowArt.rect(CGRect(x: 21, y: 57, width: 5, height: 25), color: dark, in: exhaust)
            SnowArt.rect(CGRect(x: 18, y: 79, width: 11, height: 5), color: SnowArt.color(0x3C5D70), radius: 1, in: exhaust)
            SnowArt.polygon([.init(x: 41, y: 46), .init(x: 51, y: 42), .init(x: 51, y: 27), .init(x: 41, y: 29)], color: SnowArt.color(0x3C5D70), in: body).zPosition = 4
        }

        let rear = wheel(radius: CleanerGeometry.rearWheelRadius, retro: retro, name: "cleaner.wheel.rear")
        // SpriteKit adds ancestor z positions: the cab's highlights reach z=7.
        // Keep the entire wheel (including its tire) in front of the cab.
        rear.position = CGPoint(x: -29, y: CleanerGeometry.rearWheelRadius); rear.zPosition = 10; root.addChild(rear)
        let front = wheel(radius: CleanerGeometry.frontWheelRadius, retro: retro, name: "cleaner.wheel.front")
        front.position = CGPoint(x: 40, y: CleanerGeometry.frontWheelRadius); front.zPosition = 10; root.addChild(front)
        let fender = CGMutablePath(); fender.move(to: CGPoint(x: -56, y: 40))
        fender.addCurve(to: CGPoint(x: -2, y: 29), control1: CGPoint(x: -44, y: 65), control2: CGPoint(x: -11, y: 63))
        let fenderNode = SKNode(); fenderNode.zPosition = 15; root.addChild(fenderNode)
        if retro { shape(fender, color: .clear, outline: dark, width: 9, in: fenderNode) }
        shape(fender, color: .clear, outline: paint, width: retro ? 4.5 : 6, in: fenderNode).zPosition = 1

        let arm = SKNode(); arm.zPosition = 3; root.addChild(arm)
        line([.init(x: 8, y: 24), .init(x: 53, y: 39), .init(x: 72, y: 17)], color: dark, width: 5, in: arm)
        line([.init(x: 26, y: 26), .init(x: 61, y: 22)], color: SnowArt.color(0xD3DCE0), width: 2.4, in: arm)
        for point in [CGPoint(x: 11, y: 25), .init(x: 53, y: 39), .init(x: 70, y: 18)] {
            SnowArt.circle(point, radius: 2.6, color: SnowArt.color(0xE2BC69), in: arm).zPosition = 2
        }
        let bucket = SKNode(); bucket.name = "cleaner.bucket"; bucket.zPosition = 20; root.addChild(bucket)
        let scoop = CGMutablePath(); scoop.addLines(between: [.init(x: 59, y: 11), .init(x: 65, y: 1), .init(x: 90, y: 1),
                                                           .init(x: 98, y: 30), .init(x: 90, y: 32), .init(x: 80, y: 12)])
        scoop.closeSubpath()
        shape(scoop, color: SnowArt.color(retro ? 0xB0B5CA : 0xB2C8D1), outline: dark, width: retro ? 2.7 : 1.2, in: bucket)
        line([.init(x: 66, y: 4), .init(x: 88, y: 4), .init(x: 95, y: 29)], color: SnowArt.color(0xE9F0F2), width: 1.7, in: bucket)
        if let blade {
            let image = SKSpriteNode(texture: SKTexture(image: blade)); image.name = "cleaner.bucket.image"
            image.position = CGPoint(x: 77, y: 8); image.size = CGSize(width: 14, height: 9); image.zPosition = 2; bucket.addChild(image)
        }
        let load = SKNode(); load.name = "cleaner.bucket.snow"; load.position = CGPoint(x: 76, y: 12); load.zPosition = 3; bucket.addChild(load)
        let pile = CGMutablePath(); pile.move(to: CGPoint(x: -12, y: 0))
        pile.addCurve(to: CGPoint(x: 12, y: 1), control1: CGPoint(x: -10, y: 16), control2: CGPoint(x: 6, y: 18))
        pile.closeSubpath(); shape(pile, color: SnowArt.color(0xF1F7F9), outline: .clear, width: 0, in: load)
        return root
    }
}
