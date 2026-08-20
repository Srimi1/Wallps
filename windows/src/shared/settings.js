'use strict';

/**
 * User settings.
 *
 * Port of Wallps/Support/Preferences.swift. macOS uses `UserDefaults`; there is
 * no Windows equivalent worth using, so this is a small JSON file next to the
 * library. The key names and defaults are deliberately identical to the Swift
 * side, so the two platforms can be compared without a translation table.
 *
 * Every value is coerced on read: this file is user-editable, and a hand-edited
 * `volume: "loud"` should fall back to the default rather than reach the player.
 */

const fs = require('node:fs');
const path = require('node:path');

const GRAVITIES = ['fill', 'fit', 'stretch'];

/**
 * How the video is scaled inside each screen — the CSS equivalents of
 * `AVLayerVideoGravity`.
 */
const GRAVITY_OBJECT_FIT = {
  fill: 'cover',
  fit: 'contain',
  stretch: 'fill',
};

const GRAVITY_LABELS = {
  fill: 'Fill',
  fit: 'Fit',
  stretch: 'Stretch',
};

const DEFAULTS = Object.freeze({
  muted: true,
  volume: 0.5,
  gravity: 'fill',
  pauseOnBattery: true,
  pauseInLowPowerMode: true,
  pauseWhenHidden: true,
  /**
   * Empty by default: this build ships no bundled catalog, so the gallery stays
   * empty until the user points it at a `catalog.json` they host. See
   * docs/CATALOG.md for the format.
   */
  catalogURLString: '',
  /** Wallpaper used for any display without an explicit per-display choice. */
  defaultWallpaperID: null,
  /** Stable display key → wallpaper item id. */
  perDisplayWallpaperIDs: {},
  /**
   * Windows-only. macOS keeps this in the Login Items database via
   * SMAppService; on Windows it is a registry entry that Electron manages, and
   * the desired state has to be remembered somewhere.
   */
  launchAtLogin: false,
});

function coerceBool(value, fallback) {
  return typeof value === 'boolean' ? value : fallback;
}

function coerceVolume(value, fallback) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.min(1, Math.max(0, value));
}

function coerceGravity(value, fallback) {
  return GRAVITIES.includes(value) ? value : fallback;
}

function coerceString(value, fallback) {
  return typeof value === 'string' ? value : fallback;
}

function coerceNullableString(value) {
  return typeof value === 'string' && value.length ? value : null;
}

function coerceMap(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const out = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof key === 'string' && typeof entry === 'string' && entry.length) out[key] = entry;
  }
  return out;
}

/** Applies every coercion, so the rest of the app never sees a bad value. */
function normalise(raw) {
  const input = raw && typeof raw === 'object' ? raw : {};
  return {
    muted: coerceBool(input.muted, DEFAULTS.muted),
    volume: coerceVolume(input.volume, DEFAULTS.volume),
    gravity: coerceGravity(input.gravity, DEFAULTS.gravity),
    pauseOnBattery: coerceBool(input.pauseOnBattery, DEFAULTS.pauseOnBattery),
    pauseInLowPowerMode: coerceBool(input.pauseInLowPowerMode, DEFAULTS.pauseInLowPowerMode),
    pauseWhenHidden: coerceBool(input.pauseWhenHidden, DEFAULTS.pauseWhenHidden),
    catalogURLString: coerceString(input.catalogURLString, DEFAULTS.catalogURLString),
    defaultWallpaperID: coerceNullableString(input.defaultWallpaperID),
    perDisplayWallpaperIDs: coerceMap(input.perDisplayWallpaperIDs),
    launchAtLogin: coerceBool(input.launchAtLogin, DEFAULTS.launchAtLogin),
  };
}

class SettingsStore {
  constructor(filePath) {
    this.filePath = filePath;
    this.values = { ...DEFAULTS };
    this.lastError = null;
  }

  load() {
    try {
      this.values = normalise(JSON.parse(fs.readFileSync(this.filePath, 'utf8')));
    } catch (error) {
      // A missing or corrupt file is not worth bothering the user about — the
      // defaults are all reasonable.
      if (error.code !== 'ENOENT') this.lastError = error.message;
      this.values = { ...DEFAULTS };
    }
    return this.values;
  }

  save() {
    try {
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
      const tmp = `${this.filePath}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(this.values, null, 2), 'utf8');
      fs.renameSync(tmp, this.filePath);
    } catch (error) {
      this.lastError = `Couldn't save settings: ${error.message}`;
    }
  }

  get(key) {
    return this.values[key];
  }

  /** Applies a partial update, coercing the result, and persists it. */
  update(patch) {
    this.values = normalise({ ...this.values, ...patch });
    this.save();
    return this.values;
  }

  all() {
    return { ...this.values };
  }

  reset() {
    this.values = { ...DEFAULTS };
    this.save();
    return this.values;
  }

  /** The three toggles `PlaybackPolicy` needs. */
  get playbackPolicy() {
    return {
      pauseOnBattery: this.values.pauseOnBattery,
      pauseInLowPowerMode: this.values.pauseInLowPowerMode,
      pauseWhenHidden: this.values.pauseWhenHidden,
    };
  }

  get objectFit() {
    return GRAVITY_OBJECT_FIT[this.values.gravity] ?? 'cover';
  }

  // --- Assignment, mirroring WallpaperEngine.assign(_:to:) ----------------

  /**
   * Assigning to every display also clears the per-display map, so a later
   * "all displays" choice is not silently overridden by a stale per-display one.
   */
  assignToAllDisplays(itemId) {
    return this.update({ defaultWallpaperID: itemId ?? null, perDisplayWallpaperIDs: {} });
  }

  assignToDisplay(displayKey, itemId) {
    const map = { ...this.values.perDisplayWallpaperIDs };
    if (itemId) map[displayKey] = itemId;
    else delete map[displayKey];
    return this.update({ perDisplayWallpaperIDs: map });
  }

  /** The item a display should show, falling back to the default. */
  wallpaperIdFor(displayKey) {
    return this.values.perDisplayWallpaperIDs[displayKey] ?? this.values.defaultWallpaperID ?? null;
  }

  /** Called when an item is deleted from the library. */
  forgetWallpaper(itemId) {
    const map = Object.fromEntries(
      Object.entries(this.values.perDisplayWallpaperIDs).filter(([, id]) => id !== itemId)
    );
    return this.update({
      defaultWallpaperID: this.values.defaultWallpaperID === itemId ? null : this.values.defaultWallpaperID,
      perDisplayWallpaperIDs: map,
    });
  }
}

module.exports = {
  SettingsStore,
  DEFAULTS,
  GRAVITIES,
  GRAVITY_OBJECT_FIT,
  GRAVITY_LABELS,
  normalise,
};
