'use strict';

/**
 * Rectangle maths for occlusion detection and for reparenting into WorkerW.
 *
 * Getting either wrong silently breaks the app on multi-display setups — the
 * rects simply stop intersecting, or the video lands on the wrong monitor — so
 * this is kept pure and pinned by tests, the way
 * Tests/WallpsTests/OcclusionGeometryTests.swift pins the macOS side.
 *
 * Rects here are `{ x, y, width, height }` in **physical pixels**, in Windows
 * virtual-screen coordinates: the primary display's top-left is (0, 0) and
 * monitors placed left of or above it have negative coordinates.
 *
 * Note there is no coordinate *flip* on Windows. macOS needs one because AppKit
 * is bottom-left origin while CGWindowList is top-left; Win32 is top-left origin
 * throughout. What Windows needs instead is the virtual-screen translation in
 * `toWorkerWClient` below.
 */

/**
 * Fraction of a display a window must cover to count as hiding the wallpaper.
 * Same value as `OcclusionDetector.coverageThreshold`.
 */
const COVERAGE_THRESHOLD = 0.9;

/** Converts a Win32 `RECT` (left/top/right/bottom) into an `{x,y,width,height}` rect. */
function fromWin32Rect(r) {
  return { x: r.left, y: r.top, width: r.right - r.left, height: r.bottom - r.top };
}

function area(rect) {
  return Math.max(0, rect.width) * Math.max(0, rect.height);
}

/** Overlapping region of two rects, or null when they do not intersect. */
function intersection(a, b) {
  const x = Math.max(a.x, b.x);
  const y = Math.max(a.y, b.y);
  const right = Math.min(a.x + a.width, b.x + b.width);
  const bottom = Math.min(a.y + a.height, b.y + b.height);
  if (right <= x || bottom <= y) return null;
  return { x, y, width: right - x, height: bottom - y };
}

/** How much of `screen` the `window` rect covers, 0…1. */
function coverageFraction(windowRect, screenRect) {
  const screenArea = area(screenRect);
  if (screenArea <= 0) return 0;
  const overlap = intersection(windowRect, screenRect);
  if (!overlap) return 0;
  return area(overlap) / screenArea;
}

/** True when `windowRect` hides essentially all of `screenRect`. */
function covers(windowRect, screenRect, threshold = COVERAGE_THRESHOLD) {
  return coverageFraction(windowRect, screenRect) >= threshold;
}

/**
 * Which displays are covered by at least one of the given windows.
 *
 * Mirrors `OcclusionDetector.coveredDisplays(screens:ignoredPIDs:)` — the
 * caller is responsible for having already filtered out invisible, minimised,
 * cloaked, tool and shell windows, exactly as the macOS version filters on
 * layer, alpha and PID before calling in here.
 *
 * @param {Array<{key: string, bounds: object}>} displays
 * @param {Array<object>} windowRects
 * @returns {Set<string>} keys of covered displays
 */
function coveredDisplays(displays, windowRects, threshold = COVERAGE_THRESHOLD) {
  const covered = new Set();
  for (const rect of windowRects) {
    for (const display of displays) {
      if (covered.has(display.key)) continue;
      if (covers(rect, display.bounds, threshold)) covered.add(display.key);
    }
  }
  return covered;
}

/**
 * Translates a display rect from virtual-screen coordinates into the client
 * coordinates of the WorkerW window.
 *
 * WorkerW spans the whole virtual desktop, and its client origin is the
 * top-left of that desktop — `SM_XVIRTUALSCREEN` / `SM_YVIRTUALSCREEN`, which
 * are negative whenever a monitor sits left of or above the primary one. After
 * `SetParent` our window's coordinates become relative to that origin, so
 * passing raw virtual-screen coordinates to `SetWindowPos` puts the video on
 * the wrong monitor. This is the translation the original prototype omitted.
 */
function toWorkerWClient(displayRect, virtualOrigin) {
  return {
    x: displayRect.x - virtualOrigin.x,
    y: displayRect.y - virtualOrigin.y,
    width: displayRect.width,
    height: displayRect.height,
  };
}

module.exports = {
  COVERAGE_THRESHOLD,
  fromWin32Rect,
  area,
  intersection,
  coverageFraction,
  covers,
  coveredDisplays,
  toWorkerWClient,
};
