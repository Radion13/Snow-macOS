import AppKit

/// Independent, short-lived test fixture. Uses only its own windows and public geometry APIs.
/// Compile alongside Geometry.swift and WindowGeometryProvider.swift (see README).
@main
enum PlatformProbe {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let provider = WindowGeometryProvider()
        var checks: [String: Bool] = [:]
        let rear = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 480, height: 280), styleMask: [.titled, .resizable, .miniaturizable], backing: .buffered, defer: false)
        let front = NSWindow(contentRect: NSRect(x: 260, y: 280, width: 300, height: 240), styleMask: [.titled, .resizable, .miniaturizable], backing: .buffered, defer: false)
        rear.isReleasedWhenClosed = false; front.isReleasedWhenClosed = false
        rear.orderFrontRegardless(); front.orderFrontRegardless()
        let rearID = UInt32(rear.windowNumber), frontID = UInt32(front.windowNumber)
        func pump(_ duration: TimeInterval = 0.5) { RunLoop.current.run(until: Date(timeIntervalSinceNow: duration)) }
        func finish() {
            rear.close(); front.close()
            if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]), let json = String(data: data, encoding: .utf8) { print(json) }
        }
        pump()
        var reading = provider.read(excluding: [])
        checks["metadataAvailable"] = reading.available
        checks["realWindowBounds"] = reading.windows.first(where: { $0.id == rearID })?.frame == rear.frame
        let z = reading.windows.map(\.id)
        checks["frontToBackOrder"] = (z.firstIndex(of: frontID) ?? 999) < (z.firstIndex(of: rearID) ?? 0)
        // Our own windows are intentionally ineligible as surfaces; test their returned bounds
        // with eligibility enabled only inside this independent fixture.
        let testWindows = reading.windows.filter { $0.id == rearID || $0.id == frontID }.map { WindowSnapshot(id: $0.id, frame: $0.frame) }
        let display = NSScreen.screens.first?.frame ?? .zero
        let surfaces = SurfaceGeometry.surfaces(windows: testWindows, display: display, snowHeight: 18)
        checks["realOverlapClipped"] = (surfaces.first(where: { $0.id == rearID })?.visible.reduce(0) { $0 + $1.width } ?? rear.frame.width) < rear.frame.width
        let start = Date()
        rear.setFrameOrigin(NSPoint(x: 140, y: 130))
        pump(0.05); reading = provider.read(excluding: [])
        checks["movingWindowTracks"] = reading.windows.first(where: { $0.id == rearID })?.frame == rear.frame
        checks["trackingSampleUnder150ms"] = Date().timeIntervalSince(start) < 0.15
        rear.setContentSize(NSSize(width: 540, height: 320))
        pump(); reading = provider.read(excluding: [])
        checks["resizedWindowTracks"] = reading.windows.first(where: { $0.id == rearID })?.frame == rear.frame
        front.miniaturize(nil)
        pump(); reading = provider.read(excluding: [])
        checks["minimizedWindowNotOnScreen"] = !reading.windows.contains(where: { $0.id == frontID })
        front.deminiaturize(nil)
        pump(); reading = provider.read(excluding: [])
        checks["restoredWindowReturns"] = reading.windows.contains(where: { $0.id == frontID })
        // Keep only this fixture's windows visible while the app performs its
        // separate foreign-window geometry smoke check.
        if CommandLine.arguments.contains("--hold-for-smoke") { pump(5) }
        rear.close(); front.close()
        pump(); reading = provider.read(excluding: [])
        checks["closedWindowNotOnScreen"] = !reading.windows.contains(where: { $0.id == rearID || $0.id == frontID })
        finish()
    }
}
