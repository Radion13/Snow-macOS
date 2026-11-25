import Foundation

public enum PauseReason: String, Hashable, CaseIterable {
    case user, hidden, sleep, sessionInactive, displaySleep, fullscreen, systemRestriction
    public var hidesEffects: Bool { self != .user }
}

public struct PauseState: Equatable {
    public private(set) var reasons: Set<PauseReason> = []
    public init() {}
    public mutating func set(_ reason: PauseReason, active: Bool) {
        if active { reasons.insert(reason) } else { reasons.remove(reason) }
    }
    public var isPaused: Bool { !reasons.isEmpty }
    public var isHidden: Bool { reasons.contains(where: \.hidesEffects) }
    public var allowsInteraction: Bool { reasons.isEmpty }
}

/// The clock is reset on every stop/resume; no catch-up emission after a long pause.
public struct SimulationClock {
    private var previous: TimeInterval?
    public init() {}
    public mutating func reset() { previous = nil }
    public mutating func advance(to time: TimeInterval) -> Double {
        defer { previous = time }
        guard let previous else { return 0 }
        return min(1.0 / 15.0, max(0, time - previous))
    }
}
