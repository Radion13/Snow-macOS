import XCTest
import CoreGraphics
@testable import SnowCore

final class SnowmanVariantTests: XCTestCase {
    private let surface = SnowSurface(id: 7, frame: CGRect(x: 0, y: -600, width: 800, height: 600), visible: [.init(0, 800)])
    private func stack(firstID: UInt64 = 1, x: CGFloat = 200) -> [Snowball] {
        var top: CGFloat = 0
        return [CGFloat(33), 22, 14].enumerated().map { index, radius in
            var ball = Snowball(id: firstID + UInt64(index), radius: radius, position: CGPoint(x: x, y: top + radius))
            ball.surfaceID = surface.id; ball.localX = x; ball.anchorHeight = top + radius
            ball.supportID = index == 0 ? nil : ball.id - 1
            top += radius * 2
            return ball
        }
    }
    func testFourVariantsCycleWithoutConsecutiveRepeats() {
        let cycle = SnowmanVariantCycle()
        XCTAssertEqual((0..<8).map { _ in cycle.next() }, SnowmanVariant.allCases + SnowmanVariant.allCases)
    }
    func testSeparateDisplaysShareOneCycle() {
        let cycle = SnowmanVariantCycle()
        let variants = (0..<5).compactMap { index in
            SnowGame(balls: stack(firstID: UInt64(index * 10 + 1)), variantCycle: cycle).snowmanVariants().values.first
        }
        XCTAssertEqual(variants, SnowmanVariant.allCases + [.festive])
    }
    func testIncompleteStacksDoNotConsumeAStyle() {
        let cycle = SnowmanVariantCycle()
        let incomplete = SnowGame(balls: Array(stack().prefix(2)), variantCycle: cycle)
        XCTAssertTrue(incomplete.snowmanVariants().isEmpty)
        let complete = SnowGame(balls: stack(), variantCycle: cycle)
        XCTAssertEqual(complete.snowmanVariants()[3], .festive)
    }
    func testRedrawAndMovingWindowPreserveVariant() {
        let cycle = SnowmanVariantCycle()
        let game = SnowGame(balls: stack(), variantCycle: cycle)
        let original = game.snowmanVariants()
        for _ in 0..<20 { XCTAssertEqual(game.snowmanVariants(), original) }
        var moved = surface; moved.frame = moved.frame.offsetBy(dx: 60, dy: 20)
        game.step(delta: 0, surfaces: [moved], profiles: [:], size: CGSize(width: 1200, height: 900))
        XCTAssertEqual(game.snowmanVariants(), original)
        XCTAssertEqual(cycle.next(), .winterBroom)
    }
    func testReassemblingTheSameBallsGetsTheNextVariant() {
        let game = SnowGame(balls: stack(), variantCycle: SnowmanVariantCycle())
        XCTAssertEqual(game.snowmanVariants()[3], .festive)
        let head = game.balls[2]
        var profiles = [surface.id: SnowProfile(width: 800, maximum: 48)]
        game.begin(at: head.position, surfaces: [surface], profiles: profiles)
        game.drag(to: head.position, surfaces: [surface], profiles: &profiles)
        game.endDrag(surfaces: [surface], profiles: profiles)
        XCTAssertEqual(game.snowmen, [[1, 2, 3]])
        XCTAssertEqual(game.snowmanVariants()[3], .winterBroom)
    }
    func testDisplayTransferCarriesTheAssignedVariant() {
        let source = SnowGame(balls: stack(), variantCycle: SnowmanVariantCycle(start: 1))
        let target = SnowGame(variantCycle: SnowmanVariantCycle(start: 3))
        XCTAssertEqual(source.snowmanVariants()[3], .winterBroom)
        XCTAssertTrue(source.transfer(on: surface.id, to: target) { _ in true })
        XCTAssertTrue(source.snowmanVariants().isEmpty)
        XCTAssertEqual(target.snowmanVariants()[3], .winterBroom)
    }
    func testClearingSnowDoesNotRestartTheCycle() {
        let cycle = SnowmanVariantCycle()
        let first = SnowGame(balls: stack(), variantCycle: cycle)
        XCTAssertEqual(first.snowmanVariants()[3], .festive)
        first.clear(); XCTAssertTrue(first.snowmanVariants().isEmpty)
        let next = SnowGame(balls: stack(firstID: 10), variantCycle: cycle)
        XCTAssertEqual(next.snowmanVariants()[12], .winterBroom)
    }
    func testSettingsPreviewHasAnIndependentCycle() {
        let cycle = SnowmanVariantCycle()
        let first = SnowGame(balls: stack(), variantCycle: cycle)
        XCTAssertEqual(first.snowmanVariants()[3], .festive)
        let preview = SnowGame(balls: stack(), variantCycle: SnowmanVariantCycle(start: 2))
        XCTAssertEqual(preview.snowmanVariants()[3], .classicBucket)
        let next = SnowGame(balls: stack(firstID: 20), variantCycle: cycle)
        XCTAssertEqual(next.snowmanVariants()[22], .winterBroom)
    }
}
