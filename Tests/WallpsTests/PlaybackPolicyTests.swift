import XCTest
@testable import Wallps

final class PlaybackPolicyTests: XCTestCase {
    private let strict = PlaybackPolicy(pauseOnBattery: true, pauseInLowPowerMode: true, pauseWhenHidden: true)
    private let lenient = PlaybackPolicy(pauseOnBattery: false, pauseInLowPowerMode: false, pauseWhenHidden: false)

    func testPlaysWhenNothingBlocks() {
        XCTAssertTrue(strict.shouldPlay(given: PlaybackConditions()))
    }

    func testUserPauseWinsOverEverySetting() {
        var conditions = PlaybackConditions()
        conditions.userPaused = true
        XCTAssertFalse(lenient.shouldPlay(given: conditions))
    }

    /// Decoding video behind a locked screen has no upside, so this pause is
    /// not user-configurable.
    func testDesktopHiddenPausesEvenWithEverySettingOff() {
        var conditions = PlaybackConditions()
        conditions.desktopHidden = true
        XCTAssertFalse(lenient.shouldPlay(given: conditions))
        XCTAssertFalse(strict.shouldPlay(given: conditions))
    }

    func testBatteryPausesOnlyWhenEnabled() {
        var conditions = PlaybackConditions()
        conditions.onBattery = true
        XCTAssertFalse(strict.shouldPlay(given: conditions))
        XCTAssertTrue(lenient.shouldPlay(given: conditions))
    }

    func testLowPowerModePausesOnlyWhenEnabled() {
        var conditions = PlaybackConditions()
        conditions.lowPowerMode = true
        XCTAssertFalse(strict.shouldPlay(given: conditions))
        XCTAssertTrue(lenient.shouldPlay(given: conditions))
    }

    func testOcclusionPausesOnlyWhenEnabled() {
        var conditions = PlaybackConditions()
        conditions.windowOccluded = true
        XCTAssertFalse(strict.shouldPlay(given: conditions))
        XCTAssertTrue(lenient.shouldPlay(given: conditions))
    }

    /// Every combination of the five inputs against a hand-written oracle: this
    /// is the whole battery story, so it is worth checking exhaustively.
    func testExhaustiveAgainstOracle() {
        for bits in 0..<32 {
            var conditions = PlaybackConditions()
            conditions.userPaused = bits & 1 != 0
            conditions.onBattery = bits & 2 != 0
            conditions.lowPowerMode = bits & 4 != 0
            conditions.windowOccluded = bits & 8 != 0
            conditions.desktopHidden = bits & 16 != 0

            for policy in [strict, lenient] {
                let expected = !conditions.userPaused
                    && !conditions.desktopHidden
                    && !(policy.pauseOnBattery && conditions.onBattery)
                    && !(policy.pauseInLowPowerMode && conditions.lowPowerMode)
                    && !(policy.pauseWhenHidden && conditions.windowOccluded)
                XCTAssertEqual(
                    policy.shouldPlay(given: conditions), expected,
                    "policy=\(policy) conditions=\(conditions)"
                )
            }
        }
    }
}
