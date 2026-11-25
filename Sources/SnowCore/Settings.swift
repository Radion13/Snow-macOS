import Foundation

public enum SnowWeather: String, Codable, CaseIterable {
    case light, steady, blizzard
    public var birthRate: Double { switch self { case .light: return 24; case .steady: return 65; case .blizzard: return 145 } }
    public var speed: Double { switch self { case .light: return 32; case .steady: return 55; case .blizzard: return 95 } }
}

public enum SnowQuality: String, Codable, CaseIterable { case auto, economical, smooth }
public enum SnowAppearance: String, Codable, CaseIterable {
    case simple, textured
    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .simple
    }
}
public enum SnowflakeStyle: String, Codable, CaseIterable {
    case simple, patterned
    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .simple
    }
}
public enum SnowTool: String, CaseIterable { case mitten, shovel, snowball, delete }
public enum CleanerCharacter: String, Codable, CaseIterable {
    case tractor, retro
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // Removed characters migrate without resetting unrelated preferences.
        self = Self(rawValue: raw) ?? .tractor
    }
}
public enum GarlandMode: String, Codable, CaseIterable { case off, steady, twinkle, wave }
public enum GarlandPalette: String, Codable, CaseIterable { case warm, festive, icy }
public enum GarlandStyle: String, Codable, CaseIterable { case classic, stars, glow }
public enum WinterScene: String, Codable, CaseIterable { case none, cabin, porch }
public enum ImportPlacement: String, CaseIterable { case blade }

public struct SnowSettings: Codable, Equatable {
    public var weather: SnowWeather = .steady
    public var wind: Double = 0
    public var accumulateOnWindows = true
    public var accumulateAtBottom = true
    public var windowHeight: Double = 18
    public var bottomHeight: Double = 48
    public var allDisplays = true
    public var displayIDs: Set<UInt32> = []
    public var quality: SnowQuality = .auto
    public var snowAppearance: SnowAppearance = .simple
    public var snowflakeStyle: SnowflakeStyle = .simple
    public var snowflakeSize: Double = 1
    public var decorativeSweep = true
    public var respectReduceMotion = true
    public var accumulateOnDock = false
    public var verticalDock = false
    public var accumulateOnWidgets = false
    public var cleaner: CleanerCharacter = .tractor
    public var automaticCleaner = false
    public var useBladeImage = false
    public var garland: GarlandMode = .off
    public var garlandPalette: GarlandPalette = .festive
    public var garlandStyle: GarlandStyle = .classic
    public var garlandBrightness: Double = 0.75
    public var garlandBlinkIntensity: Double = 0.7
    public var scenes: [UInt32: WinterScene] = [:]
    public init() {}

    // Older P0 preferences remain valid when new fields are introduced.
    private enum CodingKeys: String, CodingKey {
        case weather, wind, accumulateOnWindows, accumulateAtBottom, windowHeight, bottomHeight
        case allDisplays, displayIDs, quality, snowAppearance, snowflakeStyle, snowflakeSize, decorativeSweep, respectReduceMotion
        case accumulateOnDock, verticalDock, accumulateOnWidgets, cleaner, automaticCleaner, useBladeImage
        case garland, garlandPalette, garlandStyle, garlandBrightness, garlandBlinkIntensity, scenes
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weather = try c.decodeIfPresent(SnowWeather.self, forKey: .weather) ?? weather
        wind = try c.decodeIfPresent(Double.self, forKey: .wind) ?? wind
        accumulateOnWindows = try c.decodeIfPresent(Bool.self, forKey: .accumulateOnWindows) ?? accumulateOnWindows
        accumulateAtBottom = try c.decodeIfPresent(Bool.self, forKey: .accumulateAtBottom) ?? accumulateAtBottom
        windowHeight = try c.decodeIfPresent(Double.self, forKey: .windowHeight) ?? windowHeight
        bottomHeight = try c.decodeIfPresent(Double.self, forKey: .bottomHeight) ?? bottomHeight
        allDisplays = try c.decodeIfPresent(Bool.self, forKey: .allDisplays) ?? allDisplays
        displayIDs = try c.decodeIfPresent(Set<UInt32>.self, forKey: .displayIDs) ?? displayIDs
        quality = try c.decodeIfPresent(SnowQuality.self, forKey: .quality) ?? quality
        snowAppearance = try c.decodeIfPresent(SnowAppearance.self, forKey: .snowAppearance) ?? snowAppearance
        snowflakeStyle = try c.decodeIfPresent(SnowflakeStyle.self, forKey: .snowflakeStyle) ?? snowflakeStyle
        snowflakeSize = try c.decodeIfPresent(Double.self, forKey: .snowflakeSize) ?? snowflakeSize
        decorativeSweep = try c.decodeIfPresent(Bool.self, forKey: .decorativeSweep) ?? decorativeSweep
        respectReduceMotion = try c.decodeIfPresent(Bool.self, forKey: .respectReduceMotion) ?? respectReduceMotion
        accumulateOnDock = try c.decodeIfPresent(Bool.self, forKey: .accumulateOnDock) ?? accumulateOnDock
        verticalDock = try c.decodeIfPresent(Bool.self, forKey: .verticalDock) ?? verticalDock
        accumulateOnWidgets = try c.decodeIfPresent(Bool.self, forKey: .accumulateOnWidgets) ?? accumulateOnWidgets
        cleaner = try c.decodeIfPresent(CleanerCharacter.self, forKey: .cleaner) ?? cleaner
        automaticCleaner = try c.decodeIfPresent(Bool.self, forKey: .automaticCleaner) ?? automaticCleaner
        useBladeImage = try c.decodeIfPresent(Bool.self, forKey: .useBladeImage) ?? useBladeImage
        garland = try c.decodeIfPresent(GarlandMode.self, forKey: .garland) ?? garland
        garlandPalette = try c.decodeIfPresent(GarlandPalette.self, forKey: .garlandPalette) ?? garlandPalette
        garlandStyle = try c.decodeIfPresent(GarlandStyle.self, forKey: .garlandStyle) ?? garlandStyle
        if !c.contains(.garlandStyle), garlandPalette == .warm { garlandPalette = .festive }
        garlandBrightness = try c.decodeIfPresent(Double.self, forKey: .garlandBrightness) ?? garlandBrightness
        garlandBlinkIntensity = try c.decodeIfPresent(Double.self, forKey: .garlandBlinkIntensity) ?? garlandBlinkIntensity
        scenes = try c.decodeIfPresent([UInt32: WinterScene].self, forKey: .scenes) ?? scenes
    }

