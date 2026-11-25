import Foundation
import CoreGraphics

/// Session-only decoration. Uses the scene clock, with no independent timers.
public struct HolidayTree {
    public static let growthDuration: Double = 1.25
    public static let treeCount = 5
    public static let layoutCount = 6
    public static let sizeMultiplier: CGFloat = 1.25
    public static let artSize = CGSize(width: 180, height: 270)
    public static let renderBounds = CGRect(x: -96, y: -6, width: 192, height: 290)
    public static let trunkHeight: CGFloat = 42
    public static let rootInset: CGFloat = 6
    public private(set) var isVisible = false
    public private(set) var growth: Double = 0
    private var randomState: UInt64
    private var layoutIndex: Int?
    private struct Placement {
        let x: CGFloat
        let height: CGFloat
        let delay: Double
        init(_ x: CGFloat, _ height: CGFloat, _ delay: Double) {
            self.x = x; self.height = height; self.delay = delay
        }
    }
    /// Ready-made arrangements across the whole lower edge. Selection runs on
    /// enable only; frame updates read the same five placements without RNG.
    private static let layouts: [[Placement]] = [
        [.init(0.06, 100, 0.00), .init(0.26, 74, 0.16), .init(0.48, 90, 0.06), .init(0.72, 64, 0.25), .init(0.92, 82, 0.12)],
        [.init(0.12, 72, 0.10), .init(0.34, 96, 0.00), .init(0.55, 62, 0.24), .init(0.76, 100, 0.08), .init(0.94, 84, 0.18)],
        [.init(0.05, 82, 0.22), .init(0.22, 100, 0.04), .init(0.43, 70, 0.14), .init(0.65, 94, 0.00), .init(0.86, 62, 0.28)],
        [.init(0.15, 98, 0.00), .init(0.38, 76, 0.24), .init(0.57, 100, 0.09), .init(0.78, 66, 0.18), .init(0.96, 86, 0.04)],
        [.init(0.04, 68, 0.16), .init(0.29, 88, 0.00), .init(0.51, 100, 0.24), .init(0.70, 76, 0.08), .init(0.90, 94, 0.18)],
        [.init(0.09, 90, 0.26), .init(0.31, 64, 0.10), .init(0.46, 82, 0.00), .init(0.68, 100, 0.18), .init(0.89, 74, 0.06)]
    ]
    public init(seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
        randomState = seed
    }

    public mutating func grow(reduceMotion: Bool) {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        if let previous = layoutIndex {
            let choice = Int((randomState >> 32) % UInt64(Self.layouts.count - 1))
            layoutIndex = choice >= previous ? choice + 1 : choice
        } else {
            layoutIndex = Int((randomState >> 32) % UInt64(Self.layouts.count))
        }
        isVisible = true; growth = reduceMotion ? 1 : 0
    }
    public mutating func remove() { isVisible = false; growth = 0 }
    public mutating func step(delta: Double, reduceMotion: Bool) {
        guard isVisible else { return }
        if reduceMotion { growth = 1; return }
        guard delta.isFinite else { return }
        growth = min(1, growth + min(1.0 / 15, max(0, delta)) / Self.growthDuration)
    }
    public func appearances(in size: CGSize, ground: SnowProfile? = nil) -> [HolidayTreeAppearance] {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 16 else { return [] }
        let inset = min(24, size.width * 0.04)
        let layoutScale = min(1, max(0, (size.width - inset * 2) / 640), max(0, (size.height - 16) / (112 * Self.sizeMultiplier)))
        return Self.layouts[layoutIndex ?? 0].enumerated().map { index, placement in
            let scale = placement.height / Self.artSize.height * layoutScale * Self.sizeMultiplier
            let halfWidth = Self.renderBounds.width / 2 * scale * 0.9
            let x = max(halfWidth + layoutScale, min(size.width - halfWidth - layoutScale,
                        inset + placement.x * (size.width - inset * 2)))
            let progress = min(1, max(0, (growth * Self.growthDuration - placement.delay) / 0.9))
            let ease = 1 - pow(1 - progress, 3)
            let snow = min(ground?.height(at: x) ?? 0, max(0, size.height - Self.renderBounds.height * scale))
            let settledY = max(-Self.rootInset * scale, snow - (Self.trunkHeight + Self.rootInset) * scale)
            // Every tree starts wholly below the display, including when the
            // final roots sit on a deep snowbank. The snow renderer covers them.
            let y = settledY - (1 - ease) * (max(0, settledY) + (Self.artSize.height + 20) * scale)
            return HolidayTreeAppearance(id: index, position: CGPoint(x: x, y: y),
                                         xScale: scale * 0.9 * (0.93 + 0.07 * ease), yScale: scale * (0.94 + 0.06 * ease),
                                         opacity: isVisible ? min(1, progress * 6) : 0,
                                         lightsOpacity: max(0, min(1, (progress - 0.65) / 0.35)))
        }
    }
}

public struct HolidayTreeAppearance: Equatable {
    public let id: Int
    public let position: CGPoint
    public let xScale: CGFloat
    public let yScale: CGFloat
    public let opacity: Double
    public let lightsOpacity: Double
}
