'use strict';

/**
 * The tray menu's contents, as a plain template.
 *
 * Port of Wallps/UI/MenuBarContent.swift, in the same order: status line, the
 * reason playback is stopped, the pause toggle, the library, the five most
 * recent wallpapers, then the destructive and diagnostic items.
 *
 * Kept free of Electron so it can be unit-tested. On macOS the tray never even
 * gets built — `new Tray` rejects a `.ico` — so without this split the whole
 * menu would be unexercised until it ran on Windows.
 */

/** How many recent wallpapers the menu offers, matching the macOS menu. */
const RECENT_LIMIT = 5;

/**
 * @param {object}   options
 * @param {object}   options.status    from `WallpaperEngine.status()`
 * @param {Array}    options.recent    library display models, newest first
 * @param {object}   options.actions   click handlers
 */
function trayMenuTemplate({ status, recent = [], actions = {} }) {
  const activeIds = new Set(status?.activeItemIds ?? []);
  const hasActive = activeIds.size > 0;
  const template = [{ label: status?.statusDescription ?? 'Starting…', enabled: false }];

  // Only shown when something is actually stopped, so the menu does not carry a
  // permanently greyed-out line.
  if (status?.pauseReason) template.push({ label: status.pauseReason, enabled: false });

  template.push(
    { type: 'separator' },
    {
      label: 'Pause Playback',
      type: 'checkbox',
      checked: Boolean(status?.userPaused),
      enabled: hasActive,
      click: actions.togglePause,
    },
    { label: 'Open Library…', click: actions.openLibrary }
  );

  const items = recent.slice(0, RECENT_LIMIT);
  if (items.length) {
    template.push({ type: 'separator' });
    for (const item of items) {
      template.push({
        label: item.title,
        type: 'checkbox',
        checked: activeIds.has(item.id),
        click: () => actions.applyWallpaper?.(item.id),
      });
    }
  }

  template.push(
    { type: 'separator' },
    { label: 'Clear Wallpaper', enabled: hasActive, click: actions.clearWallpaper },
    { label: 'Copy Diagnostics', click: actions.copyDiagnostics },
    { type: 'separator' },
    { label: 'Quit Wallps', click: actions.quit }
  );

  return template;
}

module.exports = { trayMenuTemplate, RECENT_LIMIT };
