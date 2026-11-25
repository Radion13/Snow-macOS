import XCTest
import CoreGraphics
@testable import SnowCore

final class WindowCornerTests: XCTestCase {
    private let surface = SnowSurface(id: 7, frame: CGRect(x: 80, y: 100, width: 400, height: 200), visible: [.init(0, 400)])
    private func filled() -> SnowProfile {
        var p = SnowProfile(width: 400, maximum: 18, variationSeed: 42, roundedEdges: true)
        for x in stride(from: CGFloat(0), through: 400, by: 4) { p.deposit(at: x, amount: 100) }
        return p
    }
    func testWindowSurfaceFollowsBothCornersAndCoordinatesRoundTrip() {
        XCTAssertEqual(surface.point(at: 0).y, surface.baseline - 24)
        XCTAssertEqual(surface.point(at: 24).y, surface.baseline)
        XCTAssertEqual(surface.point(at: 200).y, surface.baseline)
        for x: CGFloat in [0, 0.5, 2, 8, 16, 24, 200, 376, 392, 400] {
            XCTAssertEqual(surface.baseOffset(at: x), surface.baseOffset(at: 400 - x), accuracy: 0.000001)
            let point = surface.point(at: x, height: 9)
            let local = surface.coordinates(of: point)
            XCTAssertEqual(local.x, x, accuracy: 0.000001); XCTAssertEqual(local.y, 9, accuracy: 0.000001)
        }
    }
    func testSnowWrapsCornerInsteadOfLeavingAnAirborneShelf() {
        let p = filled(), path = SnowContour.path(surface: surface, profile: filled(), span: .init(0, 400))
        for x: CGFloat in [0.25, 0.5, 1] {
            XCTAssertFalse(path.contains(CGPoint(x: surface.frame.minX + x, y: surface.baseline + 0.2)), "The old triangular shelf must be empty")
        }
        for x: CGFloat in [4, 8, 392, 396] {
            XCTAssertTrue(path.contains(surface.point(at: x, height: p.height(at: x) * 0.5)), "Snow should hug the rounded base")
        }
        XCTAssertEqual(path.boundingBox.minX, surface.frame.minX, accuracy: 0.001)
        XCTAssertEqual(path.boundingBox.maxX, surface.frame.maxX, accuracy: 0.001)
        XCTAssertEqual(path.boundingBox.minY, surface.baseline - 24, accuracy: 0.001)
    }
    func testPhysicalEndStartsWithVerticalTangentRatherThanDiagonalPoint() {
        let path = SnowContour.path(surface: surface, profile: filled(), span: .init(0, 400))
        var start: CGPoint?, control: CGPoint?
        path.applyWithBlock { element in
            if start == nil && element.pointee.type == .moveToPoint { start = element.pointee.points[0] }
            if control == nil && element.pointee.type == .addCurveToPoint { control = element.pointee.points[0] }
        }
        XCTAssertNotNil(start); XCTAssertNotNil(control)
        XCTAssertEqual(start!.x, control!.x, accuracy: 0.000001)
        XCTAssertGreaterThan(control!.y, start!.y)
    }
    func testEmptySnowDoesNotPaintPhantomCornerFillets() {
        let p = SnowProfile(width: 400, maximum: 18, roundedEdges: true)
        let path = SnowContour.path(surface: surface, profile: p, span: .init(0, 400))
        XCTAssertTrue(path.isEmpty)
        for x in 0..<24 {
            for y in -24..<0 {
                XCTAssertFalse(path.contains(CGPoint(x: surface.frame.minX + CGFloat(x) + 0.17,
                                                     y: surface.baseline + CGFloat(y) + 0.23)))
            }
        }
    }
    func testVisibilityCutDoesNotGrowPastItsBoundaryOrRoundAnOcclusion() {
        let path = SnowContour.path(surface: surface, profile: filled(), span: .init(10, 300))
        XCTAssertEqual(path.boundingBox.minX, surface.frame.minX + 10, accuracy: 0.001)
        XCTAssertEqual(path.boundingBox.maxX, surface.frame.minX + 300, accuracy: 0.001)
        XCTAssertFalse(path.contains(CGPoint(x: surface.frame.minX + 9, y: surface.baseline)))
        let middle = SnowContour.path(surface: surface, profile: filled(), span: .init(70, 290))
        XCTAssertEqual(middle.boundingBox.minY, surface.baseline, accuracy: 0.001)
    }
    func testFloorAndDockKeepFlatBases() {
        for s in [SnowSurface(id: 1, frame: surface.frame, visible: [.init(0, 400)], isBottom: true),
                  SnowSurface(id: 2, frame: surface.frame, visible: [.init(0, 400)], kind: .dock)] {
            XCTAssertEqual(s.cornerRadius, 0)
            for x: CGFloat in [0, 4, 24, 200, 400] { XCTAssertEqual(s.point(at: x).y, s.baseline) }
        }
    }
    func testVerticalDockStillDrawsSnowOnBothSides() {
        let p = filled()
        for orientation: SurfaceOrientation in [.leftEdge, .rightEdge] {
            let s = SnowSurface(id: 2, frame: CGRect(x: 100, y: 50, width: 60, height: 400),
                                visible: [.init(0, 400)], kind: .dock, orientation: orientation)
            let path = SnowContour.path(surface: s, profile: p, span: .init(0, 400))
            XCTAssertEqual(s.cornerRadius, 0)
            XCTAssertFalse(path.isEmpty)
            XCTAssertTrue(path.contains(s.point(at: 200, height: p.height(at: 200) / 2)))
            let empty = SnowProfile(width: 400, maximum: 18)
            XCTAssertTrue(SnowContour.path(surface: s, profile: empty, span: .init(0, 400)).isEmpty)
        }
    }
    func testBallLandsOnWrappedSnowAndFollowsItsWindow() {
        let p = filled(), x: CGFloat = 8
        let game = SnowGame(balls: [.init(id: 820_001, radius: 6, position: CGPoint(x: surface.frame.minX + x, y: surface.baseline + 80))])
        for _ in 0..<180 { game.step(delta: 1.0 / 60, surfaces: [surface], profiles: [surface.id: p], size: CGSize(width: 800, height: 600)) }
        XCTAssertEqual(game.balls.count, 1); XCTAssertEqual(game.balls[0].surfaceID, surface.id)
        XCTAssertEqual(game.balls[0].position.y - 6, surface.point(at: x, height: p.height(at: x)).y, accuracy: 0.001)
        let original = game.balls[0].position
        var moved = surface; moved.frame = moved.frame.offsetBy(dx: 30, dy: 40)
        game.step(delta: 0, surfaces: [moved], profiles: [surface.id: p], size: CGSize(width: 800, height: 600))
        XCTAssertEqual(game.balls[0].position.x, original.x + 30, accuracy: 0.001)
        XCTAssertEqual(game.balls[0].position.y, original.y + 40, accuracy: 0.001)
    }
    func testLowerFrontWindowClipsOnlyWrappedCorners() {
        let rear = WindowSnapshot(id: 7, frame: surface.frame)
        let front = WindowSnapshot(id: 8, frame: CGRect(x: 80, y: 200, width: 120, height: 88))
        let result = SurfaceGeometry.surfaces(windows: [front, rear], display: CGRect(x: 0, y: 0, width: 800, height: 600), snowHeight: 18)
        let cap = result.first { $0.id == rear.id }!
        XCTAssertFalse(cap.visible.contains { $0.contains(4) })
        XCTAssertTrue(cap.visible.contains { $0.contains(100) }, "The middle is above the lower front window")
        XCTAssertTrue(cap.visible.contains { $0.contains(396) })
    }
}
