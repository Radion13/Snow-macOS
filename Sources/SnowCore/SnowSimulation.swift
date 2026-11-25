import Foundation
import CoreGraphics

public struct SnowParticle: Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var speed: CGFloat
    public var drift: CGFloat
    public var radius: CGFloat
    public var alpha: CGFloat
    public var life: Double
    public var scattered: Bool
    /// Actual snow displaced from a ledge, in logical square points. Ordinary
    /// snowfall and cosmetic scatter carry no area until they land.
    public var carriedArea: CGFloat = 0
    public var ignoredSurfaceID: UInt32? = nil
    /// Stable visual identity; styling never consumes the physics random stream.
    public var flakeSeed: UInt32 = 0
}

private struct SnowRandom {
    var state: UInt64
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}

public final class SnowSimulation {
    public private(set) var particles: [SnowParticle] = []
    public private(set) var profiles: [UInt32: SnowProfile] = [:]
    public private(set) var surfaces: [SnowSurface] = []
    public private(set) var surfaceRevision: UInt64 = 0
    public var size: CGSize
    public let game = SnowGame()
    public let cleaner = SnowCleaner()
    private var random: SnowRandom
    private var flakeSequence: UInt32
    private var birthRemainder: Double = 0
    private var currentWind: CGFloat = 0
    private var activeParticleLimit: Int?
    private static let chunkArea: CGFloat = 96
    public init(size: CGSize, seed: UInt64 = 42) {
        self.size = size; random = .init(state: seed); flakeSequence = UInt32(truncatingIfNeeded: seed)
    }

