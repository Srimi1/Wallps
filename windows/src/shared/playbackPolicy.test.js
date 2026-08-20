'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { conditions, policy, shouldPlay, pauseReason } = require('./playbackPolicy');

// Mirrors Tests/WallpsTests/PlaybackPolicyTests.swift case for case.
const strict = policy({ pauseOnBattery: true, pauseInLowPowerMode: true, pauseWhenHidden: true });
const lenient = policy({ pauseOnBattery: false, pauseInLowPowerMode: false, pauseWhenHidden: false });

test('plays when nothing blocks', () => {
  assert.equal(shouldPlay(strict, conditions()), true);
});

test('user pause wins over every setting', () => {
  assert.equal(shouldPlay(lenient, conditions({ userPaused: true })), false);
});

// Decoding video behind a locked screen has no upside, so this pause is
// not user-configurable.
test('desktop hidden pauses even with every setting off', () => {
  const c = conditions({ desktopHidden: true });
  assert.equal(shouldPlay(lenient, c), false);
  assert.equal(shouldPlay(strict, c), false);
});

test('battery pauses only when enabled', () => {
  const c = conditions({ onBattery: true });
  assert.equal(shouldPlay(strict, c), false);
  assert.equal(shouldPlay(lenient, c), true);
});

test('low power mode pauses only when enabled', () => {
  const c = conditions({ lowPowerMode: true });
  assert.equal(shouldPlay(strict, c), false);
  assert.equal(shouldPlay(lenient, c), true);
});

test('occlusion pauses only when enabled', () => {
  const c = conditions({ windowOccluded: true });
  assert.equal(shouldPlay(strict, c), false);
  assert.equal(shouldPlay(lenient, c), true);
});

// Every combination of the five inputs against a hand-written oracle: this
// is the whole battery story, so it is worth checking exhaustively.
test('exhaustive against oracle', () => {
  for (let bits = 0; bits < 32; bits++) {
    const c = conditions({
      userPaused: (bits & 1) !== 0,
      onBattery: (bits & 2) !== 0,
      lowPowerMode: (bits & 4) !== 0,
      windowOccluded: (bits & 8) !== 0,
      desktopHidden: (bits & 16) !== 0,
    });

    for (const p of [strict, lenient]) {
      const expected =
        !c.userPaused &&
        !c.desktopHidden &&
        !(p.pauseOnBattery && c.onBattery) &&
        !(p.pauseInLowPowerMode && c.lowPowerMode) &&
        !(p.pauseWhenHidden && c.windowOccluded);
      assert.equal(
        shouldPlay(p, c),
        expected,
        `policy=${JSON.stringify(p)} conditions=${JSON.stringify(c)}`
      );
    }
  }
});

test('defaults match Preferences.swift', () => {
  const p = policy();
  assert.equal(p.pauseOnBattery, true);
  assert.equal(p.pauseInLowPowerMode, true);
  assert.equal(p.pauseWhenHidden, true);
});

// pauseReason mirrors WallpaperEngine.pauseReason, including its precedence.
test('pause reason is null while playing', () => {
  assert.equal(pauseReason(strict, conditions()), null);
});

test('pause reason follows the same precedence as shouldPlay', () => {
  assert.equal(pauseReason(strict, conditions({ userPaused: true })), 'Paused by you');
  assert.equal(pauseReason(strict, conditions({ desktopHidden: true })), 'Desktop not visible');
  assert.equal(pauseReason(strict, conditions({ onBattery: true })), 'On battery');
  assert.equal(pauseReason(strict, conditions({ lowPowerMode: true })), 'Low Power Mode');
  assert.equal(pauseReason(strict, conditions({ windowOccluded: true })), 'Covered by a window');
});

test('pause reason respects the toggles', () => {
  assert.equal(pauseReason(lenient, conditions({ onBattery: true })), null);
  assert.equal(pauseReason(lenient, conditions({ windowOccluded: true })), null);
  // …but the non-configurable one still reports.
  assert.equal(pauseReason(lenient, conditions({ desktopHidden: true })), 'Desktop not visible');
});

test('pause reason never disagrees with shouldPlay', () => {
  for (let bits = 0; bits < 32; bits++) {
    const c = conditions({
      userPaused: (bits & 1) !== 0,
      onBattery: (bits & 2) !== 0,
      lowPowerMode: (bits & 4) !== 0,
      windowOccluded: (bits & 8) !== 0,
      desktopHidden: (bits & 16) !== 0,
    });
    for (const p of [strict, lenient]) {
      assert.equal(
        pauseReason(p, c) === null,
        shouldPlay(p, c),
        `policy=${JSON.stringify(p)} conditions=${JSON.stringify(c)}`
      );
    }
  }
});
