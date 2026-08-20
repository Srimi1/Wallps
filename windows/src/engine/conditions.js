'use strict';

/**
 * Gathers everything `PlaybackPolicy` needs to decide whether a display should
 * be playing.
 *
 * This is three macOS files rolled into one, because on Windows they share a
 * single polling timer:
 *   - Wallps/Engine/OcclusionDetector.swift  → the coverage poll
 *   - Wallps/Engine/PowerMonitor.swift       → AC/battery and Battery Saver
 *   - Wallps/Engine/SystemStateMonitor.swift → lock, screensaver, display sleep
 *
 * Electron's `powerMonitor` is used for everything it exposes; the rest comes
 * from Win32. Like the macOS original, only geometry is read — never window
 * contents — so no screen-capture permission is involved.
 */

const { EventEmitter } = require('node:events');

const win32 = require('./win32');
const { fromWin32Rect, coveredDisplays } = require('../shared/geometry');
const { logger } = require('../shared/log');

const log = logger('conditions');

/** Same cadence as `OcclusionDetector.interval`. */
const POLL_INTERVAL_MS = 2000;

/**
 * Window classes that are desktop furniture rather than something that would
 * actually hide the wallpaper. The direct analogue of
 * `OcclusionDetector.ignoredBundleIDs`.
 */
const IGNORED_CLASSES = new Set([
  'Progman',
  'WorkerW',
  'SHELLDLL_DefView',
  'Shell_TrayWnd',
  'Shell_SecondaryTrayWnd',
  'NotifyIconOverflowWindow',
  'TopLevelWindowForOverflowXamlIsland',
  'Windows.UI.Core.CoreWindow',
  'ApplicationManager_DesktopShellWindow',
  'ForegroundStaging',
  'MultitaskingViewFrame',
  'XamlExplorerHostIslandWindow',
  'Progman_Fallback',
]);

class ConditionsMonitor extends EventEmitter {
  /**
   * @param {object} deps
   * @param {object} deps.screen        Electron `screen` module
   * @param {object} deps.powerMonitor  Electron `powerMonitor` module
   */
  constructor({ screen, powerMonitor }) {
    super();
    this.screen = screen;
    this.powerMonitor = powerMonitor;

    this.onBattery = false;
    this.lowPowerMode = false;
    this.screenLocked = false;
    this.suspended = false;
    this.screensaverActive = false;
    this.fullscreenApp = false;
    /** Display key → covered. */
    this.coveredDisplayKeys = new Set();

    this.timer = null;
    this.listeners = [];
    /** Supplied by the engine: () => [{ key, bounds }] in physical pixels. */
    this.displayProvider = () => [];
  }

  /** Screen locked, screensaver running, or the machine is asleep. */
  get desktopHidden() {
    return this.screenLocked || this.suspended || this.screensaverActive;
  }

  setDisplayProvider(provider) {
    this.displayProvider = provider;
  }

  start() {
    this.bindPowerMonitor();
    this.sample();
    this.timer = setInterval(() => this.sample(), POLL_INTERVAL_MS);
    // Never let the poll hold the process open on quit.
    if (this.timer.unref) this.timer.unref();
    log.info('started');
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    for (const [emitter, event, handler] of this.listeners) {
      emitter.removeListener(event, handler);
    }
    this.listeners = [];
    log.info('stopped');
  }

  bindPowerMonitor() {
    const pm = this.powerMonitor;
    if (!pm) return;

    const bind = (event, handler) => {
      pm.on(event, handler);
      this.listeners.push([pm, event, handler]);
    };

    bind('on-battery', () => this.update({ onBattery: true }));
    bind('on-ac', () => this.update({ onBattery: false }));
    bind('lock-screen', () => this.update({ screenLocked: true }));
    bind('unlock-screen', () => this.update({ screenLocked: false }));
    bind('suspend', () => this.update({ suspended: true }));
    // Re-query rather than trusting event ordering after a wake, the way
    // SystemStateMonitor.refreshDisplaySleep() does on macOS.
    bind('resume', () => {
      this.suspended = false;
      this.sample();
    });
  }

  /** Applies a partial state change. Does not notify — see `update`. */
  applyPatch(patch) {
    let changed = false;
    for (const [key, value] of Object.entries(patch)) {
      if (this[key] !== value) {
        this[key] = value;
        changed = true;
      }
    }
    if (changed) log.debug('changed:', JSON.stringify(patch));
    return changed;
  }

  /** Applies a partial state change and notifies only if something moved. */
  update(patch) {
    const changed = this.applyPatch(patch);
    if (changed) this.emit('changed');
    return changed;
  }