    public mutating func sanitize() {
        wind = wind.isFinite ? min(100, max(-100, wind)) : 0
        windowHeight = windowHeight.isFinite ? min(36, max(4, windowHeight)) : 18
        bottomHeight = bottomHeight.isFinite ? min(96, max(8, bottomHeight)) : 48
        snowflakeSize = snowflakeSize.isFinite ? min(3, max(0.5, snowflakeSize)) : 1
        displayIDs = Set(displayIDs.sorted().prefix(16))
        garlandBrightness = garlandBrightness.isFinite ? min(1, max(0, garlandBrightness)) : 0.75
        garlandBlinkIntensity = garlandBlinkIntensity.isFinite ? min(1, max(0, garlandBlinkIntensity)) : 0.7
        scenes = Dictionary(uniqueKeysWithValues: scenes.sorted { $0.key < $1.key }.prefix(16).map { ($0.key, $0.value) })
    }

    public static func load(_ data: Data?) -> SnowSettings {
        guard let data, var settings = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        settings.sanitize()
        return settings
    }
}

/// One bounded calculation per existing lamp; intensity changes depth and tempo
/// without adding timers, particles or SpriteKit actions.
public enum GarlandLighting {
    public static func alpha(time: Double, index: Int, settings: SnowSettings, reduceMotion: Bool) -> Double {
        let brightness = settings.garlandBrightness.isFinite ? min(1, max(0, settings.garlandBrightness)) : 0.75
        guard settings.garland != .off else { return 0 }
        guard !reduceMotion, settings.garland == .twinkle || settings.garland == .wave else { return brightness }
        let intensity = settings.garlandBlinkIntensity.isFinite ? min(1, max(0, settings.garlandBlinkIntensity)) : 0.7
        let wave = settings.garland == .wave
        let phase = Double(index) * (wave ? 0.3 : 1.73)
        let speed = (wave ? 1.8 : 1.2) * (0.3 + intensity)
        let pulse = 1 - intensity * 0.5 * (1 - sin(time * speed - phase))
        return brightness * pulse
    }
}

public struct RenderBudget: Equatable {
    public let framesPerSecond: Int
    public let particleLimit: Int
    public let birthMultiplier: Double
    public static func resolve(quality: SnowQuality, lowPower: Bool, thermallyLimited: Bool, reduceMotion: Bool) -> Self {
        // Initial profiling on the reference M3 Pro exceeded 10% CPU at 60 Hz.
        // Auto starts at the measured conservative tier; Smooth remains an explicit choice.
        let economy = quality != .smooth || lowPower || thermallyLimited || reduceMotion
        return .init(framesPerSecond: economy ? 30 : 60, particleLimit: economy ? 360 : 1100, birthMultiplier: reduceMotion ? 0.35 : (economy ? 0.6 : 1))
    }
    public func particleLimit(for weather: SnowWeather) -> Int {
        let fraction: Double
        switch weather { case .light: fraction = 0.35; case .steady: fraction = 0.65; case .blizzard: fraction = 1 }
        return max(30, Int(Double(particleLimit) * fraction))
    }
}
