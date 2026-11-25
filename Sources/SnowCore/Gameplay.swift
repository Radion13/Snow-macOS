import Foundation
import CoreGraphics

private enum BallIdentity {
    private static let lock = NSLock()
    private static var counter: UInt64 = 1
    static func reserve(through id: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if id >= counter && id < .max { counter = id + 1 }
    }
    static func make() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let id = counter; counter &+= 1; return id
    }
}

public struct GlassFlight: Equatable {
    public let origin: CGPoint
    public let target: CGPoint
    public var elapsed: CGFloat = 0
    public let duration: CGFloat = 0.26
    public var progress: CGFloat { min(1, max(0, elapsed / duration)) }
}

public struct SnowImpact: Equatable {
    public let id: UInt64
    public let position: CGPoint
    public let radius: CGFloat
    public let variant: Int
    public var age: CGFloat = 0
    public static let lifetime: CGFloat = 5.2
    public var opacity: CGFloat {
        let t = min(1, max(0, (age - 3.6) / (Self.lifetime - 3.6)))
        return 1 - t * t * (3 - 2 * t)
    }
    public var spread: CGFloat {
        if age < 0.12 { let t = age / 0.12; return 0.75 + 0.33 * (1 - pow(1 - t, 3)) }
        return 1 + 0.08 * max(0, 1 - (age - 0.12) / 0.12)
    }
}

public struct Snowball: Equatable {
    public let id: UInt64
    public var radius: CGFloat
    public var position: CGPoint
    public var velocity: CGFloat = 0
    public var horizontalVelocity: CGFloat = 0
    public var surfaceID: UInt32?
    public var localX: CGFloat = 0
    public var anchorHeight: CGFloat = 0
    public var supportID: UInt64?
    public var isLooseSnow = false
    public var glassFlight: GlassFlight?
    public var approachScale: CGFloat { glassFlight.map { 1 + 1.4 * $0.progress * $0.progress } ?? 1 }
    public init(id: UInt64, radius: CGFloat, position: CGPoint) {
        self.id = id; self.radius = min(40, max(6, radius)); self.position = position
    }
}

