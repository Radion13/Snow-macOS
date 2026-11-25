import XCTest
import CoreGraphics
@testable import SnowCore

final class InteractionFixTests: XCTestCase {
    private let floor = SnowSurface(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: 800, height: 600), visible: [.init(0, 800)], isBottom: true)
    private func snow() -> [UInt32: SnowProfile] {
        var profile = SnowProfile(width: 800, maximum: 48)
        for x in stride(from: CGFloat(0), through: 800, by: 8) { profile.deposit(at: x, amount: 96) }
        return [floor.id: profile]
    }
    func testRolledBallStartsAboveSnowAndSurvivesReleaseAtBottomEdge() {
        let game = SnowGame(); var profiles = snow()
        game.begin(at: CGPoint(x: 100, y: 5), surfaces: [floor], profiles: profiles)
        game.drag(to: CGPoint(x: 250, y: 5), surfaces: [floor], profiles: &profiles)
        guard let rolled = game.balls.first else { return XCTFail("A gesture inside the full snow band must create a ball") }
        XCTAssertGreaterThan(rolled.radius, 6)
        XCTAssertGreaterThanOrEqual(rolled.position.y - rolled.radius, profiles[floor.id]!.height(at: 250))
        game.endDrag(surfaces: [floor], profiles: profiles)
        for _ in 0..<600 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size) }
        XCTAssertEqual(game.balls.count, 1)
        XCTAssertEqual(game.balls[0].surfaceID, floor.id)
    }
    func testThreeEqualBallsCanBePlacedIntoSnowmanThroughDragAndRelease() {
        var base = Snowball(id: 9001, radius: 33, position: CGPoint(x: 200, y: 33))
        base.surfaceID = floor.id; base.localX = 200; base.anchorHeight = 33
        let game = SnowGame(balls: [base, .init(id: 9002, radius: 33, position: CGPoint(x: 400, y: 80)), .init(id: 9003, radius: 33, position: CGPoint(x: 600, y: 80))])
        var profiles = [floor.id: SnowProfile(width: 800, maximum: 48)]
        game.begin(at: CGPoint(x: 400, y: 80), surfaces: [floor], profiles: profiles)
        game.drag(to: CGPoint(x: 205, y: 99), surfaces: [floor], profiles: &profiles)
        game.endDrag(surfaces: [floor], profiles: profiles)
        let top = game.balls[1].position.y + game.balls[1].radius
        game.begin(at: CGPoint(x: 600, y: 80), surfaces: [floor], profiles: profiles)
        game.drag(to: CGPoint(x: 204, y: top + 33), surfaces: [floor], profiles: &profiles)
        game.endDrag(surfaces: [floor], profiles: profiles)
        XCTAssertEqual(game.snowmen, [[9001, 9002, 9003]])
        XCTAssertLessThan(game.balls[1].radius, game.balls[0].radius)
        XCTAssertLessThan(game.balls[2].radius, game.balls[1].radius)
        XCTAssertEqual(game.balls[2].position.x, 200)
    }
    func testSparseMouseGestureReleasesWithHorizontalAndUpwardMomentum() {
        let game = SnowGame(balls: [.init(id: 9101, radius: 20, position: CGPoint(x: 100, y: 200))])
        var profiles = snow()
        game.begin(at: CGPoint(x: 100, y: 200), surfaces: [floor], profiles: profiles, time: 1)
        game.drag(to: CGPoint(x: 220, y: 320), surfaces: [floor], profiles: &profiles, time: 1.2)
        game.endDrag(at: CGPoint(x: 220, y: 320), time: 1.21, surfaces: [floor], profiles: profiles)
        XCTAssertGreaterThan(game.balls[0].horizontalVelocity, 0)
        XCTAssertLessThan(game.balls[0].velocity, 0)
        game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size)
        XCTAssertGreaterThan(game.balls[0].position.x, 220)
        XCTAssertGreaterThan(game.balls[0].position.y, 320)
    }
    func testHoldingBeforeReleaseRemovesThrowMomentum() {
        let game = SnowGame(balls: [.init(id: 9201, radius: 20, position: CGPoint(x: 100, y: 200))])
        var profiles = snow()
        game.begin(at: CGPoint(x: 100, y: 200), surfaces: [floor], profiles: profiles, time: 1)
        game.drag(to: CGPoint(x: 220, y: 320), surfaces: [floor], profiles: &profiles, time: 1.2)
        game.endDrag(at: CGPoint(x: 220, y: 320), time: 2, surfaces: [floor], profiles: profiles)
        XCTAssertEqual(game.balls[0].horizontalVelocity, 0)
        XCTAssertEqual(game.balls[0].velocity, 0)
    }
    func testPickupKeepsGrabOffsetAndExitDoesNotThrow() {
        let game = SnowGame(balls: [.init(id: 9301, radius: 20, position: CGPoint(x: 100, y: 200))])
        var profiles = snow()
        game.begin(at: CGPoint(x: 106, y: 207), surfaces: [floor], profiles: profiles, time: 1)
        game.drag(to: CGPoint(x: 226, y: 327), surfaces: [floor], profiles: &profiles, time: 1.1)
        XCTAssertEqual(game.balls[0].position, CGPoint(x: 220, y: 320))
        game.endDrag(throwBall: false)
        XCTAssertEqual(game.balls[0].horizontalVelocity, 0); XCTAssertNil(game.draggedID)
    }
    func testGarlandsAnchorAtBothMenuBarCornersForEveryStyle() {
        let size = CGSize(width: 1728, height: 1084)
        for style in GarlandStyle.allCases {
            let wires = GarlandLayout.wires(style: style, size: size)
            XCTAssertFalse(wires.isEmpty)
            for wire in wires {
                XCTAssertEqual(wire.first, CGPoint(x: 0, y: 1082))
                XCTAssertEqual(wire.last, CGPoint(x: 1728, y: 1082))
            }
            let lights = GarlandLayout.lights(style: style, size: size)
            XCTAssertFalse(lights.isEmpty); XCTAssertLessThanOrEqual(lights.count, 512)
            XCTAssertTrue(lights.allSatisfy { $0.position.x >= 0 && $0.position.x <= size.width && $0.position.y > size.height - 120 })
        }
        XCTAssertEqual(GarlandLayout.wires(style: .classic, size: size).count, 3)
        XCTAssertEqual(GarlandLayout.wires(style: .stars, size: size).count, 1)
        XCTAssertEqual(GarlandLayout.wires(style: .glow, size: size).count, 2)
    }
    func testGarlandLimitsAndSettingsMigration() throws {
        XCTAssertTrue(GarlandLayout.lights(style: .stars, size: .zero).isEmpty)
        for style in GarlandStyle.allCases {
            XCTAssertLessThanOrEqual(GarlandLayout.lights(style: style, size: CGSize(width: 20_000, height: 2000)).count, 512)
        }
        let migrated = SnowSettings.load(Data(#"{"wind":40,"garland":"wave","garlandPalette":"warm"}"#.utf8))
        XCTAssertEqual(migrated.wind, 40); XCTAssertEqual(migrated.garland, .wave); XCTAssertEqual(migrated.garlandStyle, .classic)
        var settings = migrated; settings.garlandStyle = .stars; settings.garlandPalette = .icy
        XCTAssertEqual(SnowSettings.load(try JSONEncoder().encode(settings)), settings)
    }
    private func stack(at x: CGFloat, firstID: UInt64) -> [Snowball] {
        var result: [Snowball] = []; var top: CGFloat = 48
        for (index, radius) in [CGFloat(33), 24, 17].enumerated() {
            let id = firstID + UInt64(index)
            var ball = Snowball(id: id, radius: radius, position: CGPoint(x: x, y: top + radius))
            ball.surfaceID = floor.id; ball.localX = x; ball.anchorHeight = ball.position.y
            ball.supportID = index == 0 ? nil : id - 1
            result.append(ball); top += radius * 2
        }
        return result
    }
    func testCleanerDropsOnlyStackOverClearedSnowAndKeepsItTogether() {
        let game = SnowGame(balls: stack(at: 200, firstID: 9500) + stack(at: 650, firstID: 9600))
        var profiles = snow(); let cleaner = SnowCleaner(); var settings = SnowSettings()
        settings.automaticCleaner = false
        let untouched = Array(game.balls.suffix(3))
        XCTAssertTrue(cleaner.start(character: .tractor))
        for _ in 0..<120 {
            var bottom = profiles[floor.id]
            cleaner.step(delta: 1.0 / 60, width: 800, settings: settings, profile: &bottom)
            profiles[floor.id] = bottom
            game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size)
        }
        XCTAssertEqual(game.balls.count, 6)
        XCTAssertEqual(game.snowmen, [[9500, 9501, 9502], [9600, 9601, 9602]])
        XCTAssertLessThan(game.balls[0].position.y, 81)
        XCTAssertEqual(Array(game.balls.suffix(3)), untouched)
        for _ in 0..<180 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: profiles, size: floor.frame.size) }
        XCTAssertEqual(game.balls[0].position.y, 33, accuracy: 0.01)
        XCTAssertEqual(game.balls[0].surfaceID, floor.id)
        XCTAssertEqual(game.balls[1].position.y, 90, accuracy: 0.01)
        XCTAssertEqual(game.balls[2].position.y, 131, accuracy: 0.01)
    }
    func testFallingStackPreservesLinksEvenWithReversedBallOrder() {
        let game = SnowGame(balls: stack(at: 200, firstID: 9700).reversed())
        let empty = [floor.id: SnowProfile(width: 800, maximum: 48)]
        game.step(delta: 1.0 / 60, surfaces: [floor], profiles: empty, size: floor.frame.size)
        XCTAssertTrue(game.balls.allSatisfy { $0.surfaceID == nil })
        XCTAssertEqual(game.snowmen, [[9700, 9701, 9702]])
        let base = game.balls.first { $0.id == 9700 }!
        XCTAssertGreaterThan(base.velocity, 0)
        for _ in 0..<180 { game.step(delta: 1.0 / 60, surfaces: [floor], profiles: empty, size: floor.frame.size) }
        XCTAssertEqual(game.balls.count, 3); XCTAssertEqual(game.snowmen, [[9700, 9701, 9702]])
        XCTAssertTrue(game.balls.allSatisfy { $0.surfaceID == floor.id && $0.velocity == 0 })
    }
    func testFallingStackWithoutFloorLeavesNoOrphanedHead() {
        let falling = stack(at: 200, firstID: 9800).map { ball -> Snowball in
            var ball = ball; ball.surfaceID = nil; return ball
        }
        let game = SnowGame(balls: falling)
        for _ in 0..<600 { game.step(delta: 1.0 / 60, surfaces: [], profiles: [:], size: floor.frame.size) }
        XCTAssertTrue(game.balls.isEmpty); XCTAssertTrue(game.snowmen.isEmpty)
    }
    func testBlinkIntensityAndBrightnessHaveIndependentBoundedEffects() {
        var settings = SnowSettings(); settings.garland = .twinkle; settings.garlandBrightness = 0.6
        settings.garlandBlinkIntensity = 0
        for time in stride(from: 0.0, through: 10, by: 0.1) {
            XCTAssertEqual(GarlandLighting.alpha(time: time, index: 3, settings: settings, reduceMotion: false), 0.6)
        }
        settings.garlandBlinkIntensity = 1
        let samples = stride(from: 0.0, through: 10, by: 0.05).map { GarlandLighting.alpha(time: $0, index: 3, settings: settings, reduceMotion: false) }
        XCTAssertLessThan(samples.min()!, 0.01); XCTAssertGreaterThan(samples.max()!, 0.59)
        XCTAssertTrue(samples.allSatisfy { (0...0.6).contains($0) })
        XCTAssertEqual(GarlandLighting.alpha(time: 3, index: 3, settings: settings, reduceMotion: true), 0.6)
        settings.garland = .steady
        XCTAssertEqual(GarlandLighting.alpha(time: 3, index: 3, settings: settings, reduceMotion: false), 0.6)
        settings.garland = .wave; settings.garlandBrightness = 0
        XCTAssertEqual(GarlandLighting.alpha(time: 3, index: 3, settings: settings, reduceMotion: false), 0)
        settings.garland = .off; settings.garlandBrightness = 1
        XCTAssertEqual(GarlandLighting.alpha(time: 3, index: 3, settings: settings, reduceMotion: false), 0)
    }
    func testBlinkPreferencesMigratePersistAndSanitize() throws {
        let previous = SnowSettings.load(Data(#"{"garland":"wave","garlandBrightness":0.42}"#.utf8))
        XCTAssertEqual(previous.garlandBrightness, 0.42); XCTAssertEqual(previous.garlandBlinkIntensity, 0.7)
        var changed = previous; changed.garlandBlinkIntensity = 0.23
        XCTAssertEqual(SnowSettings.load(try JSONEncoder().encode(changed)), changed)
        changed.garlandBrightness = -5; changed.garlandBlinkIntensity = 5; changed.sanitize()
        XCTAssertEqual(changed.garlandBrightness, 0); XCTAssertEqual(changed.garlandBlinkIntensity, 1)
        changed.garlandBlinkIntensity = .nan; changed.sanitize()
        XCTAssertEqual(changed.garlandBlinkIntensity, 0.7)
    }
}
