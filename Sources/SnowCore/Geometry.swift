import Foundation
import CoreGraphics

public struct SnowInterval: Equatable {
    public var lower: CGFloat
    public var upper: CGFloat
    public init(_ lower: CGFloat, _ upper: CGFloat) { self.lower = lower; self.upper = upper }
    public var width: CGFloat { max(0, upper - lower) }
    public func contains(_ x: CGFloat) -> Bool { x >= lower && x <= upper }
    public func subtracting(_ cut: Self) -> [Self] {
        guard cut.upper > lower, cut.lower < upper else { return [self] }
        var result: [Self] = []
        if cut.lower > lower { result.append(.init(lower, min(upper, cut.lower))) }
        if cut.upper < upper { result.append(.init(max(lower, cut.upper), upper)) }
        return result.filter { $0.width > 0.5 }
    }
}

public enum SnowCoordinates {
    /// CG uses a top-left origin on the primary display, AppKit a bottom-left origin.
    /// Both APIs expose logical points; backingScaleFactor must NOT multiply these rectangles.
    public static func appKitRect(fromCG rect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }
    public static func localRect(_ global: CGRect, display: CGRect) -> CGRect {
        global.offsetBy(dx: -display.minX, dy: -display.minY)
    }
}

public struct WindowSnapshot: Equatable {
    public let id: UInt32
    public let frame: CGRect
    public let eligible: Bool
    public init(id: UInt32, frame: CGRect, eligible: Bool = true) {
        self.id = id; self.frame = frame; self.eligible = eligible
    }
}

public enum SurfaceKind { case window, bottom, dock, widget }
public enum SurfaceOrientation { case top, leftEdge, rightEdge }
public struct SnowSurface: Equatable {
    public let id: UInt32
    public var frame: CGRect
    public var visible: [SnowInterval]
    public let isBottom: Bool
    public var kind: SurfaceKind
    public var orientation: SurfaceOrientation
    public init(id: UInt32, frame: CGRect, visible: [SnowInterval], isBottom: Bool = false,
                kind: SurfaceKind = .window, orientation: SurfaceOrientation = .top) {
        self.id = id; self.frame = frame; self.visible = visible; self.isBottom = isBottom
        self.kind = isBottom ? .bottom : kind; self.orientation = orientation
    }
    public var baseline: CGFloat { isBottom ? frame.minY : frame.maxY }
    public var length: CGFloat { orientation == .top ? frame.width : frame.height }
    /// A conservative inset stays inside rounded native window corners. Public
    /// window bounds do not expose each application's exact corner mask.
    public var cornerRadius: CGFloat {
        guard orientation == .top, kind == .window || kind == .widget, !isBottom else { return 0 }
        return max(0, min(24, frame.width / 4, frame.height / 4))
    }
    public func baseOffset(at distance: CGFloat) -> CGFloat {
        let radius = cornerRadius
        guard radius > 0 else { return 0 }
        let edgeDistance = max(0, min(distance, length - distance))
        guard edgeDistance < radius else { return 0 }
        let dx = radius - edgeDistance
        return sqrt(max(0, radius * radius - dx * dx)) - radius
    }
    public func point(at distance: CGFloat, height: CGFloat = 0) -> CGPoint {
        switch orientation {
        case .top: return .init(x: frame.minX + distance, y: baseline + baseOffset(at: distance) + height)
        case .leftEdge: return .init(x: frame.minX - height, y: frame.minY + distance)
        case .rightEdge: return .init(x: frame.maxX + height, y: frame.minY + distance)
        }
    }
    public func coordinates(of point: CGPoint) -> CGPoint {
        switch orientation {
        case .top:
            let distance = point.x - frame.minX
            return .init(x: distance, y: point.y - baseline - baseOffset(at: distance))
        case .leftEdge: return .init(x: point.y - frame.minY, y: frame.minX - point.x)
        case .rightEdge: return .init(x: point.y - frame.minY, y: point.x - frame.maxX)
        }
    }
}

public enum SurfaceGeometry {
    public static let bottomID: UInt32 = .max
    public static let dockID: UInt32 = .max - 1

