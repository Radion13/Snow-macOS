import XCTest
import CoreGraphics
@testable import SnowCore

final class SnowDriftTests: XCTestCase {
    private func fill(_ profile: inout SnowProfile) {
        for x in stride(from: CGFloat(0), through: profile.width, by: 4) { profile.deposit(at: x, amount: 100) }
    }
    func testMoundsStayUnevenAtCapacityAndDoNotTaperScreenBottom() {
        var first = SnowProfile(width: 800, maximum: 48, variationSeed: 42)
        var same = first; fill(&first); fill(&same)
        XCTAssertEqual(first, same)
        XCTAssertGreaterThan(first.heights.max()! - first.heights.min()!, 3)
        XCTAssertGreaterThan(first.height(at: 0), 0)
        XCTAssertTrue(first.heights.allSatisfy { (0...48).contains($0) })
        XCTAssertGreaterThanOrEqual(first.filledFraction, 0.6)
        var window = SnowProfile(width: 800, maximum: 18, variationSeed: 42, roundedEdges: true); fill(&window)
        XCTAssertEqual(window.height(at: 0), 0); XCTAssertEqual(window.height(at: 800), 0)
        XCTAssertGreaterThan(window.height(at: 24), window.height(at: 4))
    }
    func testRoundedCapOverflowsAndKeepsItsShapeAfterResize() {
        var profile = SnowProfile(width: 400, maximum: 18, roundedEdges: true); fill(&profile)
        XCTAssertGreaterThan(profile.deposit(at: 0, amount: 5), 0)
        XCTAssertEqual(profile.height(at: 0), 0)
        XCTAssertEqual(profile.height(at: 200), 18)
        profile.resize(to: 600, maximum: 18)
        XCTAssertEqual(profile.height(at: 0), 0); XCTAssertEqual(profile.height(at: 600), 0)
        XCTAssertEqual(profile.height(at: 200), 18)
        XCTAssertEqual(profile.height(at: 550), 0)
    }
    func testContourUsesCurvesAndStaysInsideVisibleSpan() {
        let surface = SnowSurface(id: 10, frame: CGRect(x: 40, y: 80, width: 400, height: 200), visible: [.init(0, 400)])
        var profile = SnowProfile(width: 400, maximum: 18, variationSeed: 42, roundedEdges: true); fill(&profile)
        let path = SnowContour.path(surface: surface, profile: profile, span: .init(70, 290))
        var curves = 0
        path.applyWithBlock { if $0.pointee.type == .addQuadCurveToPoint { curves += 1 } }
        XCTAssertGreaterThan(curves, 10)
        XCTAssertEqual(path.boundingBox.minX, 110, accuracy: 0.01)
        XCTAssertEqual(path.boundingBox.maxX, 330, accuracy: 0.01)
        XCTAssertLessThanOrEqual(path.boundingBox.maxY, surface.baseline + 18)
    }
    func testExcessAtWindowCornersFallsWithinExistingParticleBudget() {
        let surface = SnowSurface(id: 10, frame: CGRect(x: 60, y: 100, width: 520, height: 200), visible: [.init(0, 520)])
        var settings = SnowSettings(); settings.weather = .blizzard; settings.accumulateAtBottom = false
        let sim = SnowSimulation(size: CGSize(width: 640, height: 480), seed: 123)
        sim.synchronize(surfaces: [surface], settings: settings, liveWindowIDs: [10])
        for x in stride(from: CGFloat(0), through: 520, by: 4) { sim.depositSnow(on: 10, at: x, amount: 100) }
        let budget = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: false)
        var fell = false
        for _ in 0..<1200 {
            sim.step(delta: 1.0 / 60, settings: settings, budget: budget)
            fell = fell || sim.particles.contains { $0.scattered && $0.y < surface.baseline - 10 && ($0.x < surface.frame.minX || $0.x > surface.frame.maxX) }
            XCTAssertLessThanOrEqual(sim.particles.count, budget.particleLimit(for: settings.weather))
        }
        XCTAssertTrue(fell)
        XCTAssertEqual(sim.profiles[10]?.height(at: 0), 0)
        XCTAssertEqual(sim.profiles[10]?.height(at: 520), 0)
    }
}
