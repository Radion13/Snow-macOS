import Foundation
import CoreGraphics

public struct SnowProfile: Equatable {
    public private(set) var heights: [CGFloat]
    public private(set) var width: CGFloat
    public var maximum: CGFloat
    public let variationSeed: UInt64?
    public let roundedEdges: Bool
    public static let spacing: CGFloat = 8
    public init(width: CGFloat, maximum: CGFloat, variationSeed: UInt64? = nil, roundedEdges: Bool = false) {
        self.width = max(1, width); self.maximum = maximum
        self.variationSeed = variationSeed; self.roundedEdges = roundedEdges
        heights = .init(repeating: 0, count: Self.sampleCount(width))
    }
    private static func sampleCount(_ width: CGFloat) -> Int { min(2048, max(2, Int(ceil(max(1, width) / spacing)) + 1)) }
    public func height(at x: CGFloat) -> CGFloat {
        let position = min(CGFloat(heights.count - 1), max(0, x / width * CGFloat(heights.count - 1)))
        let index = Int(position); let next = min(heights.count - 1, index + 1)
        return heights[index] + (heights[next] - heights[index]) * (position - CGFloat(index))
    }
    public var edgeInset: CGFloat { roundedEdges ? min(width / 3, max(16, maximum * 1.2)) : 0 }
    private func edgeFactor(at x: CGFloat) -> CGFloat {
        guard roundedEdges else { return 1 }
        let t = min(1, max(0, min(x, width - x) / edgeInset))
        return sqrt(max(0, 1 - (1 - t) * (1 - t)))
    }
    private func ceiling(at x: CGFloat) -> CGFloat {
        var cap = maximum
        if let seed = variationSeed {
            func noise(_ distance: CGFloat, salt: UInt64) -> CGFloat {
                let cell = UInt64(max(0, floor(distance))); let t = distance - floor(distance)
                func value(_ i: UInt64) -> CGFloat {
                    var h = (i &+ seed &+ salt) &* 0x9E3779B97F4A7C15
                    h = (h ^ (h >> 30)) &* 0xBF58476D1CE4E5B9
                    h = (h ^ (h >> 27)) &* 0x94D049BB133111EB
                    return CGFloat(h ^ (h >> 31)) / CGFloat(UInt64.max)
                }
                let blend = t * t * (3 - 2 * t)
                return value(cell) + (value(cell &+ 1) - value(cell)) * blend
            }
            let phase = x / 22 + noise(x / 160, salt: 19) * 3 + CGFloat(seed % 127)
            let mound = 0.5 + 0.5 * cos(phase)
            cap *= 0.6 + 0.4 * (mound * 0.85 + noise(x / 173, salt: 71) * 0.15)
        }
        return max(0, cap * edgeFactor(at: x))
    }
    public mutating func resize(to newWidth: CGFloat, maximum: CGFloat) {
        let oldWidth = width
        let old = self
        width = max(1, newWidth); self.maximum = maximum
        // Retain local x coordinates. A wider window gets fresh snow-free space on the right.
        heights = (0..<Self.sampleCount(width)).map { index in
            let x = CGFloat(index) / CGFloat(Self.sampleCount(width) - 1) * width
            let wasMound = old.height(at: x) > old.ceiling(at: x) + 0.00000001
            let cap = wasMound ? max(ceiling(at: x), maximum * 1.8 * edgeFactor(at: x)) : ceiling(at: x)
            return x <= oldWidth ? min(cap, old.height(at: x)) : 0
        }
    }
    @discardableResult public mutating func deposit(at x: CGFloat, amount: CGFloat) -> CGFloat {
        guard x >= 0, x <= width else { return 0 }
        var overflow: CGFloat = 0
        for index in indices(near: x, radius: 18) {
            let sampleX = CGFloat(index) / CGFloat(heights.count - 1) * width
            let weight = max(0, 1 - abs(sampleX - x) / 18)
            let requested = max(0, heights[index] + amount * weight)
            // New snowfall must not erase a taller pile made with the mitten.
            heights[index] = max(heights[index], min(ceiling(at: sampleX), requested))
            overflow += max(0, requested - heights[index]) * width / CGFloat(heights.count - 1)
        }
        return overflow
    }
    @discardableResult public mutating func sweep(at x: CGFloat, radius: CGFloat) -> CGFloat {
        var removed: CGFloat = 0
        for index in indices(near: x, radius: radius) {
            let sampleX = CGFloat(index) / CGFloat(heights.count - 1) * width
            let fraction = max(0, 1 - abs(sampleX - x) / radius)
            let amount = heights[index] * fraction
            heights[index] -= amount; removed += amount
        }
        return removed
    }
    public mutating func clear() { heights = .init(repeating: 0, count: heights.count) }
    public var snowArea: CGFloat { heights.reduce(0, +) * width / CGFloat(heights.count - 1) }