public final class SnowGame {
    public static let ballLimit = 30
    public static let snowmanLimit = 5
    public static let impactLimit = 12
    public private(set) var balls: [Snowball]
    public private(set) var impacts: [SnowImpact] = []
    public private(set) var draggedID: UInt64?
    public private(set) var message: String?
    private var start: CGPoint?
    private var previous: CGPoint?
    private var sourceID: UInt32?
    private var pickupOffset = CGPoint.zero
    private var rollingOnSnow = false
    private var pointerSamples: [(point: CGPoint, time: TimeInterval)] = []
    private var lastMotion: (velocity: CGVector, time: TimeInterval)?
    public private(set) var lastReleaseVelocity = CGVector.zero
    public init(balls: [Snowball] = []) {
        self.balls = Array(balls.prefix(Self.ballLimit))
        BallIdentity.reserve(through: balls.map(\.id).max() ?? 0)
    }
    public var snowmen: [[UInt64]] {
        var result: [[UInt64]] = []
        for base in balls where base.supportID == nil && base.id != draggedID && !base.isLooseSnow {
            guard let middle = balls.first(where: { $0.supportID == base.id && $0.radius < base.radius }),
                  let head = balls.first(where: { $0.supportID == middle.id && $0.radius < middle.radius }) else { continue }
            result.append([base.id, middle.id, head.id])
        }
        return Array(result.prefix(Self.snowmanLimit))
    }
    public func clear() { balls.removeAll(); impacts.removeAll(); cancelDrag(); message = nil }
    public func cancelDrag() { draggedID = nil; start = nil; sourceID = nil; previous = nil; pointerSamples.removeAll(); pickupOffset = .zero; lastMotion = nil; rollingOnSnow = false }
    public func hit(at point: CGPoint, surfaces: [SnowSurface]) -> UInt64? {
        balls.reversed().first { ball in
            let visible = ball.surfaceID == nil || surfaces.contains { $0.id == ball.surfaceID && $0.visible.contains { $0.contains(ball.localX) } }
            return ball.glassFlight == nil && visible && hypot(ball.position.x - point.x, ball.position.y - point.y) <= ball.radius + 8
        }?.id
    }
    public func begin(at point: CGPoint, surfaces: [SnowSurface], profiles: [UInt32: SnowProfile], time: TimeInterval? = nil) {
        message = nil; cancelDrag(); start = point; previous = point
        sample(point, at: time)
        if let id = hit(at: point, surfaces: surfaces), let index = balls.firstIndex(where: { $0.id == id }) {
            detachDependents(of: id)
            draggedID = id; balls[index].surfaceID = nil; balls[index].supportID = nil
            pickupOffset = CGPoint(x: point.x - balls[index].position.x, y: point.y - balls[index].position.y)
            balls[index].velocity = 0; balls[index].horizontalVelocity = 0
            return
        }
        sourceID = surfaces.first(where: { surface in
            let local = surface.coordinates(of: point)
            let height = profiles[surface.id]?.height(at: local.x) ?? 0
            return surface.orientation == .top && surface.visible.contains { $0.contains(local.x) } &&
                local.y >= -2 && local.y <= height + 14
        })?.id
        if sourceID == nil { message = "game.startOnSnow" }
    }
    /// Production input creates visible snow on mouse-down, without a hidden drag threshold.
    public func scoop(at point: CGPoint, surfaces: [SnowSurface], profiles: inout [UInt32: SnowProfile],
                      looseSnow: Bool = false, time: TimeInterval? = nil) {
        begin(at: point, surfaces: surfaces, profiles: profiles, time: time)
        guard draggedID == nil, let sourceID, let source = surfaces.first(where: { $0.id == sourceID }) else { return }
        guard balls.count < Self.ballLimit, snowmen.count < Self.snowmanLimit else { message = "game.limit"; return }
        let x = source.coordinates(of: point).x, brush: CGFloat = looseSnow ? 20 : 26
        let available = profiles[sourceID]?.availableArea(at: x, radius: brush) ?? 0
        guard available >= .pi * 36 else { message = "game.noSnow"; return }
        let radius = min(looseSnow ? 14 : 12, sqrt(available / .pi))
        let top = source.point(at: x, height: profiles[sourceID]?.height(at: x) ?? 0).y
        let area = profiles[sourceID]?.takeSnow(at: x, radius: brush, maximumArea: .pi * radius * radius) ?? 0
        var ball = Snowball(id: BallIdentity.make(), radius: sqrt(area / .pi), position: CGPoint(x: point.x, y: max(point.y, top + radius)))
        ball.isLooseSnow = looseSnow; balls.append(ball); draggedID = ball.id
        rollingOnSnow = !looseSnow
        pickupOffset = CGPoint(x: point.x - ball.position.x, y: point.y - ball.position.y)
    }
    /// A released handful lands back in the profile instead of fading out or losing area.
    @discardableResult public func settleLooseSnow(surfaces: [SnowSurface], profiles: inout [UInt32: SnowProfile]) -> Bool {
        var changed = false
        for index in balls.indices where balls[index].isLooseSnow && balls[index].id != draggedID {
            guard let id = balls[index].surfaceID, surfaces.contains(where: { $0.id == id }), profiles[id] != nil else { continue }
            let area = CGFloat.pi * balls[index].radius * balls[index].radius
            let accepted = profiles[id]?.placeSnow(at: balls[index].localX, radius: max(24, balls[index].radius * 2), area: area) ?? 0
            if accepted > 0 {
                balls[index].radius = sqrt(max(0, area - accepted) / .pi); changed = true
            }
        }
        balls.removeAll { $0.isLooseSnow && $0.radius < 0.05 && $0.id != draggedID }
        return changed
    }
    public func drag(to point: CGPoint, surfaces: [SnowSurface], profiles: inout [UInt32: SnowProfile], time: TimeInterval? = nil) {
        guard let start else { return }
        sample(point, at: time)
        let distance = hypot(point.x - (previous ?? point).x, point.y - (previous ?? point).y)
        defer { previous = point }
        if draggedID == nil {
            guard hypot(point.x - start.x, point.y - start.y) >= 8, let sourceID,
                  let source = surfaces.first(where: { $0.id == sourceID }) else { return }
            guard balls.count < Self.ballLimit, snowmen.count < Self.snowmanLimit else { message = "game.limit"; return }
            let x = source.coordinates(of: start).x
            let initialArea = CGFloat.pi * 36
            guard (profiles[sourceID]?.availableArea(at: x, radius: 26) ?? 0) >= initialArea else {
                message = "game.noSnow"; return
            }
            profiles[sourceID]?.takeSnow(at: x, radius: 26, maximumArea: initialArea)
            let ball = Snowball(id: BallIdentity.make(), radius: 6, position: point)
            balls.append(ball); draggedID = ball.id
        }
        guard let index = balls.firstIndex(where: { $0.id == draggedID }) else { return }
        balls[index].position = CGPoint(x: point.x - pickupOffset.x, y: point.y - pickupOffset.y)
        rollingOnSnow = false
        if !balls[index].isLooseSnow, distance > 0.5, let surface = surfaces.first(where: { surface in
            let local = surface.coordinates(of: point)
            let height = profiles[surface.id]?.height(at: local.x) ?? 0
            return surface.orientation == .top && surface.visible.contains { $0.contains(local.x) } &&
                local.y >= -2 && local.y <= height + 45
        }) {
            // Remember contact before taking snow: the new hollow underneath
            // the rolled ball must not be mistaken for an airborne throw.
            rollingOnSnow = true
            let radius = balls[index].radius
            let requested = min(CGFloat.pi * (1600 - radius * radius), distance * 18)
            let area = profiles[surface.id]?.takeSnow(at: surface.coordinates(of: point).x,
                                                     radius: max(26, radius), maximumArea: requested) ?? 0
            balls[index].radius = min(40, sqrt(radius * radius + area / .pi))
            // A rolled ball rests ON the snow. A center at pointer.y used to put its
            // lower half below the floor, so the subsequent crossing test never landed it.
            let top = surface.point(at: surface.coordinates(of: point).x,
                                    height: profiles[surface.id]?.height(at: surface.coordinates(of: point).x) ?? 0).y
            balls[index].position.y = max(balls[index].position.y, top + balls[index].radius)
        }
    }
    private func sample(_ point: CGPoint, at time: TimeInterval?) {
        guard let time else { return }
        if let last = pointerSamples.last, time > last.time,
           hypot(point.x - last.point.x, point.y - last.point.y) > 0.5 {
            let dt = CGFloat(min(0.14, max(0.008, time - last.time)))
            lastMotion = (CGVector(dx: (point.x - last.point.x) / dt, dy: (point.y - last.point.y) / dt), time)
        }
        pointerSamples.removeAll { time - $0.time > 0.14 || $0.time > time }
        pointerSamples.append((point, time))
        if pointerSamples.count > 12 { pointerSamples.removeFirst(pointerSamples.count - 12) }
    }
    private func depth(of ball: Snowball) -> Int {
        var current = ball; var count = 0
        while let id = current.supportID, let parent = balls.first(where: { $0.id == id }), count < 3 { count += 1; current = parent }
        return count
    }
    public func endDrag(at point: CGPoint? = nil, time: TimeInterval? = nil,
                        surfaces: [SnowSurface] = [], profiles: [UInt32: SnowProfile] = [:], throwBall: Bool = true) {
        defer { cancelDrag() }
        guard let index = balls.firstIndex(where: { $0.id == draggedID }) else { return }
        if let point { sample(point, at: time) }
        lastReleaseVelocity = .zero
        var ball = balls[index]
        var impulse = CGVector.zero
        if throwBall, let lastMotion, let releasedAt = time ?? pointerSamples.last?.time,
           releasedAt - lastMotion.time <= 0.14 {
            impulse = CGVector(dx: min(1600, max(-1600, lastMotion.velocity.dx)),
                               dy: min(1600, max(-1600, lastMotion.velocity.dy)))
        }
        let nearSnow = surfaces.contains { surface in
            guard surface.orientation == .top else { return false }
            let local = surface.coordinates(of: ball.position)
            let top = profiles[surface.id]?.height(at: local.x) ?? 0
            return surface.visible.contains(where: { $0.contains(local.x) }) && local.y >= 0 &&
                abs(local.y - ball.radius - top) <= max(14, ball.radius * 0.3)
        }
        if !ball.isLooseSnow, let support = balls.filter({ support in
            support.id != ball.id && !support.isLooseSnow && support.surfaceID != nil && depth(of: support) < 2 &&
            !balls.contains { $0.supportID == support.id } &&
            surfaces.contains { $0.id == support.surfaceID && $0.visible.contains { $0.contains(support.localX) } } &&
            abs(ball.position.x - support.position.x) <= max(12, support.radius * 0.5) &&
            abs(ball.position.y - ball.radius - support.position.y - support.radius) <= max(24, ball.radius) &&
            ball.position.y > support.position.y
        }).min(by: { abs($0.position.x - ball.position.x) < abs($1.position.x - ball.position.x) }),
           let surface = surfaces.first(where: { $0.id == support.surfaceID }),
           support.radius > 7, support.supportID == nil || snowmen.count < Self.snowmanLimit {
            // Magnetic placement also fits an equal-sized upper ball to the required
            // descending size. This makes three rolled balls usable without pixel-perfect sizing.
            ball.radius = min(ball.radius, max(6, support.radius * 0.72))
            ball.position = CGPoint(x: support.position.x, y: support.position.y + support.radius + ball.radius)
            ball.surfaceID = surface.id; ball.supportID = support.id; ball.localX = support.localX
            ball.anchorHeight = surface.coordinates(of: ball.position).y
            ball.velocity = 0; ball.horizontalVelocity = 0; balls[index] = ball; return
        }
        if !ball.isLooseSnow, hypot(impulse.dx, impulse.dy) >= 300, !nearSnow, !rollingOnSnow {
            // Magnetic placement keeps priority at the top of another ball.
            // An airborne fling elsewhere travels toward the glass.
            ball.surfaceID = nil; ball.supportID = nil
            ball.horizontalVelocity = impulse.dx; ball.velocity = -impulse.dy
            ball.glassFlight = GlassFlight(origin: ball.position,
                target: CGPoint(x: ball.position.x + impulse.dx * 0.09, y: ball.position.y + impulse.dy * 0.09))
            lastReleaseVelocity = impulse; balls[index] = ball; return
        }
        if hypot(impulse.dx, impulse.dy) >= 140 {
            ball.horizontalVelocity = impulse.dx; ball.velocity = -impulse.dy
            lastReleaseVelocity = impulse
        }
        // Correct a release inside a snow band; never teleport a ball up from below a window.
        for surface in surfaces where surface.orientation == .top {
            let local = surface.coordinates(of: ball.position)
            let height = profiles[surface.id]?.height(at: local.x) ?? 0
            if surface.visible.contains(where: { $0.contains(local.x) }), local.y >= 0,
               local.y - ball.radius <= height + 1, local.y <= height + ball.radius + 1 {
                ball.position.y = surface.point(at: local.x, height: height + ball.radius).y
                if ball.velocity >= 0 {
                    ball.surfaceID = surface.id; ball.supportID = nil; ball.localX = local.x
                    ball.anchorHeight = height + ball.radius; ball.velocity = 0; ball.horizontalVelocity = 0
                    lastReleaseVelocity = .zero
                }
            }
        }
        balls[index] = ball
    }
    public func remove(at point: CGPoint, surfaces: [SnowSurface]) {
        guard let id = hit(at: point, surfaces: surfaces) else {
            if let index = impacts.lastIndex(where: { hypot($0.position.x - point.x, $0.position.y - point.y) <= $0.radius * 1.5 }) { impacts.remove(at: index) }
            return
        }
        var ids: Set<UInt64> = [id]
        for _ in 0..<Self.ballLimit {
            let more = balls.filter { $0.supportID.map(ids.contains) ?? false }.map(\.id)
            let before = ids.count; ids.formUnion(more)
            if before == ids.count { break }
        }
        balls.removeAll { ids.contains($0.id) }
        if draggedID.map(ids.contains) ?? false { cancelDrag() }
    }
    private func detachDependents(of id: UInt64) {
        var ids: Set<UInt64> = [id]
        for _ in 0..<Self.ballLimit {
            let next = balls.filter { $0.supportID.map(ids.contains) ?? false }.map(\.id)
            let before = ids.count; ids.formUnion(next)
            if before == ids.count { break }
        }
        for index in balls.indices where ids.contains(balls[index].id) && balls[index].id != id {
            balls[index].surfaceID = nil; balls[index].supportID = nil; balls[index].velocity = 0
        }
    }
    public func prune(liveIDs: Set<UInt32>) {
        balls.removeAll { ball in
            guard let id = ball.surfaceID else { return false }
            return id != SurfaceGeometry.bottomID && id != SurfaceGeometry.dockID && !liveIDs.contains(id)
        }
    }
    @discardableResult public func transfer(on surfaceID: UInt32, to target: SnowGame, matching predicate: (Snowball) -> Bool) -> Bool {
        let selected = balls.filter { $0.surfaceID == surfaceID && $0.id != draggedID && predicate($0) }
        guard !selected.isEmpty else { return false }
        guard target.balls.count + selected.count <= Self.ballLimit,
              !selected.contains(where: { incoming in target.balls.contains { $0.id == incoming.id } }) else {
            message = "game.limit"; target.message = "game.limit"; return false
        }
        let old = target.balls; target.balls.append(contentsOf: selected)
        let groups = target.balls.filter { base in base.surfaceID != nil && base.supportID == nil &&
            target.balls.contains { middle in middle.supportID == base.id && middle.radius < base.radius &&
                target.balls.contains { $0.supportID == middle.id && $0.radius < middle.radius } }
        }.count
        if groups > Self.snowmanLimit { target.balls = old; message = "game.limit"; target.message = "game.limit"; return false }
        let ids = Set(selected.map(\.id)); balls.removeAll { ids.contains($0.id) }
        return true
    }
    public func step(delta: Double, surfaces: [SnowSurface], profiles: [UInt32: SnowProfile], size: CGSize, reduceMotion: Bool = false) {
        let dt = CGFloat(delta.isFinite ? min(1.0 / 15, max(0, delta)) : 0)
        stepGlass(delta: dt, size: size, reduceMotion: reduceMotion)
        for index in balls.indices {
            if let id = balls[index].surfaceID, let surface = surfaces.first(where: { $0.id == id }) {
                balls[index].localX = min(max(balls[index].radius, balls[index].localX), max(balls[index].radius, surface.length - balls[index].radius))
                balls[index].position = surface.point(at: balls[index].localX, height: balls[index].anchorHeight)
            }
        }
        // A surface anchor follows its window, but it must not suspend the stack
        // when the snow underneath is cleared. Only the base needs gravity.
        for index in balls.indices where balls[index].supportID == nil && balls[index].id != draggedID {
            guard let id = balls[index].surfaceID,
                  let surface = surfaces.first(where: { $0.id == id && $0.orientation == .top }),
                  surface.visible.contains(where: { $0.contains(balls[index].localX) }),
                  let profile = profiles[id],
                  balls[index].anchorHeight - balls[index].radius > profile.height(at: balls[index].localX) + 0.5 else { continue }
            var fallingIDs: Set<UInt64> = [balls[index].id]
            for _ in 0..<2 {
                fallingIDs.formUnion(balls.filter { $0.supportID.map(fallingIDs.contains) ?? false }.map(\.id))
            }
            for child in balls.indices where fallingIDs.contains(balls[child].id) {
                balls[child].surfaceID = nil
                balls[child].velocity = 0; balls[child].horizontalVelocity = 0
            }
        }
        for index in balls.indices where balls[index].surfaceID == nil && balls[index].supportID == nil && balls[index].id != draggedID && balls[index].glassFlight == nil {
            var ball = balls[index]
            let oldCenter = ball.position
            let oldBottom = ball.position.y - ball.radius
            ball.velocity = min(1800, ball.velocity + 360 * dt)
            ball.position.y -= ball.velocity * dt; ball.position.x += ball.horizontalVelocity * dt
            if ball.position.x < ball.radius { ball.position.x = ball.radius; ball.horizontalVelocity = abs(ball.horizontalVelocity) * 0.6 }
            if ball.position.x > size.width - ball.radius { ball.position.x = max(ball.radius, size.width - ball.radius); ball.horizontalVelocity = -abs(ball.horizontalVelocity) * 0.6 }
            if ball.position.y > size.height - ball.radius { ball.position.y = size.height - ball.radius; ball.velocity = abs(ball.velocity) * 0.55 }
            var landing: (SnowSurface, CGFloat, UInt64?)?
            for surface in surfaces where surface.orientation == .top {
                let x = surface.coordinates(of: ball.position).x
                guard surface.visible.contains(where: { $0.contains(x) }) else { continue }
                let top = surface.point(at: x, height: profiles[surface.id]?.height(at: x) ?? 0).y
                let crosses = oldBottom >= top - 1 && ball.position.y - ball.radius <= top
                let insideSnow = oldCenter.y >= surface.point(at: x).y && oldBottom < top && ball.position.y - ball.radius <= top
                if ball.velocity >= 0, crosses || insideSnow,
                   top > (landing?.1 ?? -.greatestFiniteMagnitude) { landing = (surface, top, nil) }
            }
            // A complete falling stack lands on a surface, rather than creating
            // a fourth level by landing its base on another snowball.
            let hasChildren = balls.contains { $0.supportID == ball.id }
            for support in balls where !hasChildren && !ball.isLooseSnow && !support.isLooseSnow && support.id != ball.id && support.surfaceID != nil && support.radius > ball.radius {
                guard let surface = surfaces.first(where: { $0.id == support.surfaceID }),
                      surface.visible.contains(where: { $0.contains(support.localX) }),
                      abs(ball.position.x - support.position.x) <= support.radius * 0.5 else { continue }
                let top = support.position.y + support.radius
                if ball.velocity >= 0, oldBottom >= top - 1 && ball.position.y - ball.radius <= top,
                   top > (landing?.1 ?? -.greatestFiniteMagnitude) {
                    let wouldComplete = support.supportID != nil
                    if wouldComplete && snowmen.count >= Self.snowmanLimit { message = "game.limit"; continue }
                    landing = (surface, top, support.id)
                }
            }
            if let (surface, top, supportID) = landing {
                if let supportID, let support = balls.first(where: { $0.id == supportID }) { ball.position.x = support.position.x }
                ball.surfaceID = surface.id; ball.supportID = supportID
                ball.position.y = top + ball.radius; ball.velocity = 0; ball.horizontalVelocity = 0
                ball.localX = surface.coordinates(of: ball.position).x
                ball.anchorHeight = surface.coordinates(of: ball.position).y
            }
            balls[index] = ball
        }
        // Two passes cover the two links in a snowman even if its array order
        // changed during a display transfer. No extra bodies or particles.
        for _ in 0..<2 {
            for index in balls.indices {
                guard let id = balls[index].supportID, let support = balls.first(where: { $0.id == id }) else { continue }
                balls[index].position = CGPoint(x: support.position.x, y: support.position.y + support.radius + balls[index].radius)
                balls[index].surfaceID = support.surfaceID; balls[index].localX = support.localX
                balls[index].anchorHeight = support.anchorHeight + support.radius + balls[index].radius
                balls[index].velocity = support.velocity; balls[index].horizontalVelocity = support.horizontalVelocity
            }
        }
        let parents = Set(balls.compactMap(\.supportID))
        var escaped = Set(balls.filter {
            $0.supportID == nil && $0.glassFlight == nil && $0.position.y < (parents.contains($0.id) ? -300 : -100)
        }.map(\.id))
        for _ in 0..<2 {
            escaped.formUnion(balls.filter { $0.supportID.map(escaped.contains) ?? false }.map(\.id))
        }
        balls.removeAll { escaped.contains($0.id) }
    }
    private func stepGlass(delta: CGFloat, size: CGSize, reduceMotion: Bool) {
        guard delta > 0 else { return }
        for index in impacts.indices { impacts[index].age += delta }
        impacts.removeAll { $0.age >= SnowImpact.lifetime }
        var struck: Set<UInt64> = []
        for index in balls.indices {
            guard var flight = balls[index].glassFlight else { continue }
            flight.elapsed += delta
            let radius = max(28, min(92, balls[index].radius * 2.35))
            func bound(_ coordinate: CGFloat, extent: CGFloat) -> CGFloat {
                let inset = min(radius * 1.5, max(0, extent / 2))
                return min(max(inset, coordinate), max(inset, extent - inset))
            }
            let destination = reduceMotion ? flight.origin : flight.target
            let target = CGPoint(x: bound(destination.x, extent: size.width), y: bound(destination.y, extent: size.height))
            let t = flight.progress * flight.progress
            balls[index].position = CGPoint(x: flight.origin.x + (target.x - flight.origin.x) * t,
                                            y: flight.origin.y + (target.y - flight.origin.y) * t)
            balls[index].glassFlight = flight
            if reduceMotion || flight.progress >= 1 {
                impacts.append(SnowImpact(id: balls[index].id, position: target, radius: radius, variant: Int(balls[index].id % 9)))
                struck.insert(balls[index].id)
            }
        }
        balls.removeAll { struck.contains($0.id) }
        if impacts.count > Self.impactLimit { impacts.removeFirst(impacts.count - Self.impactLimit) }
    }
}
