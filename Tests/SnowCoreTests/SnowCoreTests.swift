import XCTest
import CoreGraphics
@testable import SnowCore

final class SnowCoreTests: XCTestCase {
    func testCGCoordinatesOnNegativeAndUpperDisplaysUsePoints() {
        let cg = CGRect(x: -1600, y: -900, width: 800, height: 600)
        let appKit = SnowCoordinates.appKitRect(fromCG: cg, primaryTop: 1000)
        XCTAssertEqual(appKit, CGRect(x: -1600, y: 1300, width: 800, height: 600))
        let local = SnowCoordinates.localRect(appKit, display: CGRect(x: -1600, y: 1000, width: 1600, height: 900))
        XCTAssertEqual(local.origin, CGPoint(x: 0, y: 300))
        // Retina scale does not enter a point-to-point coordinate conversion.
        XCTAssertEqual(local.width, 800)
    }
    func testFrontWindowClipsRearSnowAcrossEntireBand() {
        let front = WindowSnapshot(id: 1, frame: CGRect(x: 150, y: 310, width: 150, height: 200))
        let rear = WindowSnapshot(id: 2, frame: CGRect(x: 50, y: 100, width: 400, height: 200))
        let surfaces = SurfaceGeometry.surfaces(windows: [front, rear], display: CGRect(x: 0, y: 0, width: 800, height: 600), snowHeight: 18)
        XCTAssertEqual(surfaces.first(where: { $0.id == 2 })?.visible, [.init(0, 100), .init(250, 400)])
    }
    func testOwnIneligibleWindowStillOccludesRearWindow() {
        let front = WindowSnapshot(id: 1, frame: CGRect(x: 0, y: 250, width: 400, height: 200), eligible: false)
        let rear = WindowSnapshot(id: 2, frame: CGRect(x: 0, y: 100, width: 400, height: 200))
        XCTAssertTrue(SurfaceGeometry.surfaces(windows: [front, rear], display: CGRect(x: 0, y: 0, width: 800, height: 600), snowHeight: 18).isEmpty)
    }
    func testFullscreenDoesNotConfuseMaximizedVisibleFrame() {
        let screen = CGRect(x: -1200, y: 900, width: 1200, height: 900)
        XCTAssertTrue(SurfaceGeometry.isFullscreen(screen, on: screen))
        XCTAssertFalse(SurfaceGeometry.isFullscreen(screen.insetBy(dx: 0, dy: 30), on: screen))
    }
    func testProfileRetainsLocalCoordinatesOnResizeAndClampsHeight() {
        var profile = SnowProfile(width: 400, maximum: 18)
        for _ in 0..<100 { profile.deposit(at: 80, amount: 3) }
        XCTAssertEqual(profile.height(at: 80), 18)
        profile.resize(to: 200, maximum: 12)
        XCTAssertEqual(profile.height(at: 80), 12)
        profile.resize(to: 500, maximum: 12)
        XCTAssertEqual(profile.height(at: 400), 0)
        XCTAssertLessThanOrEqual(profile.heights.max()!, 12)
    }
    func testClosedWindowRemovedButMinimizedWindowRetained() {
        let sim = SnowSimulation(size: CGSize(width: 800, height: 600))
        let surface = SnowSurface(id: 7, frame: CGRect(x: 20, y: 100, width: 400, height: 200), visible: [.init(0, 400)])
        sim.synchronize(surfaces: [surface], settings: .init(), liveWindowIDs: [7])
        sim.synchronize(surfaces: [], settings: .init(), liveWindowIDs: [7])
        XCTAssertNotNil(sim.profiles[7])
        XCTAssertFalse(sim.surfaces.contains(where: { $0.id == 7 }))
        sim.synchronize(surfaces: [], settings: .init(), liveWindowIDs: [])
        XCTAssertNil(sim.profiles[7])
    }
    func testMovedWindowKeepsItsProfileInLocalCoordinates() {
        let sim = SnowSimulation(size: CGSize(width: 800, height: 600))
        var settings = SnowSettings(); settings.accumulateAtBottom = false
        let surface = SnowSurface(id: 8, frame: CGRect(x: 0, y: 100, width: 800, height: 200), visible: [.init(0, 800)])
        sim.synchronize(surfaces: [surface], settings: settings, liveWindowIDs: [8])
        let budget = RenderBudget.resolve(quality: .economical, lowPower: false, thermallyLimited: false, reduceMotion: false)
        for _ in 0..<900 { sim.step(delta: 1.0 / 30, settings: settings, budget: budget) }
        let before = sim.profiles[8]
        var moved = surface; moved.frame = moved.frame.offsetBy(dx: -70, dy: 50)
        sim.synchronize(surfaces: [moved], settings: settings, liveWindowIDs: [8])
        XCTAssertTrue(before!.heights.contains(where: { $0 > 0 }))
        XCTAssertEqual(sim.profiles[8], before)
    }
    func testIndependentReasonsAndNoCatchUpAfterPause() {
        var state = PauseState()
        state.set(.user, active: true); state.set(.fullscreen, active: true)
        state.set(.fullscreen, active: false)
        XCTAssertTrue(state.isPaused); XCTAssertFalse(state.isHidden)
        XCTAssertFalse(state.allowsInteraction)
        state.set(.sleep, active: true); state.set(.sleep, active: false)
        XCTAssertEqual(state.reasons, [.user])
        var clock = SimulationClock()
        XCTAssertEqual(clock.advance(to: 1), 0)
        XCTAssertEqual(clock.advance(to: 1.02), 0.02, accuracy: 0.00001)
        clock.reset()
        XCTAssertEqual(clock.advance(to: 3600), 0)
        XCTAssertLessThanOrEqual(clock.advance(to: 9999), 1.0 / 15)
    }
    func testTenMinutesBlizzardParticleAndProfileBudgets() {
        let sim = SnowSimulation(size: CGSize(width: 600, height: 400))
        var settings = SnowSettings(); settings.weather = .blizzard
        let budget = RenderBudget.resolve(quality: .economical, lowPower: false, thermallyLimited: false, reduceMotion: false)
        sim.synchronize(surfaces: [], settings: settings, liveWindowIDs: [])
        var peak = 0
        for _ in 0..<18_000 {
            sim.step(delta: 1.0 / 30, settings: settings, budget: budget)
            peak = max(peak, sim.particles.count)
        }
        XCTAssertLessThanOrEqual(peak, budget.particleLimit)
        XCTAssertLessThanOrEqual(sim.profiles[SurfaceGeometry.bottomID]!.heights.max()!, 48)
    }
    func testSimulationIsDeterministicAndClearKeepsWeatherAndFallingSnow() {
        let a = SnowSimulation(size: CGSize(width: 500, height: 300), seed: 123)
        let b = SnowSimulation(size: CGSize(width: 500, height: 300), seed: 123)
        let settings = SnowSettings()
        let budget = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: false)
        for sim in [a, b] {
            sim.synchronize(surfaces: [], settings: settings, liveWindowIDs: [])
            for _ in 0..<100 { sim.step(delta: 1.0 / 30, settings: settings, budget: budget) }
        }
        XCTAssertEqual(a.particles, b.particles)
        let particles = a.particles
        a.clear()
        XCTAssertEqual(a.particles, particles)
        XCTAssertTrue(a.profiles.values.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }
    func testCorruptSettingsAndSanitization() {
        XCTAssertEqual(SnowSettings.load(Data("bad".utf8)), SnowSettings())
        var settings = SnowSettings(); settings.wind = 900; settings.bottomHeight = -10; settings.windowHeight = .infinity
        settings.sanitize()
        XCTAssertEqual(settings.wind, 100); XCTAssertEqual(settings.bottomHeight, 8); XCTAssertEqual(settings.windowHeight, 18)
    }
    func testPowerAndReduceMotionOverrideSmoothQuality() {
        let power = RenderBudget.resolve(quality: .smooth, lowPower: true, thermallyLimited: false, reduceMotion: false)
        XCTAssertEqual(power.framesPerSecond, 30)
        XCTAssertEqual(power.particleLimit, 360)
        let reduced = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: true)
        XCTAssertEqual(reduced.birthMultiplier, 0.35)
    }
    func testRetainedProfileCacheIsBounded() {
        let sim = SnowSimulation(size: CGSize(width: 800, height: 600))
        for id: UInt32 in 1...400 {
            let surface = SnowSurface(id: id, frame: CGRect(x: 0, y: 10, width: 200, height: 100), visible: [.init(0, 200)])
            sim.synchronize(surfaces: [surface], settings: .init(), liveWindowIDs: nil)
        }
        XCTAssertLessThanOrEqual(sim.profiles.count, 128)
    }
    func testWeatherDensitiesStayDistinctAfterReachingBudgets() {
        let budget = RenderBudget.resolve(quality: .auto, lowPower: false, thermallyLimited: false, reduceMotion: false)
        var densities: [Int] = []
        for weather in SnowWeather.allCases {
            let sim = SnowSimulation(size: CGSize(width: 800, height: 600))
            var settings = SnowSettings(); settings.weather = weather
            for _ in 0..<1800 { sim.step(delta: 1.0 / 30, settings: settings, budget: budget) }
            densities.append(sim.particles.count)
            XCTAssertLessThanOrEqual(sim.particles.count, budget.particleLimit(for: weather))
        }
        XCTAssertLessThan(densities[0], densities[1])
        XCTAssertLessThan(densities[1], densities[2])
    }
}
