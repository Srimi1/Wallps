'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  makeItem,
  resolutionLabel,
  durationLabel,
  fileSizeLabel,
  needsSoftwareDecode,
  toDisplayModel,
} = require('./wallpaperItem');

// Mirrors WallpaperItemFormattingTests in Tests/WallpsTests/WallpaperLibraryTests.swift.

test('resolution labels', () => {
  assert.equal(resolutionLabel(3840, 2160), '4K');
  assert.equal(resolutionLabel(1920, 1080), '1080p');
  assert.equal(resolutionLabel(640, 480), '640×480');
  assert.equal(resolutionLabel(0, 0), '—');
});

// Portrait 4K is still 4K: the short side is what qualifies it.
test('portrait video is classified by short side', () => {
  assert.equal(resolutionLabel(2160, 3840), '4K');
});

test('duration labels', () => {
  assert.equal(durationLabel(65), '1:05');
  assert.equal(durationLabel(9), '0:09');
  assert.equal(durationLabel(Infinity), '—');
  assert.equal(durationLabel(0), '—');
  assert.equal(durationLabel(NaN), '—');
  assert.equal(durationLabel(3600), '60:00');
});

test('file size labels use decimal units, like ByteCountFormatter .file', () => {
  assert.equal(fileSizeLabel(null), null);
  assert.equal(fileSizeLabel(undefined), null);
  assert.equal(fileSizeLabel(512), '512 bytes');
  assert.equal(fileSizeLabel(52_428_800), '52.4 MB');
  assert.equal(fileSizeLabel(1_500_000_000), '1.5 GB');
});

test('software decode warning only fires on an explicit false', () => {
  assert.equal(needsSoftwareDecode({ hardwareDecodable: false }), true);
  assert.equal(needsSoftwareDecode({ hardwareDecodable: true }), false);
  // Unknown is not a warning — the macOS field is optional for the same reason.
  assert.equal(needsSoftwareDecode({ hardwareDecodable: null }), false);
  assert.equal(needsSoftwareDecode({}), false);
});

test('makeItem fills the same defaults as the Swift model', () => {
  const item = makeItem({ id: 'abc', title: 'T', videoFilename: 'v.mp4' });
  assert.equal(item.thumbnailFilename, null);
  assert.equal(item.duration, 0);
  assert.equal(item.pixelWidth, 0);
  assert.equal(item.source, 'local');
  assert.equal(item.catalogID, null);
  assert.equal(item.hardwareDecodable, null);
  assert.equal(typeof item.dateAdded, 'string');
});

test('display model pre-computes every label', () => {
  const model = toDisplayModel(
    makeItem({
      id: 'abc',
      title: 'T',
      videoFilename: 'v.mp4',
      duration: 65,
      pixelWidth: 3840,
      pixelHeight: 2160,
      fileSize: 52_428_800,
    })
  );
  assert.equal(model.resolutionLabel, '4K');
  assert.equal(model.durationLabel, '1:05');
  assert.equal(model.fileSizeLabel, '52.4 MB');
  assert.equal(model.needsSoftwareDecode, false);
});
