import XCTest
import CoreGraphics
@testable import SnowCore

final class FeatureTests: XCTestCase {
    private func filled(width: CGFloat = 500, maximum: CGFloat = 30) -> SnowProfile {
        var profile = SnowProfile(width: width, maximum: maximum)
        for x in stride(from: CGFloat(0), through: width, by: 4) { profile.deposit(at: x, amount: 100) }
        return profile
    }
    private func bottom(width: CGFloat = 500) -> SnowSurface {
        .init(id: SurfaceGeometry.bottomID, frame: CGRect(x: 0, y: 0, width: width, height: 600), visible: [.init(0, width)], isBottom: true)
    }
    func testRollThresholdAndConservationOfSnowArea() {
        let game = SnowGame(); let surface = bottom()
        var profiles = [surface.id: filled()]
        let initial = profiles[surface.id]!.availableArea(at: 250, radius: 500)
        game.begin(at: CGPoint(x: 100, y: 30), surfaces: [surface], profiles: profiles)
        game.drag(to: CGPoint(x: 107, y: 30), surfaces: [surface], profiles: &profiles)
        XCTAssertTrue(game.balls.isEmpty)
        game.drag(to: CGPoint(x: 130, y: 30), surfaces: [surface], profiles: &profiles)
        XCTAssertEqual(game.balls.count, 1)
        let removed = initial - profiles[surface.id]!.availableArea(at: 250, radius: 500)
        XCTAssertEqual(removed, .pi * pow(game.balls[0].radius, 2), accuracy: 0.001)
        game.endDrag(); XCTAssertNil(game.draggedID)
    }
    func testEmptySnowCreatesNoBallAndDoesNotSpendSnow() {
        let game = SnowGame(); let surface = bottom()
        var profiles = [surface.id: SnowProfile(width: 500, maximum: 30)]
        game.begin(at: CGPoint(x: 100, y: 0), surfaces: [surface], profiles: profiles)
        game.drag(to: CGPoint(x: 120, y: 0), surfaces: [surface], profiles: &profiles)
        XCTAssertTrue(game.balls.isEmpty); XCTAssertEqual(game.message, "game.noSnow")
        XCTAssertEqual(profiles[surface.id]!.heights.reduce(0, +), 0)
    }
    func testGrowthStopsAtFortyAndCannotContinueWithoutSnow() {
        let game = SnowGame(); let surface = bottom(width: 2000)
        var profiles = [surface.id: filled(width: 2000, maximum: 48)]
        game.begin(at: CGPoint(x: 50, y: 48), surfaces: [surface], profiles: profiles)
        for x in stride(from: 70, through: 1500, by: 10) { game.drag(to: CGPoint(x: x, y: 40), surfaces: [surface], profiles: &profiles) }
        XCTAssertEqual(game.balls.first?.radius, 40)
        profiles[surface.id]?.clear(); let radius = game.balls[0].radius
        game.drag(to: CGPoint(x: 1700, y: 40), surfaces: [surface], profiles: &profiles)
        XCTAssertEqual(game.balls[0].radius, radius)
    }
    func testThreeDescendingBallsAssembleAndFollowMovingWindow() {
        let surface = SnowSurface(id: 7, frame: CGRect(x: 0, y: 100, width: 500, height: 200), visible: [.init(0, 500)])
        var base = Snowball(id: 1, radius: 25, position: CGPoint(x: 100, y: 325))
        base.surfaceID = 7; base.localX = 100; base.anchorHeight = 25
        let game = SnowGame(balls: [base, .init(id: 2, radius: 17, position: CGPoint(x: 104, y: 440)), .init(id: 3, radius: 9, position: CGPoint(x: 102, y: 560))])
        let profiles = [UInt32(7): SnowProfile(width: 500, maximum: 18)]
        for _ in 0..<600 { game.step(delta: 1.0 / 60, surfaces: [surface], profiles: profiles, size: CGSize(width: 800, height: 800)) }
        XCTAssertEqual(game.snowmen, [[1, 2, 3]])
        let before = game.balls.map(\.position)
        var moved = surface; moved.frame = moved.frame.offsetBy(dx: 70, dy: 40)
        game.step(delta: 0, surfaces: [moved], profiles: profiles, size: CGSize(width: 800, height: 800))
        for (index, ball) in game.balls.enumerated() {
            XCTAssertEqual(ball.position.x, before[index].x + 70, accuracy: 0.01)
            XCTAssertEqual(ball.position.y, before[index].y + 40, accuracy: 0.01)
        }
        game.prune(liveIDs: [7]); XCTAssertEqual(game.balls.count, 3)
        game.prune(liveIDs: []); XCTAssertTrue(game.balls.isEmpty)
    }
    func testBallLimitDoesNotConsumeAdditionalSnow() {
        let balls = (1...30).map { Snowball(id: UInt64($0), radius: 6, position: CGPoint(x: $0 * 15, y: 300)) }
        let game = SnowGame(balls: balls); let surface = bottom(width: 1000)
        var profiles = [surface.id: filled(width: 1000)]
        let before = profiles
        game.begin(at: CGPoint(x: 800, y: 30), surfaces: [surface], profiles: profiles)
        game.drag(to: CGPoint(x: 820, y: 30), surfaces: [surface], profiles: &profiles)
        XCTAssertEqual(game.balls.count, 30); XCTAssertEqual(game.message, "game.limit"); XCTAssertEqual(profiles, before)
    }
    func testSnowmanLimitPreventsMoreCreation() {
        let surface = bottom(width: 3000)
        var balls: [Snowball] = []
        for index in 0..<5 {
            var support: UInt64?
            for (level, radius): (Int, CGFloat) in [CGFloat(25), 17, 9].enumerated() {
                let id = UInt64(index * 3 + level + 1)
                var ball = Snowball(id: id, radius: radius, position: CGPoint(x: 100 + index * 100, y: 25 + level * 42))
                ball.surfaceID = surface.id; ball.localX = ball.position.x; ball.supportID = support
                balls.append(ball); support = id
            }
        }
        let game = SnowGame(balls: balls); var profiles = [surface.id: filled(width: 3000)]
        XCTAssertEqual(game.snowmen.count, 5)
        game.begin(at: CGPoint(x: 2000, y: 30), surfaces: [surface], profiles: profiles)
        game.drag(to: CGPoint(x: 2020, y: 30), surfaces: [surface], profiles: &profiles)
        XCTAssertEqual(game.balls.count, 15); XCTAssertEqual(game.message, "game.limit")
    }
    func testCleanerOnlyClearsItsTravelledBottomRegion() {
        let cleaner = SnowCleaner(); var profile: SnowProfile? = filled(width: 800)
        XCTAssertTrue(cleaner.start(character: .retro)); XCTAssertFalse(cleaner.start(character: .tractor))
        for _ in 0..<45 { cleaner.step(delta: 1.0 / 60, width: 800, settings: .init(), profile: &profile) }
        XCTAssertEqual(profile!.height(at: 20), 0)
        XCTAssertEqual(profile!.height(at: 700), 30)
    }
    func testAutomaticCleanerThresholdAndCooldown() {
        let cleaner = SnowCleaner(); var profile: SnowProfile? = filled(width: 800)
        var settings = SnowSettings(); settings.automaticCleaner = true
        cleaner.step(delta: 1.0 / 30, width: 800, settings: settings, profile: &profile)
        XCTAssertNotNil(cleaner.x)
        cleaner.clear(); XCTAssertFalse(cleaner.start(character: .tractor, automatic: true))
        settings.automaticCleaner = false
        for _ in 0..<1801 { cleaner.step(delta: 1.0 / 30, width: 800, settings: settings, profile: &profile) }
        XCTAssertTrue(cleaner.start(character: .tractor, automatic: true))
        let empty = SnowCleaner(); profile?.clear(); settings.automaticCleaner = true
        empty.step(delta: 1.0 / 30, width: 800, settings: settings, profile: &profile); XCTAssertNil(empty.x)
    }
    func testDockGeometryRejectsHiddenAndSupportsBothVerticalSides() {
        let display = CGRect(x: -1200, y: 900, width: 1200, height: 900)
        XCTAssertNil(SurfaceGeometry.dock(frame: CGRect(x: -1000, y: 800, width: 700, height: 80), display: display, vertical: true))
        let horizontal = SurfaceGeometry.dock(frame: CGRect(x: -1000, y: 900, width: 700, height: 80), display: display, vertical: false)
        XCTAssertEqual(horizontal?.orientation, .top)
        let left = SurfaceGeometry.dock(frame: CGRect(x: -1200, y: 1050, width: 80, height: 600), display: display, vertical: true)!
        XCTAssertEqual(left.orientation, .rightEdge)
        let point = left.point(at: 123, height: 15)
        XCTAssertEqual(left.coordinates(of: point), CGPoint(x: 123, y: 15))
        let right = SurfaceGeometry.dock(frame: CGRect(x: -80, y: 1050, width: 80, height: 600), display: display, vertical: true)
        XCTAssertEqual(right?.orientation, .leftEdge)
        XCTAssertNil(SurfaceGeometry.dock(frame: CGRect(x: -80, y: 1050, width: 80, height: 600), display: display, vertical: false))
    }
    func testWholeSnowmanBoundsAreClippedByFrontWindow() {
        let rear = WindowSnapshot(id: 2, frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        let front = WindowSnapshot(id: 1, frame: CGRect(x: 50, y: 260, width: 100, height: 100))
        let bounds = CGRect(x: 0, y: 200, width: 200, height: 180)
        let parts = SurfaceGeometry.visibleParts(of: bounds, on: 2, windows: [front, rear])
        XCTAssertEqual(parts.reduce(0) { $0 + $1.width * $1.height }, 26_000)
        XCTAssertTrue(parts.allSatisfy { $0.intersection(front.frame).isEmpty })
    }
    func testP0SettingsMigrateAndP1SettingsRoundTrip() throws {
        let migrated = SnowSettings.load(Data(#"{"weather":"blizzard","wind":33,"quality":"smooth"}"#.utf8))
        XCTAssertEqual(migrated.weather, .blizzard); XCTAssertEqual(migrated.wind, 33)
        XCTAssertFalse(migrated.accumulateOnDock); XCTAssertEqual(migrated.garland, .off)
        var settings = migrated; settings.garland = .wave; settings.cleaner = .retro; settings.scenes[1] = .cabin
        XCTAssertEqual(SnowSettings.load(try JSONEncoder().encode(settings)), settings)
    }
    func testSharedProfilesPreserveClearingAndLocalCoordinatesAcrossDisplays() {
        var shared = filled(width: 400)
        var left = shared; left.clearRange(from: 0, to: 180)
        shared.merge(from: left, visible: [.init(0, 200)])
        XCTAssertEqual(shared.height(at: 80), 0); XCTAssertEqual(shared.height(at: 300), 30)
        let sim = SnowSimulation(size: CGSize(width: 1000, height: 900))
        XCTAssertTrue(sim.adopt(shared, for: 7))
        let surface = SnowSurface(id: 7, frame: CGRect(x: -200, y: 100, width: 400, height: 300), visible: [.init(200, 400)])
        sim.synchronize(surfaces: [surface], settings: .init(), liveWindowIDs: [7])
        XCTAssertEqual(sim.profiles[7]?.height(at: 80), 0)
        XCTAssertEqual(sim.profiles[7]?.height(at: 300), 18)
    }
    func testAttachedSnowmanTransfersToDisplayWithNegativeCoordinates() {
        var balls: [Snowball] = []
        for (index, radius): (Int, CGFloat) in [CGFloat(25), 17, 9].enumerated() {
            var ball = Snowball(id: UInt64(index + 1), radius: radius, position: .zero)
            ball.surfaceID = 7; ball.localX = 100; ball.anchorHeight = [CGFloat(25), 67, 93][index]
            ball.supportID = index == 0 ? nil : UInt64(index)
            balls.append(ball)
        }
        let source = SnowGame(balls: balls), target = SnowGame()
        XCTAssertTrue(source.transfer(on: 7, to: target) { _ in true })
        XCTAssertTrue(source.balls.isEmpty); XCTAssertEqual(target.snowmen, [[1, 2, 3]])
        let display = CGRect(x: -1000, y: 900, width: 1000, height: 900)
        let global = CGRect(x: -800, y: 1100, width: 400, height: 200)
        let surface = SnowSurface(id: 7, frame: SnowCoordinates.localRect(global, display: display), visible: [.init(0, 400)])
        target.step(delta: 0, surfaces: [surface], profiles: [7: SnowProfile(width: 400, maximum: 18)], size: display.size)
        XCTAssertEqual(target.balls[0].position, CGPoint(x: 300, y: 425))
        XCTAssertEqual(target.balls[2].position, CGPoint(x: 300, y: 493))
    }
    func testTransferToFullDisplayPreservesSourceObjects() {
        var ball = Snowball(id: 1, radius: 20, position: CGPoint(x: 100, y: 200)); ball.surfaceID = 7
        let source = SnowGame(balls: [ball])
        let target = SnowGame(balls: (100..<130).map { .init(id: UInt64($0), radius: 10, position: .zero) })
        XCTAssertFalse(source.transfer(on: 7, to: target) { _ in true })
        XCTAssertEqual(source.balls.count, 1); XCTAssertEqual(target.balls.count, 30)
        XCTAssertEqual(source.message, "game.limit")
    }
    func testGeneratedBallIDsAreUniqueAcrossDisplayModels() {
        let a = SnowGame(), b = SnowGame(); let surface = bottom()
        for game in [a, b] {
            var profiles = [surface.id: filled()]
            game.begin(at: CGPoint(x: 100, y: 30), surfaces: [surface], profiles: profiles)
            game.drag(to: CGPoint(x: 120, y: 30), surfaces: [surface], profiles: &profiles)
        }
        XCTAssertEqual(a.balls.count, 1); XCTAssertEqual(b.balls.count, 1)
        XCTAssertNotEqual(a.balls.first?.id, b.balls.first?.id)
    }
    func testImportValidationRejectsLimitsAndWrongTypes() {
        XCTAssertTrue(ImageImportPolicy.accepts(byteCount: 1024, type: "public.heic", width: 4000, height: 3000))
        XCTAssertFalse(ImageImportPolicy.accepts(byteCount: 20 * 1024 * 1024 + 1, type: "public.png", width: 1, height: 1))
        XCTAssertFalse(ImageImportPolicy.accepts(byteCount: 1024, type: "public.tiff", width: 100, height: 100))
        XCTAssertFalse(ImageImportPolicy.accepts(byteCount: 1024, type: "public.jpeg", width: 0, height: 100))
        XCTAssertFalse(ImageImportPolicy.accepts(byteCount: 1024, type: "public.png", width: Int.max, height: Int.max))
    }
}