    public static func dock(frame: CGRect, display: CGRect, vertical: Bool) -> SnowSurface? {
        let clipped = frame.intersection(display)
        guard !clipped.isNull, clipped.width > 15, clipped.height > 15 else { return nil }
        let local = SnowCoordinates.localRect(frame, display: display)
        if frame.width > frame.height * 2.5, abs(frame.minY - display.minY) < 8, frame.height < 180 {
            return .init(id: dockID, frame: local, visible: [.init(0, frame.width)], kind: .dock)
        }
        guard vertical, frame.height > frame.width * 2.5, frame.width < 180 else { return nil }
        if abs(frame.minX - display.minX) < 8 {
            return .init(id: dockID, frame: local, visible: [.init(0, frame.height)], kind: .dock, orientation: .rightEdge)
        }
        if abs(frame.maxX - display.maxX) < 8 {
            return .init(id: dockID, frame: local, visible: [.init(0, frame.height)], kind: .dock, orientation: .leftEdge)
        }
        return nil
    }

    public static func subtract(_ cut: CGRect, from rect: CGRect) -> [CGRect] {
        let overlap = rect.intersection(cut)
        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return [rect] }
        return [CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: overlap.minY - rect.minY),
                CGRect(x: rect.minX, y: overlap.maxY, width: rect.width, height: rect.maxY - overlap.maxY),
                CGRect(x: rect.minX, y: overlap.minY, width: overlap.minX - rect.minX, height: overlap.height),
                CGRect(x: overlap.maxX, y: overlap.minY, width: rect.maxX - overlap.maxX, height: overlap.height)]
            .filter { $0.width > 0.5 && $0.height > 0.5 }
    }

    public static func visibleParts(of rect: CGRect, on id: UInt32, windows: [WindowSnapshot]) -> [CGRect] {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return [rect] }
        return windows.prefix(index).reduce([rect]) { parts, front in
            Array(parts.flatMap { subtract(front.frame, from: $0) }.prefix(64))
        }
    }

    /// Rectangles arrive front-to-back. Clip the entire snow band, not just its baseline.
    public static func surfaces(windows: [WindowSnapshot], display: CGRect, snowHeight: CGFloat) -> [SnowSurface] {
        var occluders: [CGRect] = []
        var result: [SnowSurface] = []
        for window in windows {
            let rect = window.frame
            if window.eligible, rect.width >= 100, rect.height >= 60,
               rect.maxY >= display.minY, rect.maxY < display.maxY,
               rect.maxX > display.minX, rect.minX < display.maxX {
                var spans = [SnowInterval(max(rect.minX, display.minX), min(rect.maxX, display.maxX))]
                let cornerDepth = min(24, rect.width / 4, rect.height / 4)
                for front in occluders where front.minY < rect.maxY + snowHeight && front.maxY > rect.maxY - cornerDepth - 1 {
                    if front.maxY > rect.maxY - 1 {
                        spans = spans.flatMap { $0.subtracting(.init(front.minX, front.maxX)) }
                    } else {
                        // Only the wrapped corners extend below the top edge.
                        // A lower front window must not remove the central cap.
                        for corner in [SnowInterval(rect.minX, rect.minX + cornerDepth), SnowInterval(rect.maxX - cornerDepth, rect.maxX)] {
                            let cut = SnowInterval(max(front.minX, corner.lower), min(front.maxX, corner.upper))
                            if cut.width > 0 { spans = spans.flatMap { $0.subtracting(cut) } }
                        }
                    }
                }
                if !spans.isEmpty {
                    result.append(.init(id: window.id,
                                        frame: SnowCoordinates.localRect(rect, display: display),
                                        visible: spans.map { .init($0.lower - rect.minX, $0.upper - rect.minX) }))
                }
            }
            if rect.intersects(display) { occluders.append(rect) }
        }
        return Array(result.prefix(96))
    }

    public static func isFullscreen(_ window: CGRect, on screen: CGRect) -> Bool {
        abs(window.minX - screen.minX) <= 2 && abs(window.minY - screen.minY) <= 2 &&
        abs(window.width - screen.width) <= 4 && abs(window.height - screen.height) <= 4
    }
}

