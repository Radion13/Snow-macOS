import XCTest
@testable import SnowCore

final class SnowAppearanceTests: XCTestCase {
    func testLegacyPreferencesDefaultToSimpleWithoutResettingOtherChoices() {
        let old = Data(#"{"wind":-43,"quality":"economical","weather":"light","windowHeight":27,"garland":"wave"}"#.utf8)
        let settings = SnowSettings.load(old)
        XCTAssertEqual(settings.snowAppearance, .simple)
        XCTAssertEqual(settings.wind, -43); XCTAssertEqual(settings.windowHeight, 27)
        XCTAssertEqual(settings.quality, .economical); XCTAssertEqual(settings.garland, .wave)
    }
    func testFreshResetAndInvalidPreferencesUseSimpleSnow() {
        XCTAssertEqual(SnowSettings().snowAppearance, .simple)
        XCTAssertEqual(SnowSettings.load(nil).snowAppearance, .simple)
        XCTAssertEqual(SnowSettings.load(Data("broken".utf8)).snowAppearance, .simple)
    }
    func testBothAppearancesSurviveSavingWithOtherPreferences() throws {
        for appearance in SnowAppearance.allCases {
            var settings = SnowSettings(); settings.snowAppearance = appearance
            settings.accumulateOnDock = true; settings.garlandBrightness = 0.35
            let restored = SnowSettings.load(try JSONEncoder().encode(settings))
            XCTAssertEqual(restored, settings)
        }
    }
    func testUnknownFutureAppearanceFallsBackWithoutResettingPreferences() {
        let data = Data(#"{"snowAppearance":"future-material","wind":28,"weather":"blizzard"}"#.utf8)
        let settings = SnowSettings.load(data)
        XCTAssertEqual(settings.snowAppearance, .simple)
        XCTAssertEqual(settings.wind, 28); XCTAssertEqual(settings.weather, .blizzard)
    }
}
