import AppKit
import CoreGraphics

struct GeometryReading {
    var windows: [WindowSnapshot]
    var liveIDs: Set<UInt32>?
    var available: Bool
    var dockFrames: [CGRect] = []
    var widgets: [WindowSnapshot] = []
}

/// Only ID, bounds, layer, alpha, process ID and visibility are inspected.
/// No title key, image capture, Accessibility or event tap is used.
final class WindowGeometryProvider {
    private var lastPrune = Date.distantPast
    private var liveIDs: Set<UInt32>?
    private var previousDockFrames: [CGRect] = []
    private var appBundles: [Int32: String] = [:]
    private var lastAppRefresh = Date.distantPast
    func read(excluding overlayIDs: Set<UInt32>) -> GeometryReading {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return .init(windows: [], liveIDs: nil, available: false)
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if Date().timeIntervalSince(lastAppRefresh) >= 2 {
            appBundles = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0.bundleIdentifier ?? "") })
            lastAppRefresh = Date()
        }
        var docks: [CGRect] = []
        var widgets: [WindowSnapshot] = []
        let windows: [WindowSnapshot] = list.compactMap { item in
            guard let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  !overlayIDs.contains(id),
                  (item[kCGWindowIsOnscreen as String] as? Bool) == true,
                  let layer = (item[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width > 1, rect.height > 1,
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0.01 else { return nil }
            let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            let bundle = pid.flatMap { appBundles[$0] } ?? ""
            let appKitRect = SnowCoordinates.appKitRect(fromCG: rect, primaryTop: primaryTop)
            if bundle == "com.apple.dock", layer >= 0, layer <= 30 { docks.append(appKitRect) }
            // Desktop-only widget windows. Notification Center panels (nonnegative layers)
            // and full-screen desktop backing windows cannot become widget surfaces.
            if (bundle.lowercased().contains("widget") || bundle == "com.apple.notificationcenterui"),
               layer < 0, rect.width >= 90, rect.height >= 90, rect.width <= 650, rect.height <= 650 {
                widgets.append(.init(id: id, frame: appKitRect))
            }
            guard layer >= 0, layer <= Int(CGWindowLevelForKey(.floatingWindow)) else { return nil }
            let opaque = (item[kCGWindowAlpha as String] as? Double ?? 1) >= 0.95
            return .init(id: id, frame: appKitRect,
                         eligible: layer == 0 && pid != ownPID && opaque)
        }
        if Date().timeIntervalSince(lastPrune) >= 2 {
            lastPrune = Date()
            if let all = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] {
                liveIDs = Set(all.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
            }
        }
        let stableDocks = docks.filter { frame in previousDockFrames.contains { previous in
            abs(previous.minX - frame.minX) < 1 && abs(previous.minY - frame.minY) < 1 &&
            abs(previous.width - frame.width) < 1 && abs(previous.height - frame.height) < 1
        } }
        previousDockFrames = docks
        return .init(windows: windows, liveIDs: liveIDs, available: true, dockFrames: stableDocks, widgets: Array(widgets.prefix(32)))
    }
}