  /**
   * Polls every signal that has no event to hang off.
   *
   * Each sample notifies at most once, however many individual fields moved —
   * otherwise a single poll where the battery, the screensaver and the covered
   * set all changed would drive three separate playback passes.
   */
  sample() {
    let changed = false;

    if (this.powerMonitor) {
      changed = this.applyPatch({ onBattery: this.powerMonitor.isOnBatteryPower() }) || changed;
    }

    const power = win32.getSystemPowerStatus();
    if (power) {
      changed = this.applyPatch({ lowPowerMode: power.batterySaverOn }) || changed;
    }

    changed =
      this.applyPatch({
        screensaverActive: win32.isScreensaverRunning(),
        fullscreenApp: win32.isFullscreenAppRunning(),
      }) || changed;

    changed = this.sampleOcclusion() || changed;

    if (changed) this.emit('changed');
    return changed;
  }

  /**
   * Walks the top-level window list and works out which displays are covered.
   *
   * Mirrors `OcclusionDetector.coveredDisplays`: a window only counts if it is
   * visible, not minimised, not cloaked, not a tool window, not ours, and not
   * desktop furniture.
   */
  sampleOcclusion() {
    const displays = this.displayProvider();
    if (!displays.length) return false;

    // A fullscreen game or presentation hides every desktop at once, and an
    // exclusive-fullscreen window is not always reported with a covering rect.
    if (this.fullscreenApp) {
      return this.replaceCovered(new Set(displays.map((d) => d.key)));
    }

    if (!win32.available()) return false;

    const ownPid = process.pid;
    const rects = [];

    win32.enumWindows((hwnd) => {
      if (!win32.isWindowVisible(hwnd)) return true;
      if (win32.isIconic(hwnd)) return true;
      // Cloaked windows live on another virtual desktop or are suspended UWP
      // apps: still "visible", but covering nothing.
      if (win32.isCloaked(hwnd)) return true;
      if (IGNORED_CLASSES.has(win32.getClassName(hwnd))) return true;

      const exStyle = win32.getWindowLongPtr(hwnd, win32.GWL_EXSTYLE);
      if (exStyle & win32.WS_EX_TOOLWINDOW) return true;

      if (win32.getWindowProcessId(hwnd) === ownPid) return true;

      const raw = win32.getFrameBounds(hwnd);
      if (!raw) return true;
      const rect = fromWin32Rect(raw);
      if (rect.width <= 0 || rect.height <= 0) return true;

      rects.push(rect);
      return true;
    });

    return this.replaceCovered(coveredDisplays(displays, rects));
  }

  /** Does not notify on its own — `sample` emits once for the whole pass. */
  replaceCovered(next) {
    if (setsEqual(next, this.coveredDisplayKeys)) return false;
    this.coveredDisplayKeys = next;
    log.debug('covered displays:', [...next].join(', ') || '(none)');
    return true;
  }

  isCovered(displayKey) {
    return this.coveredDisplayKeys.has(displayKey);
  }

  /** The `PlaybackConditions` for one display. */
  forDisplay(displayKey, { userPaused }) {
    return {
      userPaused,
      onBattery: this.onBattery,
      lowPowerMode: this.lowPowerMode,
      windowOccluded: this.isCovered(displayKey),
      desktopHidden: this.desktopHidden,
    };
  }

  /** Aggregate conditions, for the tray's single pause reason. */
  aggregate({ userPaused, displayKeys }) {
    return {
      userPaused,
      onBattery: this.onBattery,
      lowPowerMode: this.lowPowerMode,
      // Matches WallpaperEngine.pauseReason: the reason only shows when *every*
      // display is covered, not when one window happens to be maximised.
      windowOccluded:
        displayKeys.length > 0 && displayKeys.every((key) => this.isCovered(key)),
      desktopHidden: this.desktopHidden,
    };
  }

  describe() {
    return {
      onBattery: this.onBattery,
      lowPowerMode: this.lowPowerMode,
      screenLocked: this.screenLocked,
      suspended: this.suspended,
      screensaverActive: this.screensaverActive,
      fullscreenApp: this.fullscreenApp,
      desktopHidden: this.desktopHidden,
      covered: [...this.coveredDisplayKeys],
    };
  }
}

function setsEqual(a, b) {
  if (a.size !== b.size) return false;
  for (const value of a) if (!b.has(value)) return false;
  return true;
}

module.exports = { ConditionsMonitor, POLL_INTERVAL_MS, IGNORED_CLASSES };
