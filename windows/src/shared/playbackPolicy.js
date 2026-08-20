'use strict';

/**
 * Everything that can force playback to pause, gathered in one place.
 *
 * Direct port of `PlaybackConditions` in Wallps/Engine/PlaybackPolicy.swift.
 * Field names are kept identical so the two platforms can be diffed by eye.
 */
function conditions(overrides) {
  return {
    userPaused: false,
    onBattery: false,
    lowPowerMode: false,
    /** The wallpaper window for this display is covered by another window. */
    windowOccluded: false,
    /** Screen locked, screensaver running, or displays asleep. */
    desktopHidden: false,
    ...overrides,
  };
}

/**
 * The three user-configurable pause toggles.
 * Port of `PlaybackPolicy` in Wallps/Engine/PlaybackPolicy.swift.
 */
function policy(overrides) {
  return {
    pauseOnBattery: true,
    pauseInLowPowerMode: true,
    pauseWhenHidden: true,
    ...overrides,
  };
}

/**
 * Pure decision logic for whether a wallpaper window should be playing.
 *
 * Kept free of Electron and of any Win32 binding so it is trivially testable —
 * this is the one piece of behaviour users notice on their battery meter.
 */
function shouldPlay(p, c) {
  if (c.userPaused) return false;
  // Never configurable: decoding video nobody can see is pure waste.
  if (c.desktopHidden) return false;
  if (p.pauseOnBattery && c.onBattery) return false;
  if (p.pauseInLowPowerMode && c.lowPowerMode) return false;
  if (p.pauseWhenHidden && c.windowOccluded) return false;
  return true;
}

/**
 * Why playback is currently stopped, for the tray menu. Null when playing.
 *
 * Mirrors `WallpaperEngine.pauseReason` (Wallps/Engine/WallpaperEngine.swift:66-76),
 * including its precedence. The caller decides what `windowOccluded` means in
 * aggregate — on macOS the reason only shows when *every* display is covered.
 */
function pauseReason(p, c) {
  if (c.userPaused) return 'Paused by you';
  if (c.desktopHidden) return 'Desktop not visible';
  if (p.pauseOnBattery && c.onBattery) return 'On battery';
  if (p.pauseInLowPowerMode && c.lowPowerMode) return 'Low Power Mode';
  if (p.pauseWhenHidden && c.windowOccluded) return 'Covered by a window';
  return null;
}

module.exports = { conditions, policy, shouldPlay, pauseReason };
