'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const { SettingsStore, DEFAULTS, GRAVITY_OBJECT_FIT, normalise } = require('./settings');

function withStore(fn) {
  const dir = path.join(os.tmpdir(), `WallpsSettings-${crypto.randomUUID()}`);
  const store = new SettingsStore(path.join(dir, 'settings.json'));
  try {
    return fn(store);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

// Defaults are checked against Wallps/Support/Preferences.swift:76-84 — if the
// two drift, the same app behaves differently on the two platforms.
test('defaults match Preferences.swift', () => {
  assert.equal(DEFAULTS.muted, true);
  assert.equal(DEFAULTS.volume, 0.5);
  assert.equal(DEFAULTS.gravity, 'fill');
  assert.equal(DEFAULTS.pauseOnBattery, true);
  assert.equal(DEFAULTS.pauseInLowPowerMode, true);
  assert.equal(DEFAULTS.pauseWhenHidden, true);
  assert.deepEqual(DEFAULTS.perDisplayWallpaperIDs, {});
  assert.equal(DEFAULTS.defaultWallpaperID, null);
});

// This build ships no bundled catalog, so nothing is fetched until the user
// configures one.
test('no catalog is configured out of the box', () => {
  assert.equal(DEFAULTS.catalogURLString, '');
});

test('gravity maps onto the CSS object-fit values', () => {
  assert.equal(GRAVITY_OBJECT_FIT.fill, 'cover');
  assert.equal(GRAVITY_OBJECT_FIT.fit, 'contain');
  assert.equal(GRAVITY_OBJECT_FIT.stretch, 'fill');
});

test('a missing settings file loads defaults without an error', () => {
  withStore((store) => {
    store.load();
    assert.deepEqual(store.all(), { ...DEFAULTS });
    assert.equal(store.lastError, null);
  });
});

test('round trips through disk', () => {
  withStore((store) => {
    store.update({ muted: false, volume: 0.25, gravity: 'fit' });
    const reloaded = new SettingsStore(store.filePath);
    reloaded.load();
    assert.equal(reloaded.get('muted'), false);
    assert.equal(reloaded.get('volume'), 0.25);
    assert.equal(reloaded.get('gravity'), 'fit');
  });
});

// The file is user-editable, so bad values must never reach the player.
test('hand-edited nonsense falls back to defaults', () => {
  const cleaned = normalise({
    muted: 'yes',
    volume: 'loud',
    gravity: 'sideways',
    pauseOnBattery: 1,
    perDisplayWallpaperIDs: ['not', 'a', 'map'],
    defaultWallpaperID: 42,
  });
  assert.equal(cleaned.muted, true);
  assert.equal(cleaned.volume, 0.5);
  assert.equal(cleaned.gravity, 'fill');
  assert.equal(cleaned.pauseOnBattery, true);
  assert.deepEqual(cleaned.perDisplayWallpaperIDs, {});
  assert.equal(cleaned.defaultWallpaperID, null);
});

test('volume is clamped rather than rejected', () => {
  assert.equal(normalise({ volume: 5 }).volume, 1);
  assert.equal(normalise({ volume: -2 }).volume, 0);
  assert.equal(normalise({ volume: 0.3 }).volume, 0.3);
});

test('a corrupt settings file is reported but not fatal', () => {
  withStore((store) => {
    fs.mkdirSync(path.dirname(store.filePath), { recursive: true });
    fs.writeFileSync(store.filePath, '{ this is not json');
    store.load();
    assert.deepEqual(store.all(), { ...DEFAULTS });
    assert.notEqual(store.lastError, null);
  });
});

test('playbackPolicy exposes exactly the three toggles', () => {
  withStore((store) => {
    store.update({ pauseOnBattery: false, pauseWhenHidden: false });
    assert.deepEqual(store.playbackPolicy, {
      pauseOnBattery: false,
      pauseInLowPowerMode: true,
      pauseWhenHidden: false,
    });
  });
});

// --- Assignment, mirroring WallpaperEngine.assign(_:to:) ------------------

test('assigning to all displays clears per-display choices', () => {
  withStore((store) => {
    store.assignToDisplay('monitor-a', 'item-1');
    store.assignToDisplay('monitor-b', 'item-2');
    store.assignToAllDisplays('item-3');

    assert.equal(store.get('defaultWallpaperID'), 'item-3');
    assert.deepEqual(store.get('perDisplayWallpaperIDs'), {});
    assert.equal(store.wallpaperIdFor('monitor-a'), 'item-3');
  });
});

test('a per-display choice wins over the default', () => {
  withStore((store) => {
    store.assignToAllDisplays('item-default');
    store.assignToDisplay('monitor-a', 'item-a');

    assert.equal(store.wallpaperIdFor('monitor-a'), 'item-a');
    assert.equal(store.wallpaperIdFor('monitor-b'), 'item-default');
  });
});

test('assigning null to a display clears just that display', () => {
  withStore((store) => {
    store.assignToAllDisplays('item-default');
    store.assignToDisplay('monitor-a', 'item-a');
    store.assignToDisplay('monitor-a', null);

    assert.deepEqual(store.get('perDisplayWallpaperIDs'), {});
    assert.equal(store.wallpaperIdFor('monitor-a'), 'item-default');
  });
});

test('clearing all displays leaves nothing assigned', () => {
  withStore((store) => {
    store.assignToAllDisplays('item-1');
    store.assignToAllDisplays(null);
    assert.equal(store.wallpaperIdFor('monitor-a'), null);
  });
});

// Deleting a wallpaper must not leave displays pointing at a file that is gone.
test('forgetting a deleted wallpaper clears every reference to it', () => {
  withStore((store) => {
    store.assignToAllDisplays('doomed');
    store.assignToDisplay('monitor-a', 'doomed');
    store.assignToDisplay('monitor-b', 'survivor');

    store.forgetWallpaper('doomed');

    assert.equal(store.get('defaultWallpaperID'), null);
    assert.deepEqual(store.get('perDisplayWallpaperIDs'), { 'monitor-b': 'survivor' });
  });
});

test('forgetting an unrelated wallpaper changes nothing', () => {
  withStore((store) => {
    store.assignToAllDisplays('keeper');
    store.forgetWallpaper('someone-else');
    assert.equal(store.get('defaultWallpaperID'), 'keeper');
  });
});

test('reset restores every default', () => {
  withStore((store) => {
    store.update({ muted: false, gravity: 'stretch', launchAtLogin: true });
    store.reset();
    assert.deepEqual(store.all(), { ...DEFAULTS });
  });
});
