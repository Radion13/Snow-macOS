import XCTest
import CoreGraphics
@testable import SnowCore

final class SnowflakeSettingsTests: XCTestCase {
    func testFreshAndLegacyPreferencesUseOriginalFlakesAndSize() {
        let fresh = SnowSettings.load(nil)
        XCTAssertEqual(fresh.snowflakeStyle, .simple); XCTAssertEqual(fresh.snowflakeSize, 1)
        let legacy = SnowSettings.load(Data(#"{"snowAppearance":"textured","wind":32,"weather":"light"}"#.utf8))
        XCTAssertEqual(legacy.snowflakeStyle, .simple); XCTAssertEqual(legacy.snowflakeSize, 1)
        XCTAssertEqual(legacy.snowAppearance, .textured); XCTAssertEqual(legacy.wind, 32)
        XCTAssertEqual(legacy.weather, .light)
    }
    func testFlakesSaveIndependentlyOfSurfaceAppearance() throws {
        for appearance in SnowAppearance.allCases {
            for style in SnowflakeStyle.allCases {
                var settings = SnowSettings(); settings.snowAppearance = appearance
                settings.snowflakeStyle = style; settings.snowflakeSize = 2.4; settings.garlandBrightness = 0.35
                XCTAssertEqual(SnowSettings.load(try JSONEncoder().encode(settings)), settings)
            }
        }
    }
    func testUnknownFutureStyleKeepsOtherSettings() {
        let settings = SnowSettings.load(Data(#"{"snowflakeStyle":"future-shape","snowflakeSize":1.8,"wind":-21}"#.utf8))
        XCTAssertEqual(settings.snowflakeStyle, .simple)
        XCTAssertEqual(settings.snowflakeSize, 1.8); XCTAssertEqual(settings.wind, -21)
    }
    func testSizeBoundsAndNonFiniteValues() {
        for (value, expected): (Double, Double) in [(0, 0.5), (-10, 0.5), (10, 3), (1.7, 1.7), (.nan, 1), (.infinity, 1), (-.infinity, 1)] {
            var settings = SnowSettings(); settings.snowflakeSize = value; settings.sanitize()
            XCTAssertEqual(settings.snowflakeSize, expected)
        }
    }
    func testStyleAndSizeDoNotChangePhysicsOrAccumulation() {
        let first = SnowSimulation(size: CGSize(width: 400, height: 180), seed: 123)
        let second = SnowSimulation(size: first.size, seed: 123)
        var a = SnowSettings(); a.wind = 18
        var b = a; b.snowflakeStyle = .patterned; b.snowflakeSize = 3; b.snowAppearance = .textured
        first.synchronize(surfaces: [], settings: a, liveWindowIDs: [])
        second.synchronize(surfaces: [], settings: b, liveWindowIDs: [])
        let budget = RenderBudget.resolve(quality: .economical, lowPower: false, thermallyLimited: false, reduceMotion: false)
        for _ in 0..<600 {
            first.step(delta: 1.0 / 60, settings: a, budget: budget)
            second.step(delta: 1.0 / 60, settings: b, budget: budget)
        }
        XCTAssertEqual(first.particles, second.particles)
        XCTAssertEqual(first.profiles, second.profiles)
        XCTAssertGreaterThan(first.profiles[SurfaceGeometry.bottomID]!.snowArea, 0)
    }
    func testVisualIdentityStaysStableWhileFlakesMoveAndNewOnesArrive() {
        let simulation = SnowSimulation(size: CGSize(width: 800, height: 1000), seed: 91)
        var settings = SnowSettings(); settings.weather = .blizzard; settings.accumulateAtBottom = false
        simulation.synchronize(surfaces: [], settings: settings, liveWindowIDs: [])
        let budget = RenderBudget(framesPerSecond: 30, particleLimit: 400, birthMultiplier: 1)
        simulation.step(delta: 1.0 / 15, settings: settings, budget: budget)
        let old = simulation.particles.map(\.flakeSeed)
        XCTAssertFalse(old.isEmpty)
        for _ in 0..<10 { simulation.step(delta: 1.0 / 15, settings: settings, budget: budget) }
        XCTAssertEqual(Array(simulation.particles.prefix(old.count).map(\.flakeSeed)), old)
        XCTAssertEqual(Set(simulation.particles.map(\.flakeSeed)).count, simulation.particles.count)
        XCTAssertEqual(Set(simulation.particles.map { ($0.flakeSeed >> 16) % 8 }).count, 8)
    }
}