public struct GarlandLight {
    public var position: CGPoint
    public var attachment: CGPoint
    public var rotation: CGFloat
    public var size: CGSize
    public var colorIndex: Int
}

/// Geometry is in each display's local points. Endpoints always touch the two
/// corners immediately below the menu bar; no foreign window bounds are involved.
public enum GarlandLayout {
    public static func wirePoint(x: CGFloat, strand: Int, style: GarlandStyle, size: CGSize) -> CGPoint {
        let t = min(1, max(0, x / max(1, size.width)))
        if t <= 0.000001 || t >= 0.999999 { return CGPoint(x: min(size.width, max(0, x)), y: size.height - 2) }
        let envelope = sin(.pi * t)
        let sag: CGFloat
        switch style {
        case .classic: sag = envelope * (25 + CGFloat(strand) * 8 + 14 * sin(t * .pi * 5 + CGFloat(strand) * 2.1))
        case .stars:
            let spans = max(2, Int(ceil(size.width / 280)))
            let local = (t * CGFloat(spans)).truncatingRemainder(dividingBy: 1)
            sag = 13 + 34 * 4 * local * (1 - local)
        case .glow: sag = envelope * (40 + 14 * sin(t * .pi * 2 + CGFloat(strand) * .pi))
        }
        return CGPoint(x: min(size.width, max(0, x)), y: size.height - 2 - sag)
    }
    public static func wires(style: GarlandStyle, size: CGSize) -> [[CGPoint]] {
        guard size.width > 0, size.height > 0 else { return [] }
        let strands = style == .classic ? 3 : (style == .glow ? 2 : 1)
        let count = min(1024, max(2, Int(ceil(size.width / 8))))
        return (0..<strands).map { strand in (0...count).map { index in
            wirePoint(x: size.width * CGFloat(index) / CGFloat(count), strand: strand, style: style, size: size)
        } }
    }
    public static func lights(style: GarlandStyle, size: CGSize) -> [GarlandLight] {
        guard size.width > 0, size.height > 0 else { return [] }
        var lights: [GarlandLight] = []
        if style == .stars {
            let spans = min(40, max(2, Int(ceil(size.width / 280))))
            let step = size.width / CGFloat(spans)
            for index in 0...spans {
                let point = CGPoint(x: CGFloat(index) * step, y: size.height - 25)
                lights.append(.init(position: point, attachment: CGPoint(x: point.x, y: size.height - 2), rotation: 0,
                                    size: CGSize(width: 46, height: 46), colorIndex: index % 3))
            }
            for span in 0..<spans {
                for index in 1...5 {
                    let x = (CGFloat(span) + CGFloat(index) / 6) * step
                    let attachment = wirePoint(x: x, strand: 0, style: style, size: size)
                    lights.append(.init(position: CGPoint(x: x, y: attachment.y - 14), attachment: attachment,
                                        rotation: 0, size: CGSize(width: 22, height: 22), colorIndex: index == 3 ? 4 : 3))
                }
            }
        } else {
            let strands = style == .classic ? 3 : 2
            let count = min(170, max(3, Int(ceil(size.width / (style == .classic ? 68 : 80)))))
            for strand in 0..<strands {
                for index in 0..<count {
                    let x = size.width * (CGFloat(index) + (CGFloat(strand) + 0.5) / CGFloat(strands)) / CGFloat(count)
                    let attachment = wirePoint(x: x, strand: strand, style: style, size: size)
                    let upward = (index + strand) % 3 == 0
                    let rotation: CGFloat = upward ? .pi + 0.25 * sin(CGFloat(index)) : 0.45 * sin(CGFloat(index * 2 + strand))
                    let offset: CGFloat = style == .classic ? 10 : 8
                    let position = CGPoint(x: attachment.x + sin(rotation) * offset, y: attachment.y - cos(rotation) * offset)
                    lights.append(.init(position: position, attachment: attachment, rotation: rotation,
                                        size: style == .classic ? CGSize(width: 9, height: 23) : CGSize(width: 8, height: 15),
                                        colorIndex: (index + strand * 2) % 4))
                }
            }
        }
        return Array(lights.prefix(512))
    }
}
