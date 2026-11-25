import XCTest
import CoreGraphics
@testable import SnowCore

final class HolidayTreeTests: XCTestCase {
    private let screen = CGSize(width: 1728, height: 1084)
    private func filledGround(_ size: CGSize, maximum: CGFloat = 48) -> SnowProfile {
        var profile = SnowProfile(width: size.width, maximum: maximum)
        for x in stride(from: CGFloat(0), through: size.width, by: 4) { profile.deposit(at: x, amount: 200) }
        return profile
    }
    func testFiveTreesStartWhollyBelowScreenEvenWithDeepSnow() {
        var tree = HolidayTree(seed: 42)
        XCTAssertFalse(tree.isVisible)
        XCTAssertTrue(tree.appearances(in: screen).allSatisfy { $0.opacity == 0 })
        tree.grow(reduceMotion: false)
        let poses = tree.appearances(in: screen, ground: filledGround(screen, maximum: 96))
        XCTAssertTrue(tree.isVisible); XCTAssertEqual(poses.count, 5)
        for pose in poses {
            XCTAssertEqual(pose.opacity, 0)
            XCTAssertLessThan(pose.position.y + HolidayTree.renderBounds.maxY * pose.yScale, 0)
        }
    }
    func testTreesRiseAndSettleAtSmallerSizes() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: false)
        let initial = tree.appearances(in: screen)
        for _ in 0..<30 { tree.step(delta: 1.0 / 60, reduceMotion: false) }
        let middle = tree.appearances(in: screen)
        for index in initial.indices {
            XCTAssertGreaterThan(middle[index].position.y, initial[index].position.y)
            XCTAssertGreaterThan(middle[index].yScale, initial[index].yScale)
        }
        for _ in 0..<60 { tree.step(delta: 1.0 / 60, reduceMotion: false) }
        XCTAssertEqual(tree.growth, 1)
        for pose in tree.appearances(in: screen) {
            XCTAssertEqual(pose.position.y, -HolidayTree.rootInset * pose.yScale, accuracy: 0.001)
            XCTAssertLessThanOrEqual(pose.yScale * HolidayTree.artSize.height, 125)
            XCTAssertEqual(pose.opacity, 1); XCTAssertEqual(pose.lightsOpacity, 1)
        }
    }
    func testFiveSmallTreesSpreadAcrossWholeBottomIncludingCenter() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        let poses = tree.appearances(in: screen)
        XCTAssertEqual(poses.map(\.id), Array(0..<5))
        XCTAssertLessThan(poses[0].position.x, screen.width * 0.2)
        XCTAssertGreaterThan(poses[4].position.x, screen.width * 0.8)
        XCTAssertTrue(poses.contains { (screen.width * 0.35...screen.width * 0.65).contains($0.position.x) })
        XCTAssertEqual(Set(poses.map(\.yScale)).count, 5)
        XCTAssertEqual(poses.map(\.yScale).max()! * HolidayTree.artSize.height, 125, accuracy: 0.001)
    }
    func testGrowthIsStaggeredAndReduceMotionRemovesDelay() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: false)
        for _ in 0..<8 { tree.step(delta: 1.0 / 60, reduceMotion: false) }
        let poses = tree.appearances(in: screen)
        XCTAssertTrue(poses.contains { $0.opacity > 0 })
        XCTAssertTrue(poses.contains { $0.opacity == 0 })
        tree.step(delta: 0, reduceMotion: true)
        XCTAssertTrue(tree.appearances(in: screen).allSatisfy { $0.opacity == 1 && $0.lightsOpacity == 1 })
    }
    func testRepeatAndRemoveResetWholeGroup() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        XCTAssertEqual(tree.growth, 1)
        tree.grow(reduceMotion: false)
        XCTAssertTrue(tree.isVisible); XCTAssertEqual(tree.growth, 0)
        tree.remove(); tree.step(delta: 1, reduceMotion: false)
        XCTAssertFalse(tree.isVisible); XCTAssertEqual(tree.growth, 0)
        XCTAssertTrue(tree.appearances(in: screen).allSatisfy { $0.opacity == 0 })
    }
    func testDelayedOrInvalidFrameDoesNotJumpGrowth() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: false)
        tree.step(delta: 500, reduceMotion: false)
        XCTAssertGreaterThan(tree.growth, 0); XCTAssertLessThan(tree.growth, 0.1)
        let progress = tree.growth
        tree.step(delta: -1, reduceMotion: false); tree.step(delta: .infinity, reduceMotion: false)
        XCTAssertEqual(tree.growth, progress)
    }
    func testTreesStayInsideSmallPortraitAndWideDisplays() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        for size in [CGSize(width: 48, height: 48), CGSize(width: 320, height: 180), CGSize(width: 800, height: 1400), screen, CGSize(width: 5000, height: 2000)] {
            let poses = tree.appearances(in: size)
            XCTAssertEqual(poses.count, 5)
            for pose in poses {
                XCTAssertGreaterThanOrEqual(pose.position.x + HolidayTree.renderBounds.minX * pose.xScale, 0)
                XCTAssertLessThanOrEqual(pose.position.x + HolidayTree.renderBounds.maxX * pose.xScale, size.width)
                XCTAssertLessThanOrEqual(pose.position.y + HolidayTree.renderBounds.maxY * pose.yScale, size.height)
            }
        }
    }
    func testRootsFollowSnowWithoutBuryingWholeTrees() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        let ground = filledGround(screen, maximum: 96)
        for pose in tree.appearances(in: screen, ground: ground) {
            let snow = ground.height(at: pose.position.x)
            XCTAssertLessThan(pose.position.y, snow)
            XCTAssertGreaterThan(pose.position.y + HolidayTree.artSize.height * pose.yScale, snow + 20)
        }
    }
    func testInvalidCanvasIsEmptyAndResizeKeepsStableTreeIDs() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        for size in [CGSize.zero, CGSize(width: -1, height: 600), CGSize(width: CGFloat.nan, height: 600), CGSize(width: 800, height: CGFloat.infinity)] {
            XCTAssertTrue(tree.appearances(in: size).isEmpty)
        }
        let small = tree.appearances(in: CGSize(width: 800, height: 600)), wide = tree.appearances(in: screen)
        XCTAssertEqual(small.map(\.id), wide.map(\.id))
        XCTAssertLessThan(small[0].position.x, wide[0].position.x)
        XCTAssertLessThan(small[4].position.x, wide[4].position.x)
    }
    func testLayoutStaysStillUntilEnabledAgain() {
        var tree = HolidayTree(seed: 42); tree.grow(reduceMotion: true)
        let first = tree.appearances(in: screen)
        for _ in 0..<120 { tree.step(delta: 1.0 / 60, reduceMotion: false) }
        XCTAssertEqual(tree.appearances(in: screen), first)
        tree.remove(); tree.grow(reduceMotion: true)
        XCTAssertNotEqual(tree.appearances(in: screen).map(\.position.x), first.map(\.position.x))
        XCTAssertNotEqual(tree.appearances(in: screen).map(\.yScale), first.map(\.yScale))
    }
    func testSeedReproducesEachEnable() {
        var a = HolidayTree(seed: 17), b = HolidayTree(seed: 17)
        for _ in 0..<8 {
            a.grow(reduceMotion: true); b.grow(reduceMotion: true)
            XCTAssertEqual(a.appearances(in: screen), b.appearances(in: screen))
            a.remove(); b.remove()
        }
    }
    func testPresetLayoutsKeepFiveTreesInsideDisplaysWithoutOverlap() {
        for seed in UInt64(0)..<100 {
            var tree = HolidayTree(seed: seed)
            for _ in 0..<4 {
                tree.grow(reduceMotion: true)
                for size in [CGSize(width: 48, height: 48), CGSize(width: 320, height: 180), CGSize(width: 800, height: 1400), CGSize(width: 1280, height: 96), CGSize(width: 1280, height: 128), screen, CGSize(width: 5000, height: 2000)] {
                    let poses = tree.appearances(in: size)
                    XCTAssertEqual(poses.count, 5)
                    for pose in poses {
                        let left = pose.position.x + HolidayTree.renderBounds.minX * pose.xScale
                        let right = pose.position.x + HolidayTree.renderBounds.maxX * pose.xScale
                        XCTAssertGreaterThanOrEqual(left, 0); XCTAssertLessThanOrEqual(right, size.width)
                        XCTAssertLessThanOrEqual(pose.yScale * HolidayTree.artSize.height, 125)
                        XCTAssertLessThanOrEqual(pose.position.y + HolidayTree.renderBounds.maxY * pose.yScale, size.height)
                    }
                    for index in 1..<poses.count {
                        let previousRight = poses[index - 1].position.x + HolidayTree.renderBounds.maxX * poses[index - 1].xScale
                        let nextLeft = poses[index].position.x + HolidayTree.renderBounds.minX * poses[index].xScale
                        XCTAssertLessThan(previousRight, nextLeft)
                    }
                }
            }
        }
    }
    func testSixLayoutsChangeOnEveryEnableWithoutImmediateRepeat() {
        var tree = HolidayTree(seed: 42)
        var layouts: Set<[CGFloat]> = []
        var previous: [CGFloat]?
        for _ in 0..<120 {
            tree.grow(reduceMotion: true)
            let poses = tree.appearances(in: screen)
            let positions = poses.map(\.position.x)
            XCTAssertNotEqual(positions, previous)
            XCTAssertTrue(poses.contains { (screen.width * 0.35...screen.width * 0.65).contains($0.position.x) })
            layouts.insert(positions); previous = positions
            tree.remove()
        }
        XCTAssertEqual(layouts.count, 6)
    }
}