    /// Return a held handful to the surface, allowing a bounded, hand-made mound.
    @discardableResult public mutating func placeSnow(at x: CGFloat, radius: CGFloat, area: CGFloat) -> CGFloat {
        addArea(at: x, radius: radius, area: area, excluding: [])
    }
    @discardableResult private mutating func addArea(at x: CGFloat, radius: CGFloat, area: CGFloat, excluding: Set<Int>) -> CGFloat {
        guard area > 0, area.isFinite, radius > 0, x + radius >= 0, x - radius <= width else { return 0 }
        let spacing = width / CGFloat(heights.count - 1)
        let candidates = indices(near: x, radius: radius).filter { !excluding.contains($0) }
        var remaining = area
        // Spread each portion over a smooth kernel instead of filling one sample
        // first, which produces a tall needle when a small handful lands.
        for _ in 0..<4 {
            let available = candidates.compactMap { index -> (Int, CGFloat, CGFloat)? in
                let sampleX = CGFloat(index) * spacing, t = abs(sampleX - x) / radius
                guard t < 1 else { return nil }
                let weight = pow(cos(t * .pi / 2), 2)
                let mound = maximum * 1.8 * edgeFactor(at: sampleX) * (0.5 + 0.5 * cos(t * .pi / 2))
                let capacity = max(0, max(ceiling(at: sampleX), mound) - heights[index]) * spacing
                return capacity > 0.000001 ? (index, weight, capacity) : nil
            }
            let weights = available.reduce(CGFloat(0)) { $0 + $1.1 }
            guard remaining > 0.000001, weights > 0 else { break }
            let portion = remaining
            for (index, weight, capacity) in available {
                let added = min(capacity, portion * weight / weights)
                heights[index] += added / spacing; remaining = max(0, remaining - added)
            }
        }
        return area - remaining
    }
    /// Conservative push for surfaces with no open edge, such as the screen floor.
    @discardableResult public mutating func push(at x: CGFloat, toward movement: CGFloat, radius: CGFloat = 24) -> CGFloat {
        push(at: x, toward: movement, radius: radius, spillLimit: 0).movedArea
    }
    /// Partition displacement into a neighboring mound and snow falling over a
    /// physical edge. A smooth kernel makes spilling gradual. Anything that
    /// cannot be represented within the caller's budget stays at its source.
    public mutating func push(at x: CGFloat, toward movement: CGFloat, radius: CGFloat = 24, spillLimit: CGFloat) -> SnowPushResult {
        guard x.isFinite, movement.isFinite, abs(movement) > 0.1, radius.isFinite, radius > 0 else { return .init() }
        let spacing = width / CGFloat(heights.count - 1), strength = min(0.85, abs(movement) / 22)
        var removed: [Int: CGFloat] = [:]; var area: CGFloat = 0
        for index in indices(near: x, radius: radius) {
            let weight = max(0, 1 - abs(CGFloat(index) * spacing - x) / radius)
            let amount = heights[index] * weight * strength
            removed[index] = amount; heights[index] -= amount; area += amount * spacing
        }
        guard area > 0 else { return .init() }
        let destination = x + (movement > 0 ? 1 : -1) * radius * 1.8, spread = radius * 1.4
        func cumulative(_ t: CGFloat) -> CGFloat {
            let value = min(1, max(-1, t))
            return (value + 1) / 2 + sin(.pi * value) / (2 * .pi)
        }
        let outside = movement < 0 ? cumulative(-destination / spread) : 1 - cumulative((width - destination) / spread)
        let requestedSpill = area * min(1, max(0, outside))
        let limit = spillLimit.isFinite ? max(0, spillLimit) : 0
        let spilled = min(requestedSpill, limit)
        let placed = addArea(at: destination, radius: spread, area: area - requestedSpill, excluding: Set(removed.keys))
        let accepted = placed + spilled
        for (index, amount) in removed { heights[index] += amount * (1 - accepted / area) }
        return .init(movedArea: accepted, spilledArea: spilled)
    }
    public mutating func merge(from other: SnowProfile, visible spans: [SnowInterval]) {
        for index in heights.indices {
            let x = CGFloat(index) / CGFloat(heights.count - 1) * width
            if spans.contains(where: { $0.contains(x) }) {
                let sourceX = min(x, other.width)
                let wasMound = other.height(at: sourceX) > other.ceiling(at: sourceX) + 0.00000001
                let cap = wasMound ? max(ceiling(at: x), maximum * 1.8 * edgeFactor(at: x)) : ceiling(at: x)
                let incoming = min(cap, other.height(at: sourceX))
                if heights[index] != incoming { heights[index] = incoming }
            }
        }
    }
    public var filledFraction: Double {
        Double(heights.filter { $0 >= maximum * 0.7 }.count) / Double(heights.count)
    }
    public func availableArea(at x: CGFloat, radius: CGFloat) -> CGFloat {
        let spacing = width / CGFloat(heights.count - 1)
        return indices(near: x, radius: radius).reduce(0) { $0 + heights[$1] * spacing }
    }
    /// Transfer snow area to a ball; never create mass or consume beyond the request.
    @discardableResult public mutating func takeSnow(at x: CGFloat, radius: CGFloat, maximumArea: CGFloat) -> CGFloat {
        guard maximumArea > 0 else { return 0 }
        let spacing = width / CGFloat(heights.count - 1)
        var removed: CGFloat = 0
        for index in indices(near: x, radius: radius) {
            let area = min(heights[index] * spacing, maximumArea - removed)
            heights[index] -= area / spacing; removed += area
            if removed >= maximumArea { break }
        }
        return removed
    }
    @discardableResult public mutating func clearRange(from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        var area: CGFloat = 0
        for index in heights.indices {
            let x = CGFloat(index) / CGFloat(heights.count - 1) * width
            if x >= lower && x <= upper {
                area += heights[index] * width / CGFloat(heights.count - 1)
                heights[index] = 0
            }
        }
        return area
    }
    private func indices(near x: CGFloat, radius: CGFloat) -> ClosedRange<Int> {
        let count = CGFloat(heights.count - 1)
        let lo = min(heights.count - 1, max(0, Int(floor((x - radius) / width * count))))
        let hi = min(heights.count - 1, max(lo, Int(ceil((x + radius) / width * count))))
        return lo...hi
    }
}

