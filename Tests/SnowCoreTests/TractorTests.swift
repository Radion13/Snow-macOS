import XCTest
import CoreGraphics
@testable import SnowCore

final class TractorTests: XCTestCase {
    private func filled() -> SnowProfile {
        var profile = SnowProfile(width: 800, maximum: 48)
        for x in stride(from: CGFloat(0), through: 800, by: 4) { profile.deposit(at: x, amount: 100) }
        return profile
    }
    func testOnlyTwoTractorsAndRemovedPreferencesMigrateWithoutReset() throws {
        XCTAssertEqual(CleanerCharacter.allCases, [.tractor, .retro])
        for removed in ["snowmobile", "penguin", "custom"] {
            let json = "{\"cleaner\":\"\(removed)\",\"wind\":37,\"weather\":\"blizzard\",\"garlandBrightness\":0.42}"
            let migrated = SnowSettings.load(Data(json.utf8))
            XCTAssertEqual(migrated.cleaner, .tractor); XCTAssertEqual(migrated.wind, 37)
            XCTAssertEqual(migrated.weather, .blizzard); XCTAssertEqual(migrated.garlandBrightness, 0.42)
        }
        var settings = SnowSettings(); settings.cleaner = .retro
        XCTAssertEqual(SnowSettings.load(try JSONEncoder().encode(settings)), settings)
    }
    func testWheelsRollFromDistanceAndNewPassResetsMotion() {
        let cleaner = SnowCleaner(); var profile: SnowProfile? = filled()
        XCTAssertTrue(cleaner.start(character: .tractor))
        for _ in 0..<60 { cleaner.step(delta: 1.0 / 60, width: 800, settings: .init(), profile: &profile) }
        XCTAssertEqual(cleaner.travelled, 160, accuracy: 0.001)
        let rear = CleanerGeometry.wheelRotation(distance: cleaner.travelled, radius: CleanerGeometry.rearWheelRadius)
        let front = CleanerGeometry.wheelRotation(distance: cleaner.travelled, radius: CleanerGeometry.frontWheelRadius)
        XCTAssertLessThan(front, rear); XCTAssertLessThan(rear, 0)
        XCTAssertEqual(rear * CleanerGeometry.rearWheelRadius, -160, accuracy: 0.001)
        let before = cleaner.travelled
        cleaner.step(delta: 0, width: 800, settings: .init(), profile: &profile)
        XCTAssertEqual(cleaner.travelled, before)
        cleaner.clear(); XCTAssertTrue(cleaner.start(character: .retro))
        XCTAssertEqual(cleaner.travelled, 0); XCTAssertEqual(cleaner.snowLoad, 0)
    }
    func testBucketClearsAtItsLeadingEdgeAndCollectsSnow() {
        let cleaner = SnowCleaner(); var profile: SnowProfile? = filled()
        XCTAssertTrue(cleaner.start(character: .tractor))
        cleaner.step(delta: 1.0 / 60, width: 800, settings: .init(), profile: &profile)
        XCTAssertEqual(cleaner.collectedArea, 0); XCTAssertEqual(profile!.height(at: 0), 48)
        for _ in 1..<20 { cleaner.step(delta: 1.0 / 60, width: 800, settings: .init(), profile: &profile) }
        XCTAssertEqual(profile!.height(at: 24), 0)
        XCTAssertEqual(profile!.height(at: 48), 48)
        XCTAssertGreaterThan(cleaner.collectedArea, 0); XCTAssertTrue((0...1).contains(cleaner.snowLoad))
        XCTAssertGreaterThan(cleaner.x! + CleanerGeometry.bucketEdge, 24)
        XCTAssertLessThan(cleaner.x! + CleanerGeometry.bucketEdge, 48)
        cleaner.clear(); XCTAssertEqual(cleaner.snowLoad, 0)
    }
}