    public func synchronize(surfaces newSurfaces: [SnowSurface], settings: SnowSettings, liveWindowIDs: Set<UInt32>?) {
        var next = Array(newSurfaces.prefix(97))
        next = next.filter { surface in
            switch surface.kind {
            case .window: return settings.accumulateOnWindows
            case .dock: return settings.accumulateOnDock
            case .widget: return settings.accumulateOnWidgets
            case .bottom: return settings.accumulateAtBottom
            }
        }
        if settings.accumulateAtBottom {
            next.append(.init(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: size),
                              visible: [.init(0, size.width)], isBottom: true))
        }
        surfaces = next
        if let liveWindowIDs {
            profiles = profiles.filter { $0.key == SurfaceGeometry.bottomID || $0.key == SurfaceGeometry.dockID || liveWindowIDs.contains($0.key) }
            game.prune(liveIDs: liveWindowIDs)
        }
        // Hard cap also applies to windows preserved while minimized or on a different Space.
        let active = Set(next.map(\.id))
        if profiles.count > 128 {
            for id in profiles.keys.sorted() where !active.contains(id) {
                profiles.removeValue(forKey: id)
                if profiles.count <= 128 { break }
            }
        }
        for surface in next {
            let maximum = CGFloat(surface.isBottom ? settings.bottomHeight : settings.windowHeight)
            if profiles[surface.id] == nil {
                profiles[surface.id] = .init(width: surface.length, maximum: maximum,
                                             variationSeed: UInt64(surface.id), roundedEdges: surface.orientation == .top && surface.kind != .bottom)
            }
            else if profiles[surface.id]?.width != surface.length || profiles[surface.id]?.maximum != maximum {
                profiles[surface.id]?.resize(to: surface.length, maximum: maximum)
            }
        }
        // 97 active surfaces + up to 31 retained profiles; never grow with session duration.
        if profiles.count > 128 {
            for id in profiles.keys.sorted() where !active.contains(id) {
                profiles.removeValue(forKey: id)
                if profiles.count <= 128 { break }
            }
        }
        surfaceRevision &+= 1
    }

    public func clear() {
        for id in profiles.keys { profiles[id]?.clear() }
        particles.removeAll(where: \.scattered)
        game.clear(); cleaner.clear()
        surfaceRevision &+= 1
    }
    @discardableResult public func adopt(_ profile: SnowProfile, for id: UInt32) -> Bool {
        guard profiles[id] != profile else { return false }
        if profiles[id] == nil, profiles.count >= 128 { return false }
        profiles[id] = profile; surfaceRevision &+= 1; return true
    }

    public func step(delta: Double, settings: SnowSettings, budget: RenderBudget, reduceMotion: Bool = false) {
        let dt = min(1.0 / 15.0, max(0, delta))
        guard dt > 0, size.width > 0, size.height > 0 else { return }
        let particleLimit = budget.particleLimit(for: settings.weather)
        activeParticleLimit = particleLimit
        compactParticles(to: particleLimit)
        currentWind += (CGFloat(settings.wind) * 1.6 - currentWind) * min(1, dt * 2)
        birthRemainder = min(200, birthRemainder + settings.weather.birthRate * budget.birthMultiplier * dt)
        let births = min(Int(birthRemainder), max(0, particleLimit - particles.count))
        birthRemainder -= Double(Int(birthRemainder))
        for _ in 0..<births {
            flakeSequence &+= 0x9E3779B9
            particles.append(.init(x: random.unit() * size.width, y: size.height + 6,
                                   speed: settings.weather.speed * (0.65 + random.unit() * 0.7),
                                   drift: random.unit() * 20 - 10, radius: 1 + random.unit() * 2.5,
                                   alpha: 0.4 + random.unit() * 0.5, life: 120, scattered: false,
                                   flakeSeed: flakeSequence))
        }
        var survivors: [SnowParticle] = []
        survivors.reserveCapacity(particles.count)
        for var particle in particles {
            let previousPoint = CGPoint(x: particle.x, y: particle.y)
            particle.life -= dt
            particle.x += (currentWind + particle.drift) * dt
            particle.y -= particle.speed * dt
            if particle.carriedArea > 0 {
                particle.speed = min(1800, particle.speed + 380 * dt)
                if particle.x < -10 || particle.x > size.width + 10 { continue }
            } else {
                if particle.scattered { particle.speed += 110 * dt; particle.alpha *= pow(0.18, dt) }
                if particle.x < -8 { particle.x = size.width + 6 }
                if particle.x > size.width + 8 { particle.x = -6 }
            }
            var hit: SnowSurface?
            var highest: CGFloat = -.greatestFiniteMagnitude
            if !particle.scattered || particle.carriedArea > 0 {
                for surface in surfaces {
                    guard surface.id != particle.ignoredSurfaceID else { continue }
                    let local = surface.coordinates(of: CGPoint(x: particle.x, y: particle.y))
                    let oldLocal = surface.coordinates(of: previousPoint)
                    let x = local.x
                    guard surface.visible.contains(where: { $0.contains(x) }), let profile = profiles[surface.id] else { continue }
                    let height = profile.height(at: x)
                    let top = surface.point(at: x, height: height).y
                    if oldLocal.y >= height && local.y <= height && top > highest { hit = surface; highest = top }
                }
            }
            if let hit, particle.carriedArea > 0 {
                let x = hit.coordinates(of: CGPoint(x: particle.x, y: particle.y)).x
                let accepted = profiles[hit.id]?.placeSnow(at: x, radius: max(12, particle.radius * 3), area: particle.carriedArea) ?? 0
                particle.carriedArea = max(0, particle.carriedArea - accepted)
                if accepted > 0 { surfaceRevision &+= 1 }
                if particle.carriedArea > 0.000001 {
                    // A full lower ledge spills the remainder further down.
                    // Overflow at a full screen floor leaves through the bottom.
                    if !hit.isBottom {
                        let left = particle.drift < 0
                        particle.x = hit.frame.minX + (left ? -particle.radius - 2 : hit.length + particle.radius + 2)
                    }
                    particle.ignoredSurfaceID = hit.id
                    survivors.append(particle)
                }
            } else if let hit {
                let x = hit.coordinates(of: CGPoint(x: particle.x, y: particle.y)).x
                let overflow = profiles[hit.id]?.deposit(at: x, amount: particle.radius * 0.42) ?? 0
                if let profile = profiles[hit.id], profile.roundedEdges, overflow > 0.01,
                   x < max(profile.edgeInset, hit.cornerRadius) || x > profile.width - max(profile.edgeInset, hit.cornerRadius) {
                    // Reuse this flake within the same particle budget. Starting
                    // outside/below the edge prevents it from hitting the same cap.
                    let left = x < profile.width / 2
                    particle.x = hit.frame.minX + (left ? -2 : hit.length + 2)
                    particle.y = hit.point(at: x, height: profile.height(at: x)).y - 1
                    particle.speed = max(35, particle.speed)
                    particle.drift = (left ? -1 : 1) * (15 + random.unit() * 20)
                    particle.scattered = true; particle.life = 2; particle.alpha = 0.85
                    survivors.append(particle)
                }
                surfaceRevision &+= 1
            } else if particle.y > -10 && particle.life > 0 && particle.alpha > 0.03 {
                survivors.append(particle)
            }
        }
        particles = survivors
        var bottom = profiles[SurfaceGeometry.bottomID]
        let wasCleaning = cleaner.x != nil
        cleaner.step(delta: dt, width: size.width, settings: settings, profile: &bottom)
        profiles[SurfaceGeometry.bottomID] = bottom
        if wasCleaning || cleaner.x != nil { surfaceRevision &+= 1 }
        game.step(delta: dt, surfaces: surfaces, profiles: profiles, size: size, reduceMotion: reduceMotion)
        if game.settleLooseSnow(surfaces: surfaces, profiles: &profiles) { surfaceRevision &+= 1 }
    }

    public func beginRoll(at point: CGPoint, time: TimeInterval? = nil) {
        game.scoop(at: point, surfaces: surfaces, profiles: &profiles, time: time); surfaceRevision &+= 1
    }
    public func beginHandful(at point: CGPoint, time: TimeInterval? = nil) {
        game.scoop(at: point, surfaces: surfaces, profiles: &profiles, looseSnow: true, time: time); surfaceRevision &+= 1
    }
    public func roll(to point: CGPoint, time: TimeInterval? = nil) {
        game.drag(to: point, surfaces: surfaces, profiles: &profiles, time: time); surfaceRevision &+= 1
    }
    public func endRoll(at point: CGPoint, time: TimeInterval) {
        game.endDrag(at: point, time: time, surfaces: surfaces, profiles: profiles)
    }
    public func depositSnow(on id: UInt32, at x: CGFloat, amount: CGFloat) {
        profiles[id]?.deposit(at: x, amount: amount); surfaceRevision &+= 1
    }

    public func sweep(at point: CGPoint, from previous: CGPoint? = nil, tool: SnowTool, limit: Int) {
        guard tool == .mitten || tool == .shovel, point.x.isFinite, point.y.isFinite else { return }
        let boundedLimit = max(0, min(limit, activeParticleLimit ?? limit))
        if tool == .mitten, boundedLimit > 0 { compactParticles(to: boundedLimit) }
        for surface in surfaces {
            let local = surface.coordinates(of: point)
            let x = local.x
            guard let profile = profiles[surface.id] else { continue }
            let ledge = surface.orientation == .top && !surface.isBottom
            let outside = x < 0 || x > surface.length
            let rim = x < 0 ? CGFloat(0) : surface.length
            let sample = outside ? (x < 0 ? min(8, surface.length / 2) : surface.length - min(8, surface.length / 2)) : x
            let contact = surface.point(at: sample, height: profile.height(at: sample))
            let visible = outside ? (tool == .mitten && ledge && x >= -24 && x <= surface.length + 24 && surface.visible.contains { $0.contains(rim) }) : surface.visible.contains { $0.contains(x) }
            guard visible, abs(local.y - profile.height(at: x)) < 32 || (outside && abs(point.y - contact.y) < 32) else { continue }
            if tool == .shovel { profiles[surface.id]?.clear() }
            else if let previous {
                let movement = x - surface.coordinates(of: previous).x
                let edge = movement < 0 ? CGFloat(0) : surface.length
                let openEdge = ledge && surface.visible.contains { $0.contains(edge) }
                let capacity = boundedLimit > 0 ? min(8, max(0, boundedLimit - particles.count) + particles.filter { $0.carriedArea == 0 }.count) : 0
                let result = profiles[surface.id]?.push(at: x, toward: movement, spillLimit: openEdge ? CGFloat(capacity) * Self.chunkArea : 0) ?? .init()
                if result.spilledArea > 0 {
                    emitSpilledSnow(area: result.spilledArea, from: surface, contact: contact,
                                    left: movement < 0, limit: boundedLimit)
                }
            }
            surfaceRevision &+= 1
        }
    }

    private func emitSpilledSnow(area: CGFloat, from surface: SnowSurface, contact: CGPoint, left: Bool, limit: Int) {
        let count = min(8, max(1, Int(ceil(area / Self.chunkArea))))
        for _ in 0..<count {
            if particles.count >= limit, let index = particles.firstIndex(where: { $0.carriedArea == 0 }) { particles.remove(at: index) }
            let portion = area / CGFloat(count), radius = min(6, max(2, sqrt(portion / .pi)))
            particles.append(.init(x: left ? surface.frame.minX - max(3, radius / 2) : surface.frame.maxX + max(3, radius / 2),
                                   y: contact.y - 2 - random.unit() * 3,
                                   speed: 35 + random.unit() * 25, drift: (left ? -1 : 1) * (30 + random.unit() * 30),
                                   radius: radius, alpha: 0.97, life: 12, scattered: true,
                                   carriedArea: portion, ignoredSurfaceID: surface.id))
        }
    }

    /// Quality changes remove visual flakes first. If necessary, combine snow
    /// fragments instead of discarding their area when the particle cap shrinks.
    private func compactParticles(to limit: Int) {
        guard limit > 0, particles.count > limit else { return }
        let snow = particles.filter { $0.carriedArea > 0 }
        if snow.count <= limit {
            particles = snow + particles.filter { $0.carriedArea == 0 }.prefix(limit - snow.count)
            return
        }
        var merged = Array(snow.prefix(limit))
        for part in snow.dropFirst(limit) {
            func distance(_ index: Int) -> CGFloat {
                let dx = merged[index].x - part.x, dy = merged[index].y - part.y
                return dx * dx + dy * dy
            }
            let slot = merged.indices.min { distance($0) < distance($1) }!
            let old = merged[slot], area = old.carriedArea + part.carriedArea
            let weight = part.carriedArea / area
            merged[slot].x += (part.x - old.x) * weight
            merged[slot].y += (part.y - old.y) * weight
            merged[slot].speed += (part.speed - old.speed) * weight
            merged[slot].drift += (part.drift - old.drift) * weight
            merged[slot].carriedArea = area
            merged[slot].radius = min(8, max(2, sqrt(area / .pi)))
            merged[slot].life = max(old.life, part.life)
            if old.ignoredSurfaceID != part.ignoredSurfaceID { merged[slot].ignoredSurfaceID = nil }
        }
        particles = merged
    }
}
