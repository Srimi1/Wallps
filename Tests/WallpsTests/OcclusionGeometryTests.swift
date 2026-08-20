import XCTest
@testable import Wallps

/// The AppKit-to-CGWindowList coordinate flip. Getting this wrong silently
/// breaks occlusion detection on multi-display setups — the rects simply stop
/// intersecting — so it is worth pinning down.
final class OcclusionGeometryTests: XCTestCase {
    /// Single display: the primary screen maps onto the origin.
    func testPrimaryScreenMapsToOrigin() {
        let primary = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let flipped = OcclusionDetector.flip(primary, primaryMaxY: primary.maxY)
        XCTAssertEqual(flipped, CGRect(x: 0, y: 0, width: 1470, height: 956))
    }

    /// A display physically above the primary one gets a negative Y in the
    /// flipped space, which is correct and what CGWindowList itself reports.
    func testDisplayAbovePrimaryGetsNegativeY() {
        let primaryMaxY: CGFloat = 956
        let above = CGRect(x: 0, y: 956, width: 1920, height: 1080)
        let flipped = OcclusionDetector.flip(above, primaryMaxY: primaryMaxY)
        XCTAssertEqual(flipped.minY, -1080)
        XCTAssertEqual(flipped.maxY, 0)
    }

    func testDisplayBelowPrimaryGetsPositiveY() {
        let primaryMaxY: CGFloat = 956
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let flipped = OcclusionDetector.flip(below, primaryMaxY: primaryMaxY)
        XCTAssertEqual(flipped.minY, 956)
    }

    /// Horizontal position is unchanged by the flip, including to the left of
    /// the primary display.
    func testHorizontalPositionIsPreserved() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 956)
        let flipped = OcclusionDetector.flip(left, primaryMaxY: 956)
        XCTAssertEqual(flipped.minX, -1920)
        XCTAssertEqual(flipped.minY, 0)
    }

    /// The bug this replaced: pivoting on the tallest point of the whole
    /// arrangement instead of the primary screen shifts the primary display
    /// off by the height of any display stacked above it.
    func testPivotIsPrimaryNotArrangementExtent() {
        let primary = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let arrangementMaxY: CGFloat = 956 + 1080  // a second display sits above
        let correct = OcclusionDetector.flip(primary, primaryMaxY: primary.maxY)
        let buggy = OcclusionDetector.flip(primary, primaryMaxY: arrangementMaxY)
        XCTAssertEqual(correct.minY, 0)
        XCTAssertEqual(buggy.minY, 1080)
        XCTAssertNotEqual(correct, buggy)
    }
}