public struct SnowPushResult {
    public var movedArea: CGFloat = 0
    public var spilledArea: CGFloat = 0
}

/// Top and underside use the same smoothing, so empty snow has exactly zero
/// area. Real window ends turn vertically around the corner; visibility cuts
/// stay cuts rather than acquiring a false rounded edge.
public enum SnowContour {
    public static func path(surface: SnowSurface, profile: SnowProfile, span: SnowInterval) -> CGPath {
        let path = CGMutablePath()
        let lower = max(0, span.lower), upper = min(profile.width, span.upper)
        guard upper > lower else { return path }
        let count = min(480, max(1, Int(ceil((upper - lower) / SnowProfile.spacing))))
        var distances = (0...count).map { lower + (upper - lower) * CGFloat($0) / CGFloat(count) }
        if surface.cornerRadius > 0 {
            let radius = surface.cornerRadius
            for t: CGFloat in [0, 0.02, 0.04, 0.08, 0.16, 0.32, 0.5, 0.7, 0.85, 1] {
                for x in [radius * t, surface.length - radius * t] where x >= lower && x <= upper { distances.append(x) }
            }
        }
        distances = Array(Set(distances)).sorted()
        let top = distances.map { surface.point(at: $0, height: profile.height(at: $0)) }
        let base = distances.map { surface.point(at: $0) }
        guard distances.contains(where: { profile.height(at: $0) > 0.00001 }) else { return path }
        let roundLeft = surface.cornerRadius > 0 && lower < 0.001
        let roundRight = surface.cornerRadius > 0 && upper > surface.length - 0.001
        func trace(_ points: [CGPoint], roundStart: Bool, roundEnd: Bool) {
            guard points.count > 1 else { return }
            for index in 1..<points.count {
                let previous = points[index - 1], point = points[index]
                let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
                if index == 1 && roundStart {
                    let control = CGPoint(x: previous.x + (point.x - previous.x) / 6, y: previous.y + (point.y - previous.y) / 6)
                    path.addCurve(to: middle, control1: CGPoint(x: previous.x, y: control.y), control2: control)
                } else { path.addQuadCurve(to: middle, control: previous) }
            }
            let last = points[points.count - 1], previous = points[points.count - 2]
            if roundEnd {
                let control = CGPoint(x: last.x - (last.x - previous.x) / 6, y: last.y - (last.y - previous.y) / 6)
                path.addCurve(to: last, control1: control, control2: CGPoint(x: last.x, y: control.y))
            } else { path.addQuadCurve(to: last, control: last) }
        }
        path.move(to: top[0]); trace(top, roundStart: roundLeft, roundEnd: roundRight)
        path.addLine(to: base.last!)
        if surface.cornerRadius > 0 { trace(Array(base.reversed()), roundStart: roundRight, roundEnd: roundLeft) }
        else { path.addLine(to: base[0]) }
        path.closeSubpath()
        return path
    }
}
