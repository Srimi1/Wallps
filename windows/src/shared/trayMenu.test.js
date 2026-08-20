'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { trayMenuTemplate, RECENT_LIMIT } = require('./trayMenu');

const IDLE = {
  activeItemIds: [],
  statusDescription: 'No wallpaper set',
  pauseReason: null,
  userPaused: false,
  displays: [],
};

const ACTIVE = {
  activeItemIds: ['a1'],
  statusDescription: 'Rainy Night Window',
  pauseReason: null,
  userPaused: false,
  displays: [],
};

const labels = (t) => t.filter((i) => i.label).map((i) => i.label);
const byLabel = (t, label) => t.find((i) => i.label === label);

test('idle menu leads with the status line', () => {
  const template = trayMenuTemplate({ status: IDLE });
  assert.equal(template[0].label, 'No wallpaper set');
  assert.equal(template[0].enabled, false);
});

test('every item is either a separator or has a label', () => {
  const template = trayMenuTemplate({ status: ACTIVE, recent: [{ id: 'a1', title: 'One' }] });
  for (const item of template) {
    assert.ok(item.type === 'separator' || typeof item.label === 'string', JSON.stringify(item));
  }
});

// The reason line would otherwise be a permanently greyed-out empty row.
test('the pause reason only appears when something is stopped', () => {
  assert.ok(!labels(trayMenuTemplate({ status: ACTIVE })).includes('On battery'));
  const paused = trayMenuTemplate({ status: { ...ACTIVE, pauseReason: 'On battery' } });
  assert.equal(paused[1].label, 'On battery');
  assert.equal(paused[1].enabled, false);
});

test('pause and clear are disabled while nothing is active', () => {
  const template = trayMenuTemplate({ status: IDLE });
  assert.equal(byLabel(template, 'Pause Playback').enabled, false);
  assert.equal(byLabel(template, 'Clear Wallpaper').enabled, false);
});

test('pause and clear are enabled once a wallpaper is running', () => {
  const template = trayMenuTemplate({ status: ACTIVE });
  assert.equal(byLabel(template, 'Pause Playback').enabled, true);
  assert.equal(byLabel(template, 'Clear Wallpaper').enabled, true);
});

test('the pause item reflects the paused state', () => {
  const running = byLabel(trayMenuTemplate({ status: ACTIVE }), 'Pause Playback');
  assert.equal(running.checked, false);
  const paused = byLabel(
    trayMenuTemplate({ status: { ...ACTIVE, userPaused: true } }),
    'Pause Playback'
  );
  assert.equal(paused.checked, true);
});

test('recent wallpapers are listed and capped', () => {
  const recent = Array.from({ length: 9 }, (_, i) => ({ id: `id-${i}`, title: `Wallpaper ${i}` }));
  const template = trayMenuTemplate({ status: IDLE, recent });
  const listed = labels(template).filter((l) => l.startsWith('Wallpaper '));
  assert.equal(listed.length, RECENT_LIMIT);
  assert.equal(listed[0], 'Wallpaper 0');
});

test('the active wallpaper is check-marked in the recent list', () => {
  const recent = [
    { id: 'a1', title: 'Active one' },
    { id: 'a2', title: 'Other one' },
  ];
  const template = trayMenuTemplate({ status: ACTIVE, recent });
  assert.equal(byLabel(template, 'Active one').checked, true);
  assert.equal(byLabel(template, 'Other one').checked, false);
});

test('no recent section at all when the library is empty', () => {
  const template = trayMenuTemplate({ status: IDLE, recent: [] });
  // Status, separator, pause, open, separator, clear, diagnostics, separator, quit.
  const separators = template.filter((i) => i.type === 'separator').length;
  assert.equal(separators, 3);
});

test('clicking a recent item applies that id', () => {
  const applied = [];
  const template = trayMenuTemplate({
    status: IDLE,
    recent: [{ id: 'xyz', title: 'Pick me' }],
    actions: { applyWallpaper: (id) => applied.push(id) },
  });
  byLabel(template, 'Pick me').click();
  assert.deepEqual(applied, ['xyz']);
});

test('actions are wired to the right items', () => {
  const calls = [];
  const actions = {
    togglePause: () => calls.push('togglePause'),
    openLibrary: () => calls.push('openLibrary'),
    clearWallpaper: () => calls.push('clear'),
    copyDiagnostics: () => calls.push('diagnostics'),
    quit: () => calls.push('quit'),
  };
  const template = trayMenuTemplate({ status: ACTIVE, actions });
  byLabel(template, 'Pause Playback').click();
  byLabel(template, 'Open Library…').click();
  byLabel(template, 'Clear Wallpaper').click();
  byLabel(template, 'Copy Diagnostics').click();
  byLabel(template, 'Quit Wallps').click();
  assert.deepEqual(calls, ['togglePause', 'openLibrary', 'clear', 'diagnostics', 'quit']);
});

// The menu is built before the engine finishes starting.
test('a missing status does not throw', () => {
  const template = trayMenuTemplate({ status: undefined });
  assert.equal(template[0].label, 'Starting…');
  assert.equal(byLabel(template, 'Pause Playback').enabled, false);
});

test('a recent item with no matching action does not throw when clicked', () => {
  const template = trayMenuTemplate({ status: IDLE, recent: [{ id: 'x', title: 'Lonely' }] });
  assert.doesNotThrow(() => byLabel(template, 'Lonely').click());
});
