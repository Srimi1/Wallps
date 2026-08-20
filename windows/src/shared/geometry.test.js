'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  COVERAGE_THRESHOLD,
  fromWin32Rect,
  intersection,
  coverageFraction,
  covers,
  coveredDisplays,
  toWorkerWClient,
} = require('./geometry');

const FHD = { x: 0, y: 0, width: 1920, height: 1080 };

test('threshold matches OcclusionDetector.coverageThreshold', () => {
  assert.equal(COVERAGE_THRESHOLD, 0.9);
});

test('converts a Win32 RECT', () => {
  assert.deepEqual(fromWin32Rect({ left: -1920, top: -120, right: 0, bottom: 960 }), {
    x: -1920,
    y: -120,
    width: 1920,
    height: 1080,
  });
});

test('non-overlapping rects do not intersect', () => {
  assert.equal(intersection(FHD, { x: 1920, y: 0, width: 1920, height: 1080 }), null);
});

test('rects touching edge-on do not count as intersecting', () => {
  assert.equal(intersection(FHD, { x: 1920, y: 0, width: 10, height: 10 }), null);
});

test('partial overlap is measured correctly', () => {
  const overlap = intersection(FHD, { x: 960, y: 540, width: 1920, height: 1080 });
  assert.deepEqual(overlap, { x: 960, y: 540, width: 960, height: 540 });
  assert.equal(coverageFraction({ x: 960, y: 540, width: 1920, height: 1080 }, FHD), 0.25);
});

test('a maximised window covers its display', () => {
  assert.equal(coverageFraction(FHD, FHD), 1);
  assert.equal(covers(FHD, FHD), true);
});

test('a window on another display does not cover this one', () => {
  const second = { x: 1920, y: 0, width: 1920, height: 1080 };
  assert.equal(covers(second, FHD), false);
});

// A window one pixel short of fullscreen still hides the wallpaper; a
// half-screen window does not. 0.9 is the line.
test('coverage threshold behaves at the boundary', () => {
  const almost = { x: 0, y: 0, width: 1920, height: 972 }; // exactly 0.9
  assert.equal(coverageFraction(almost, FHD), 0.9);
  assert.equal(covers(almost, FHD), true);

  const justUnder = { x: 0, y: 0, width: 1920, height: 971 };
  assert.equal(covers(justUnder, FHD), false);

  const half = { x: 0, y: 0, width: 960, height: 1080 };
  assert.equal(covers(half, FHD), false);
});

test('a zero-area display never counts as covered', () => {
  assert.equal(coverageFraction(FHD, { x: 0, y: 0, width: 0, height: 0 }), 0);
});

test('only the covered display is reported', () => {
  const displays = [
    { key: 'primary', bounds: FHD },
    { key: 'secondary', bounds: { x: 1920, y: 0, width: 2560, height: 1440 } },
  ];
  const maximisedOnSecondary = { x: 1920, y: 0, width: 2560, height: 1440 };
  const result = coveredDisplays(displays, [maximisedOnSecondary]);
  assert.deepEqual([...result], ['secondary']);
});

test('a window spanning both displays covers both', () => {
  const displays = [
    { key: 'primary', bounds: FHD },
    { key: 'secondary', bounds: { x: 1920, y: 0, width: 1920, height: 1080 } },
  ];
  const spanning = { x: 0, y: 0, width: 3840, height: 1080 };
  assert.deepEqual([...coveredDisplays(displays, [spanning])].sort(), ['primary', 'secondary']);
});

test('no windows means nothing is covered', () => {
  assert.equal(coveredDisplays([{ key: 'primary', bounds: FHD }], []).size, 0);
});

// --- WorkerW reparenting -------------------------------------------------
// The bug this pins: after SetParent, coordinates are relative to WorkerW's
// client origin, which is the top-left of the *virtual* desktop — not (0,0).

test('primary display maps to the origin when it is the top-left monitor', () => {
  assert.deepEqual(toWorkerWClient(FHD, { x: 0, y: 0 }), FHD);
});

test('a display left of the primary translates to a positive x', () => {
  const left = { x: -1920, y: 0, width: 1920, height: 1080 };
  const virtualOrigin = { x: -1920, y: 0 };
  assert.deepEqual(toWorkerWClient(left, virtualOrigin), {
    x: 0,
    y: 0,
    width: 1920,
    height: 1080,
  });
  // …and the primary shifts right by the same amount.
  assert.equal(toWorkerWClient(FHD, virtualOrigin).x, 1920);
});

test('a display above the primary translates to a positive y', () => {
  const above = { x: 0, y: -1080, width: 1920, height: 1080 };
  const virtualOrigin = { x: 0, y: -1080 };
  assert.equal(toWorkerWClient(above, virtualOrigin).y, 0);
  assert.equal(toWorkerWClient(FHD, virtualOrigin).y, 1080);
});

test('passing raw virtual-screen coordinates would misplace the window', () => {
  const left = { x: -1920, y: 0, width: 1920, height: 1080 };
  const virtualOrigin = { x: -1920, y: 0 };
  const correct = toWorkerWClient(left, virtualOrigin);
  assert.notEqual(correct.x, left.x, 'translation must actually change the coordinate');
  assert.equal(correct.x, 0);
});

test('translation never changes the size', () => {
  const display = { x: -2560, y: -1440, width: 2560, height: 1440 };
  const translated = toWorkerWClient(display, { x: -2560, y: -1440 });
  assert.equal(translated.width, display.width);
  assert.equal(translated.height, display.height);
});
