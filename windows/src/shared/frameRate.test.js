'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { snapFrameRate, frameRateLabel } = require('./frameRate');

test('snaps a measured rate to the nearest standard one', () => {
  assert.equal(snapFrameRate(60.2), 60);
  assert.equal(snapFrameRate(30.1), 30);
  assert.equal(snapFrameRate(24.05), 24);
  assert.equal(snapFrameRate(120.5), 120);
  assert.equal(snapFrameRate(49.7), 50);
});

// The NTSC rates are real rates, not rounding noise, so a measurement that
// lands nearer 59.94 than 60 should stay there — `frameRateLabel` is what
// turns it back into a readable "60 FPS" for the badge.
test('NTSC rates win when the measurement is genuinely closer to them', () => {
  assert.equal(snapFrameRate(59.87), 59.94);
  assert.equal(snapFrameRate(29.9), 29.97);
  assert.equal(frameRateLabel(snapFrameRate(59.87)), '60 FPS');
});

test('exact standard rates are unchanged', () => {
  assert.equal(snapFrameRate(60), 60);
  assert.equal(snapFrameRate(25), 25);
  assert.equal(snapFrameRate(23.976), 23.976);
});

// A genuinely odd rate should be reported, not forced onto a familiar number.
test('an unusual rate is rounded, not snapped', () => {
  assert.equal(snapFrameRate(37.5), 37.5);
  assert.equal(snapFrameRate(15), 15);
  assert.equal(snapFrameRate(8.333), 8.33);
});

test('nonsense measurements yield null', () => {
  assert.equal(snapFrameRate(null), null);
  assert.equal(snapFrameRate(undefined), null);
  assert.equal(snapFrameRate(0), null);
  assert.equal(snapFrameRate(-30), null);
  assert.equal(snapFrameRate(NaN), null);
  assert.equal(snapFrameRate(Infinity), null);
});

test('labels read the way a badge should', () => {
  assert.equal(frameRateLabel(60), '60 FPS');
  assert.equal(frameRateLabel(23.976), '24 FPS');
  assert.equal(frameRateLabel(29.97), '30 FPS');
  assert.equal(frameRateLabel(37.5), '37.5 FPS');
  assert.equal(frameRateLabel(null), null);
});
