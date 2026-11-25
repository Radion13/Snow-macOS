import XCTest
import CoreGraphics
@testable import SnowCore

final class EdgePushTests: XCTestCase {
    private let budget = RenderBudget(framesPerSecond: 30, particleLimit: 200, birthMultiplier: 0)
    private let lowerID: UInt32 = 22
    private func filled() -> SnowProfile {
        var p = SnowProfile(width: 400, maximum: 18, variationSeed: 7, roundedEdges: true)
        for x in stride(from: CGFloat(0), through: 400, by: 4) { p.deposit(at: x, amount: 100) }
        return p
    }
    private func fixture(height: CGFloat = 700, windowY: CGFloat = 180, lower: Bool = false) -> (SnowSimulation, SnowSurface) {
        let simulation = SnowSimulation(size: CGSize(width: 800, height: height), seed: 123)
        let source = SnowSurface(id: 21, frame: CGRect(x: 120, y: windowY, width: 400, height: 200), visible: [.init(0, 400)])
        var surfaces = [source]
        if lower {
            surfaces.append(.init(id: lowerID, frame: CGRect(x: 0, y: 60, width: 800, height: 150), visible: [.init(0, 120), .init(520, 800)]))
        }
        simulation.synchronize(surfaces: surfaces, settings: .init(), liveWindowIDs: Set(surfaces.map(\.id)))
        simulation.adopt(filled(), for: source.id)
        return (simulation, source)
    }
    private func push(_ simulation: SnowSimulation, _ surface: SnowSurface, left: Bool, limit: Int = 100) {
        let x: CGFloat = left ? 8 : 392, movement: CGFloat = left ? -18 : 18
        let p = simulation.profiles[surface.id]!
        let point = surface.point(at: x, height: p.height(at: x))
        simulation.sweep(at: point, from: CGPoint(x: point.x - movement, y: point.y), tool: .mitten, limit: limit)
    }
    private func area(_ simulation: SnowSimulation) -> CGFloat {
        simulation.profiles.values.reduce(0) { $0 + $1.snowArea } + simulation.particles.reduce(0) { $0 + $1.carriedArea }
    }
    func testProfileSpillsRealAreaAtBothEdges() {
        for left in [true, false] {
            var p = filled(); let before = p.snowArea
            let result = p.push(at: left ? 8 : 392, toward: left ? -18 : 18, spillLimit: 1000)
            XCTAssertGreaterThan(result.spilledArea, 0)
            XCTAssertEqual(p.snowArea + result.spilledArea, before, accuracy: 0.000001)
            XCTAssertTrue(p.heights.allSatisfy { $0 >= 0 && $0.isFinite })
            XCTAssertEqual(p.height(at: 0), 0); XCTAssertEqual(p.height(at: 400), 0)
        }
    }
    func testInteriorPushAndUnavailableSpillBudgetPreserveSnow() {
        var p = filled(); let before = p.snowArea
        XCTAssertEqual(p.push(at: 200, toward: 18, spillLimit: 1000).spilledArea, 0)
        XCTAssertEqual(p.snowArea, before, accuracy: 0.000001)
        XCTAssertEqual(p.push(at: 8, toward: -18, spillLimit: 0).spilledArea, 0)
        XCTAssertEqual(p.snowArea, before, accuracy: 0.000001)
    }
    func testBothWindowEdgesCreateVisibleFallingSnowWithoutLoss() {
        for left in [true, false] {
            let (s, source) = fixture(); let before = area(s), sourceArea = s.profiles[source.id]!.snowArea
            push(s, source, left: left)
            let chunks = s.particles.filter { $0.carriedArea > 0 }
            XCTAssertFalse(chunks.isEmpty); XCTAssertLessThan(s.profiles[source.id]!.snowArea, sourceArea)
            XCTAssertTrue(chunks.allSatisfy { left ? $0.x < source.frame.minX : $0.x > source.frame.maxX })
            XCTAssertEqual(area(s), before, accuracy: 0.000001)
            let top = chunks.map(\.y).max()!
            s.step(delta: 1.0 / 60, settings: .init(), budget: budget)
            XCTAssertTrue(s.particles.allSatisfy { $0.y < top && $0.alpha > 0.9 })
        }
    }
    func testSpilledSnowLandsAtBottomAndConservesArea() {
        for left in [true, false] {
            let (s, source) = fixture(); let before = area(s)
            push(s, source, left: left)
            for _ in 0..<360 { s.step(delta: 1.0 / 60, settings: .init(), budget: budget) }
            XCTAssertFalse(s.particles.contains { $0.carriedArea > 0 })
            XCTAssertGreaterThan(s.profiles[SurfaceGeometry.bottomID]!.snowArea, 0)
            XCTAssertEqual(area(s), before, accuracy: 0.000001)
        }
    }
    func testLowerVisibleWindowCatchesSnowBeforeFloor() {
        for left in [true, false] {
            let (s, source) = fixture(lower: true); let before = area(s)
            push(s, source, left: left)
            for _ in 0..<300 { s.step(delta: 1.0 / 60, settings: .init(), budget: budget) }
            XCTAssertGreaterThan(s.profiles[lowerID]!.snowArea, 0)
            XCTAssertEqual(s.profiles[SurfaceGeometry.bottomID]!.snowArea, 0)
            XCTAssertEqual(area(s), before, accuracy: 0.000001)
        }
    }
    func testBrushCanCrossOutsidePhysicalCorner() {
        let (s, source) = fixture(); let before = s.profiles[source.id]!.snowArea
        let contact = source.point(at: 8, height: s.profiles[source.id]!.height(at: 8))
        let outside = CGPoint(x: source.frame.minX - 10, y: contact.y)
        s.sweep(at: outside, from: CGPoint(x: outside.x + 18, y: outside.y), tool: .mitten, limit: 100)
        XCTAssertLessThan(s.profiles[source.id]!.snowArea, before)
        XCTAssertGreaterThan(s.particles.reduce(0) { $0 + $1.carriedArea }, 0)
    }
    func testOcclusionCutIsNotAnOpenWindowEdge() {
        let (s, source) = fixture()
        var clipped = source; clipped.visible = [.init(80, 350)]
        s.synchronize(surfaces: [clipped], settings: .init(), liveWindowIDs: [source.id])
        let before = area(s)
        let point = source.point(at: 340, height: s.profiles[source.id]!.height(at: 340))
        s.sweep(at: point, from: CGPoint(x: point.x - 18, y: point.y), tool: .mitten, limit: 100)
        XCTAssertTrue(s.particles.isEmpty); XCTAssertEqual(area(s), before, accuracy: 0.000001)
        push(s, source, left: true)
        XCTAssertTrue(s.particles.isEmpty); XCTAssertEqual(area(s), before, accuracy: 0.000001)
    }
    func testExhaustedChunkBudgetLeavesSnowAtItsSource() {
        let (s, source) = fixture(); push(s, source, left: false, limit: 1)
        XCTAssertEqual(s.particles.count, 1)
        let before = area(s), profileArea = s.profiles[source.id]!.snowArea
        push(s, source, left: false, limit: 1)
        XCTAssertEqual(s.particles.count, 1)
        XCTAssertEqual(s.profiles[source.id]!.snowArea, profileArea, accuracy: 0.000001)
        XCTAssertEqual(area(s), before, accuracy: 0.000001)
    }
    func testFullSnowfallPoolCanRecycleFlakesWithinSameBudget() {
        let (s, source) = fixture(); var settings = SnowSettings(); settings.weather = .blizzard
        s.step(delta: 1.0 / 60, settings: settings, budget: .init(framesPerSecond: 30, particleLimit: 30, birthMultiplier: 1000))
        XCTAssertEqual(s.particles.count, 30)
        let before = area(s)
        push(s, source, left: false, limit: 30)
        XCTAssertLessThanOrEqual(s.particles.count, 30)
        XCTAssertTrue(s.particles.contains { $0.carriedArea > 0 })
        XCTAssertEqual(area(s), before, accuracy: 0.000001)
    }
    func testQualityDropCombinesChunksWithoutLosingArea() {
        let (s, source) = fixture()
        for i in 0..<50 {
            let left = i % 2 == 0
            s.depositSnow(on: source.id, at: left ? 8 : 392, amount: 100)
            push(s, source, left: left, limit: 100)
        }
        XCTAssertGreaterThan(s.particles.count, 30)
        let before = area(s)
        s.step(delta: 1.0 / 60, settings: .init(), budget: .init(framesPerSecond: 30, particleLimit: 30, birthMultiplier: 0))
        XCTAssertLessThanOrEqual(s.particles.count, 30)
        XCTAssertEqual(area(s), before, accuracy: 0.000001)
    }
    func testHighWindowSnowDoesNotFadeAfterTwoSeconds() {
        let (s, source) = fixture(height: 2400, windowY: 1800); let before = area(s)
        push(s, source, left: false)
        for _ in 0..<126 { s.step(delta: 1.0 / 60, settings: .init(), budget: budget) }
        XCTAssertTrue(s.particles.contains { $0.carriedArea > 0 && $0.alpha > 0.9 && $0.y > 0 })
        XCTAssertEqual(area(s), before, accuracy: 0.000001)
        for _ in 0..<240 { s.step(delta: 1.0 / 60, settings: .init(), budget: budget) }
        XCTAssertFalse(s.particles.contains { $0.carriedArea > 0 })
        XCTAssertEqual(area(s), before, accuracy: 0.000001)
    }
}
