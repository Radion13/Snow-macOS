import Foundation
import CoreGraphics

public enum CleanerGeometry {
    public static let startX: CGFloat = -120
    public static let bucketEdge: CGFloat = 98
    public static let bucketContactWidth: CGFloat = 8
    public static let rearWheelRadius: CGFloat = 26
    public static let frontWheelRadius: CGFloat = 17
    public static func wheelRotation(distance: CGFloat, radius: CGFloat) -> CGFloat { -distance / max(1, radius) }
}

public final class SnowCleaner {
    public private(set) var x: CGFloat?
    public private(set) var character: CleanerCharacter = .tractor
    public private(set) var travelled: CGFloat = 0
    public private(set) var collectedArea: CGFloat = 0
    public var snowLoad: CGFloat { min(1, collectedArea / 1400) }
    private var lastAutomatic: Double = -.greatestFiniteMagnitude
    private var time: Double = 0
    public init() {}
    @discardableResult public func start(character: CleanerCharacter, automatic: Bool = false) -> Bool {
        guard x == nil, !automatic || time - lastAutomatic >= 60 else { return false }
        self.character = character; x = CleanerGeometry.startX; travelled = 0; collectedArea = 0
        if automatic { lastAutomatic = time }
        return true
    }
    public func clear() { x = nil; travelled = 0; collectedArea = 0 }
    public func step(delta: Double, width: CGFloat, settings: SnowSettings, profile: inout SnowProfile?) {
        time += min(1.0 / 15, max(0, delta))
        if settings.automaticCleaner, settings.accumulateAtBottom, let profile, profile.filledFraction >= 0.6 {
            _ = start(character: settings.cleaner, automatic: true)
        }
        guard let position = x else { return }
        let next = position + CGFloat(min(1.0 / 15, max(0, delta))) * 160
        let pickedUp = profile?.clearRange(from: position + CleanerGeometry.bucketEdge - CleanerGeometry.bucketContactWidth,
                                           to: next + CleanerGeometry.bucketEdge) ?? 0
        collectedArea = min(1400, collectedArea + pickedUp)
        travelled += next - position
        x = next > width + 120 ? nil : next
    }
}

public enum ImageImportPolicy {
    public static let maximumBytes = 20 * 1024 * 1024
    public static let maximumDimension = 1024
    public static let maximumSourcePixels = 80_000_000
    public static func accepts(byteCount: Int, type: String, width: Int, height: Int) -> Bool {
        byteCount > 0 && byteCount <= maximumBytes && width > 0 && height > 0 && width <= 20000 && height <= 20000 &&
        width * height <= maximumSourcePixels &&
        ["public.png", "public.jpeg", "public.heic", "public.heif"].contains(type)
    }
}
