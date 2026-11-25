import XCTest
import CoreGraphics
@testable import SnowCore

final class GlassImpactTests: XCTestCase {
    private let size = CGSize(width: 800, height: 600)
    private var floor: SnowSurface { .init(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: size), visible: [.init(0, 800)], isBottom: true) }
    private func launch(loose: Bool = false) -> SnowGame {
        var ball = Snowball(id: 100_001, radius: 20, position: CGPoint(x: 100, y: 200)); ball.isLooseSnow = loose
        let game = SnowGame(balls: [ball]); var profiles: [UInt32: SnowProfile] = [:]
        game.begin(at: ball.position, surfaces: [], profiles: profiles, time: 1)
        game.drag(to: CGPoint(x: 260, y: 330), surfaces: [], profiles: &profiles, time: 1.1)
        game.endDrag(at: CGPoint(x: 260, y: 330), time: 1.11)
        return game
    }
    private func advance(_ game: SnowGame, frames: Int, reduceMotion: Bool = false) {
        for _ in 0..<frames { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: size, reduceMotion: reduceMotion) }
    }
    func testRaisedFastThrowApproachesGlassThenBecomesOneImpact() {
        let game = launch()
        XCTAssertNotNil(game.balls[0].glassFlight); XCTAssertTrue(game.impacts.isEmpty)
        let origin = game.balls[0].position
        advance(game, frames: 6)
        XCTAssertGreaterThan(game.balls[0].approachScale, 1)
        XCTAssertGreaterThan(game.balls[0].position.x, origin.x); XCTAssertGreaterThan(game.balls[0].position.y, origin.y)
        advance(game, frames: 12)
        XCTAssertTrue(game.balls.isEmpty); XCTAssertEqual(game.impacts.count, 1)
        XCTAssertGreaterThan(game.impacts[0].radius, 20)
        advance(game, frames: 30); XCTAssertEqual(game.impacts.count, 1)
    }
    func testSlowReleaseAndHoldingDoNotStrikeGlass() {
        for release: TimeInterval in [1.21, 2] {
            let game = SnowGame(balls: [.init(id: 100_002, radius: 20, position: CGPoint(x: 100, y: 200))])
            var profiles: [UInt32: SnowProfile] = [:]
            game.begin(at: CGPoint(x: 100, y: 200), surfaces: [], profiles: profiles, time: 1)
            game.drag(to: CGPoint(x: 120, y: 220), surfaces: [], profiles: &profiles, time: 1.2)
            game.endDrag(at: CGPoint(x: 120, y: 220), time: release)
            XCTAssertNil(game.balls[0].glassFlight)
            advance(game, frames: 30); XCTAssertTrue(game.impacts.isEmpty)
        }
        let game = launch(); game.clear(); XCTAssertTrue(game.impacts.isEmpty)
    }
    func testFastRollingOnSnowDoesNotBecomeGlassThrow() {
        let game = SnowGame(); var p = SnowProfile(width: 800, maximum: 48)
        for x in stride(from: CGFloat(0), through: 800, by: 4) { p.deposit(at: x, amount: 96) }
        var profiles = [floor.id: p]
        game.scoop(at: CGPoint(x: 100, y: 8), surfaces: [floor], profiles: &profiles, time: 1)
        game.drag(to: CGPoint(x: 400, y: 8), surfaces: [floor], profiles: &profiles, time: 1.05)
        game.endDrag(at: CGPoint(x: 400, y: 8), time: 1.06, surfaces: [floor], profiles: profiles)
        XCTAssertNil(game.balls[0].glassFlight); XCTAssertTrue(game.impacts.isEmpty)
        for _ in 0..<60 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: size) }
        XCTAssertEqual(game.balls.count, 1); XCTAssertTrue(game.impacts.isEmpty)
    }
    func testMittenHandfulUsesFallingSnowInsteadOfGlassImpact() {
        let game = launch(loose: true)
        XCTAssertNil(game.balls[0].glassFlight)
        advance(game, frames: 30); XCTAssertTrue(game.impacts.isEmpty)
    }
    func testGentlePlacementCanStillBuildSnowman() {
        for release: TimeInterval in [1.11, 2] {
        var base = Snowball(id: 100_003, radius: 30, position: CGPoint(x: 200, y: 30))
        base.surfaceID = floor.id; base.localX = 200; base.anchorHeight = 30
        let game = SnowGame(balls: [base, .init(id: 100_004, radius: 25, position: CGPoint(x: 400, y: 200))])
        var profiles = [floor.id: SnowProfile(width: 800, maximum: 48)]
        game.begin(at: CGPoint(x: 400, y: 200), surfaces: [floor], profiles: profiles, time: 1)
        game.drag(to: CGPoint(x: 202, y: 85), surfaces: [floor], profiles: &profiles, time: 1.1)
        game.endDrag(at: CGPoint(x: 202, y: 85), time: release, surfaces: [floor], profiles: profiles)
        XCTAssertEqual(game.balls[1].supportID, base.id)
        XCTAssertNil(game.balls[1].glassFlight); XCTAssertTrue(game.impacts.isEmpty)
        }
    }
    func testImpactFadesAndIsRemovedAndZeroDeltaFreezesIt() {
        let game = launch(); advance(game, frames: 18)
        let young = game.impacts[0]
        game.step(delta: 0, surfaces: [], profiles: [:], size: size)
        game.step(delta: .infinity, surfaces: [], profiles: [:], size: size)
        XCTAssertEqual(game.impacts[0], young)
        advance(game, frames: 240)
        XCTAssertGreaterThan(game.impacts[0].opacity, 0); XCTAssertLessThan(game.impacts[0].opacity, 1)
        advance(game, frames: 90); XCTAssertTrue(game.impacts.isEmpty)
    }
    func testReduceMotionSkipsZoomAndCreatesStaticMarkImmediately() {
        let game = launch(); let point = game.balls[0].position
        advance(game, frames: 1, reduceMotion: true)
        XCTAssertTrue(game.balls.isEmpty); XCTAssertEqual(game.impacts.count, 1)
        XCTAssertEqual(game.impacts[0].position, point)
    }
    func testRepeatedThrowsBoundMarksAndKeepVariantsDiverse() {
        let wide = CGSize(width: 3000, height: 600)
        let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(origin: .zero, size: wide), visible: [.init(0, wide.width)], isBottom: true)
        let balls = (0..<16).map { index -> Snowball in
            var b = Snowball(id: UInt64(110_000 + index), radius: 10, position: CGPoint(x: 100 + index * 100, y: 10))
            b.surfaceID = floor.id; b.localX = b.position.x; b.anchorHeight = 10; return b
        }
        let game = SnowGame(balls: balls); var profiles = [floor.id: SnowProfile(width: wide.width, maximum: 48)]
        for i in 0..<16 {
            let x = CGFloat(100 + i * 100), time = Double(i) + 1
            game.begin(at: CGPoint(x: x, y: 10), surfaces: [floor], profiles: profiles, time: time)
            game.drag(to: CGPoint(x: x + 30, y: 250), surfaces: [floor], profiles: &profiles, time: time + 0.1)
            game.endDrag(at: CGPoint(x: x + 30, y: 250), time: time + 0.11, surfaces: [floor], profiles: profiles)
            for _ in 0..<18 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: wide) }
            XCTAssertLessThanOrEqual(game.impacts.count, SnowGame.impactLimit)
        }
        XCTAssertEqual(game.impacts.count, SnowGame.impactLimit)
        XCTAssertEqual(Set(game.impacts.map(\.variant)).count, 9)
    }
    func testClearAndRightClickRemoveMarks() {
        let game = launch(); advance(game, frames: 18)
        game.remove(at: game.impacts[0].position, surfaces: [])
        XCTAssertTrue(game.impacts.isEmpty)
        let other = launch(); other.clear(); advance(other, frames: 30)
        XCTAssertTrue(other.balls.isEmpty); XCTAssertTrue(other.impacts.isEmpty)
    }
    func testImpactNearEdgeRemainsWithinSmallDisplay() {
        let game = launch()
        for _ in 0..<18 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: CGSize(width: 180, height: 140)) }
        let p = game.impacts[0].position
        XCTAssertTrue(p.x.isFinite && p.y.isFinite)
        XCTAssertGreaterThanOrEqual(p.x, 0); XCTAssertLessThanOrEqual(p.x, 180)
        XCTAssertGreaterThanOrEqual(p.y, 0); XCTAssertLessThanOrEqual(p.y, 140)
    }
}
