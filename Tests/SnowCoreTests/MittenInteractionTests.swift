import XCTest
import CoreGraphics
@testable import SnowCore

final class MittenInteractionTests: XCTestCase {
    private let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: 800, height: 600), visible: [.init(0, 800)], isBottom: true)
    private func filled(rounded: Bool = false) -> SnowProfile {
        var p = SnowProfile(width: 800, maximum: 48, roundedEdges: rounded)
        for x in stride(from: CGFloat(0), through: 800, by: 4) { p.deposit(at: x, amount: 96) }
        return p
    }
    func testMittenPushesInBothDirectionsWithoutLosingSnow() {
        for direction: CGFloat in [-18, 18] {
            var p = filled(); let before = p.snowArea
            let destination = CGFloat(300) + (direction > 0 ? 43.2 : -43.2)
            let oldHeight = p.height(at: destination)
            XCTAssertGreaterThan(p.push(at: 300, toward: direction), 0)
            XCTAssertLessThan(p.height(at: 300), 48)
            XCTAssertGreaterThan(p.height(at: destination), oldHeight)
            XCTAssertEqual(p.snowArea, before, accuracy: 0.000001)
        }
    }
    func testRepeatedPushingAtEdgesStaysBoundedAndPreservesArea() {
        var p = filled(rounded: true); let before = p.snowArea
        for i in 0..<500 {
            let x = CGFloat(i % 100) * 8
            p.push(at: x, toward: i % 2 == 0 ? -24 : 24)
        }
        XCTAssertEqual(p.snowArea, before, accuracy: 0.000001)
        XCTAssertTrue(p.heights.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 48 * 1.8 + 0.001 })
        XCTAssertEqual(p.height(at: 0), 0); XCTAssertEqual(p.height(at: 800), 0)
    }
    func testFreshSnowAndDisplayMergeKeepHandMadeMounds() {
        var p = filled(); p.push(at: 300, toward: 22)
        let peak = p.heights.max()!, area = p.snowArea
        XCTAssertGreaterThan(peak, 48)
        p.deposit(at: 344, amount: 1)
        XCTAssertGreaterThanOrEqual(p.heights.max()!, peak)
        XCTAssertGreaterThanOrEqual(p.snowArea, area)
        var other = filled(); other.merge(from: p, visible: [.init(0, 800)])
        XCTAssertEqual(other.heights, p.heights)
        other.resize(to: 800, maximum: 48)
        XCTAssertEqual(other.heights, p.heights)
    }
    func testSnowballExistsOnPressBeforeAnyDraggingAndUsesRealSnow() {
        let game = SnowGame(); var profiles = [floor.id: filled()]
        let before = profiles[floor.id]!.snowArea
        game.scoop(at: CGPoint(x: 200, y: 8), surfaces: [floor], profiles: &profiles, time: 1)
        XCTAssertEqual(game.balls.count, 1); XCTAssertNotNil(game.draggedID)
        let ball = game.balls[0]
        XCTAssertGreaterThanOrEqual(ball.radius, 6); XCTAssertFalse(ball.isLooseSnow)
        XCTAssertGreaterThanOrEqual(ball.position.y - ball.radius, 48)
        XCTAssertEqual(profiles[floor.id]!.snowArea + .pi * ball.radius * ball.radius, before, accuracy: 0.000001)
        game.drag(to: CGPoint(x: 360, y: 220), surfaces: [floor], profiles: &profiles, time: 1.2)
        game.endDrag(at: CGPoint(x: 360, y: 220), time: 1.21, surfaces: [floor], profiles: profiles)
        XCTAssertGreaterThan(game.lastReleaseVelocity.dx, 0)
        XCTAssertGreaterThan(game.lastReleaseVelocity.dy, 0)
        XCTAssertNil(game.balls[0].surfaceID)
    }
    func testHandfulCanBeLiftedAndSettlesBackIntoSnowWithoutLoss() {
        let game = SnowGame(); var profiles = [floor.id: filled()]
        let before = profiles[floor.id]!.snowArea
        game.scoop(at: CGPoint(x: 200, y: 8), surfaces: [floor], profiles: &profiles, looseSnow: true, time: 1)
        XCTAssertEqual(game.balls.count, 1); XCTAssertTrue(game.balls[0].isLooseSnow)
        let radius = game.balls[0].radius
        game.drag(to: CGPoint(x: 400, y: 220), surfaces: [floor], profiles: &profiles, time: 1.2)
        XCTAssertEqual(game.balls[0].radius, radius)
        XCTAssertGreaterThan(game.balls[0].position.y, 220)
        game.endDrag(at: CGPoint(x: 400, y: 220), time: 2, surfaces: [floor], profiles: profiles)
        for _ in 0..<300 {
            game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size)
            game.settleLooseSnow(surfaces: [floor], profiles: &profiles)
        }
        XCTAssertTrue(game.balls.isEmpty)
        XCTAssertEqual(profiles[floor.id]!.snowArea, before, accuracy: 0.000001)
        XCTAssertGreaterThan(profiles[floor.id]!.height(at: 400), 48)
    }
    func testEmptySnowCannotProduceFreeBallsOrHandfuls() {
        let game = SnowGame(); var profiles = [floor.id: SnowProfile(width: 800, maximum: 48)]
        for loose in [false, true] {
            game.scoop(at: CGPoint(x: 200, y: 5), surfaces: [floor], profiles: &profiles, looseSnow: loose, time: 1)
            XCTAssertTrue(game.balls.isEmpty); XCTAssertNil(game.draggedID)
            XCTAssertEqual(game.message, "game.noSnow")
        }
    }
    func testProductionMittenMovesAreaWithoutFadingParticles() {
        let simulation = SnowSimulation(size: floor.frame.size); var settings = SnowSettings()
        settings.accumulateAtBottom = true
        simulation.synchronize(surfaces: [], settings: settings, liveWindowIDs: [])
        simulation.adopt(filled(), for: floor.id)
        let before = simulation.profiles[floor.id]!.snowArea
        simulation.sweep(at: CGPoint(x: 300, y: 48), from: CGPoint(x: 282, y: 48), tool: .mitten, limit: 100)
        XCTAssertEqual(simulation.profiles[floor.id]!.snowArea, before, accuracy: 0.000001)
        XCTAssertTrue(simulation.particles.isEmpty)
        XCTAssertLessThan(simulation.profiles[floor.id]!.height(at: 300), 48)
    }
}
