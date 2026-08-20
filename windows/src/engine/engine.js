'use strict';

/**
 * Owns one desktop-level window per display and keeps playback in line with
 * user settings and system conditions.
 *
 * Port of Wallps/Engine/WallpaperEngine.swift + WallpaperScreenController.swift.
 * The structure is deliberately the same: a controller per display keyed by a
 * stable key, an `applyAssignments` pass that resolves which item each display
 * shows, and a `refreshPlayback` pass that asks the shared policy whether each
 * display should be running.
 */

const { EventEmitter } = require('node:events');

const host = require('./workerw');
const { ScreenController } = require('./screenController');
const win32 = require('./win32');
const { shouldPlay, pauseReason } = require('../shared/playbackPolicy');
const { GRAVITY_OBJECT_FIT } = require('../shared/settings');
const protocolModule = require('../main/protocol');
const { logger } = require('../shared/log');

const log = logger('engine');

class WallpaperEngine extends EventEmitter {
  constructor({ BrowserWindow, screen, powerSaveBlocker, settings, library, conditions }) {
    super();
    this.BrowserWindow = BrowserWindow;
    this.screen = screen;
    this.powerSaveBlocker = powerSaveBlocker;
    this.settings = settings;
    this.library = library;
    this.conditions = conditions;

    /** display key → ScreenController */
    this.controllers = new Map();
    this.userPaused = false;
    this.powerSaveBlockerId = null;
    this.screenListeners = [];
    this.started = false;
    this.lastStatusSignature = null;
  }

  /**
   * Emits `changed` only when the status a listener would observe actually
   * moved.
   *
   * `refreshPlayback` runs on every 2 s conditions poll, and each emit rebuilds
   * the tray menu — which on Windows closes the menu out from under a user who
   * has it open. Nothing downstream cares about a pass that changed nothing.
   */
  emitIfChanged() {
    const signature = JSON.stringify(this.status());
    if (signature === this.lastStatusSignature) return;
    this.lastStatusSignature = signature;
    this.emit('changed');
  }

  // MARK: - Display identity

  /**
   * Stable-ish key for a display.
   *
   * macOS uses the CGDisplay UUID, which survives reboots and hot-plugs
   * (Wallps/Engine/NSScreen+DisplayKey.swift). Electron's `display.id` is the
   * closest thing available without more Win32 work; it holds across a session
   * and usually across reboots, but can change if monitors are reconnected in a
   * different order. Isolated here so it can be upgraded to the EDID-derived
   * device path from `EnumDisplayDevices` without touching anything else.
   */
  displayKeyFor(display) {
    return `display-${display.id}`;
  }

  displayLabel(display) {
    if (display.label && display.label !== 'Unknown') return display.label;
    return `${display.size.width} × ${display.size.height}`;
  }

  /** Display bounds in physical pixels, which is what every Win32 call wants. */
  physicalBounds(display) {
    try {
      const rect = this.screen.dipToScreenRect(null, display.bounds);
      return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    } catch {
      // Fall back to scaling by hand if the conversion is unavailable.
      const scale = display.scaleFactor || 1;
      return {
        x: Math.round(display.bounds.x * scale),
        y: Math.round(display.bounds.y * scale),
        width: Math.round(display.bounds.width * scale),
        height: Math.round(display.bounds.height * scale),
      };
    }
  }

  get connectedDisplays() {
    return this.screen.getAllDisplays().map((display) => ({
      key: this.displayKeyFor(display),
      name: this.displayLabel(display),
      primary: display.id === this.screen.getPrimaryDisplay().id,
    }));
  }

  // MARK: - Lifecycle

  async start() {
    if (this.started) return;
    this.started = true;

    this.conditions.setDisplayProvider(() =>
      this.screen.getAllDisplays().map((display) => ({
        key: this.displayKeyFor(display),
        bounds: this.physicalBounds(display),
      }))
    );
    this.conditions.on('changed', () => this.refreshPlayback());
    this.conditions.start();

    const onDisplayChange = () => this.syncDisplays();
    for (const event of ['display-added', 'display-removed', 'display-metrics-changed']) {
      this.screen.on(event, onDisplayChange);
      this.screenListeners.push([event, onDisplayChange]);
    }

    await this.syncDisplays();
    log.info('started');
  }

  async stop() {
    if (!this.started) return;
    this.started = false;

    this.conditions.stop();
    for (const [event, handler] of this.screenListeners) this.screen.removeListener(event, handler);
    this.screenListeners = [];

    for (const controller of this.controllers.values()) controller.tearDown();
    this.controllers.clear();
    this.releasePowerSaveBlocker();
    host.detachAll();
    host.refreshDesktop();
    log.info('stopped');
  }

  /**
   * Explorer restarting destroys every WorkerW, orphaning our windows.
   * Re-resolving the host and re-attaching is the only way back — macOS has no
   * equivalent failure mode.
   */
  async reattachAll(reason) {
    log.info(`re-attaching all displays (${reason})`);
    host.resolveHost({ force: true });
    for (const controller of this.controllers.values()) {
      controller.attached = false;
      controller.attach(this.physicalBounds(controller.display));
    }
    this.refreshPlayback();
  }

  // MARK: - Displays

  /**
   * Brings the set of controllers in line with the connected displays.
   * Mirrored displays report the same key, so one window is enough.
   */
  async syncDisplays() {
    const seen = new Set();

    for (const display of this.screen.getAllDisplays()) {
      const key = this.displayKeyFor(display);
      if (seen.has(key)) continue;
      seen.add(key);

      const bounds = this.physicalBounds(display);
      const existing = this.controllers.get(key);
      if (existing) {
        existing.updateDisplay(display, bounds);
        continue;
      }

      const controller = new ScreenController({
        BrowserWindow: this.BrowserWindow,
        key,
        display,
      });
      this.controllers.set(key, controller);
      await controller.create();
      controller.attach(bounds);
    }

    for (const [key, controller] of [...this.controllers]) {
      if (seen.has(key)) continue;
      controller.tearDown();
      this.controllers.delete(key);
    }

    await this.applyAssignments();
    this.emitIfChanged();
  }

  // MARK: - Assignment

  async assign(itemId, target) {
    if (target === 'all') this.settings.assignToAllDisplays(itemId);
    else this.settings.assignToDisplay(target, itemId);
    await this.applyAssignments();
  }

  /** Called when an item is deleted from the library. */
  async wallpaperRemoved(itemId) {
    this.settings.forgetWallpaper(itemId);
    await this.applyAssignments();
  }

  async applyAssignments() {
    const primaryKey = this.displayKeyFor(this.screen.getPrimaryDisplay());
    const objectFit = GRAVITY_OBJECT_FIT[this.settings.get('gravity')] ?? 'cover';
    const volume = this.settings.get('volume');

    for (const [key, controller] of this.controllers) {
      const itemId = this.settings.wallpaperIdFor(key);
      const item = itemId ? this.library.item(itemId) : null;

      if (!item) {
        if (controller.currentItemId !== null) await controller.clear();
        continue;
      }

      // Only the primary display plays audio; duplicate soundtracks from
      // several displays are never what anyone wants.
      const muted = this.settings.get('muted') || key !== primaryKey;

      if (controller.currentItemId !== item.id) {
        await controller.setWallpaper({
          url: protocolModule.libraryURL(`Videos/${item.videoFilename}`),
          itemId: item.id,
          objectFit,
          muted,
          volume,
        });
      } else {
        await controller.updatePresentation({ objectFit, muted, volume });
      }
    }

    this.refreshPlayback();
    this.emitIfChanged();
  }

  // MARK: - Playback

  refreshPlayback() {
    const policy = this.settings.playbackPolicy;
    let anyPlaying = false;

    for (const [key, controller] of this.controllers) {
      const conditions = this.conditions.forDisplay(key, { userPaused: this.userPaused });
      const play = controller.currentItemId !== null && shouldPlay(policy, conditions);
      controller.setPlaying(play);
      if (play) anyPlaying = true;
    }

    this.updatePowerSaveBlocker(anyPlaying);
    this.emitIfChanged();
  }

  setUserPaused(paused) {
    this.userPaused = paused;
    this.refreshPlayback();
  }

  toggleUserPaused() {
    this.setUserPaused(!this.userPaused);
    return this.userPaused;
  }

  /**
   * Keeps Windows from suspending the app while a wallpaper is running, without
   * ever preventing display sleep — `prevent-app-suspension` is the analogue of
   * macOS's `beginActivity(.userInitiatedAllowingIdleSystemSleep)`, and
   * deliberately not `prevent-display-sleep`.
   */
  updatePowerSaveBlocker(anyPlaying) {
    if (!this.powerSaveBlocker) return;
    if (anyPlaying && this.powerSaveBlockerId === null) {
      this.powerSaveBlockerId = this.powerSaveBlocker.start('prevent-app-suspension');
    } else if (!anyPlaying) {
      this.releasePowerSaveBlocker();
    }
  }

  releasePowerSaveBlocker() {
    if (this.powerSaveBlockerId === null) return;
    try {
      this.powerSaveBlocker.stop(this.powerSaveBlockerId);
    } catch {
      /* already stopped */
    }
    this.powerSaveBlockerId = null;
  }

  // MARK: - Derived state for the UI

  get activeItemIds() {
    return [...this.controllers.values()]
      .map((controller) => controller.currentItemId)
      .filter((id) => id !== null);
  }

  get hasActiveWallpaper() {
    return this.activeItemIds.length > 0;
  }

  get statusDescription() {
    const ids = [...new Set(this.activeItemIds)];
    if (ids.length === 0) return 'No wallpaper set';
    if (this.userPaused) return 'Paused';
    if (ids.length === 1) {
      const item = this.library.item(ids[0]);
      if (item) return item.title;
    }
    return `${ids.length} wallpapers active`;
  }

  /** Why playback is currently stopped, for the tray. Null when playing. */
  get pauseReason() {
    if (!this.hasActiveWallpaper) return null;
    return pauseReason(
      this.settings.playbackPolicy,
      this.conditions.aggregate({
        userPaused: this.userPaused,
        displayKeys: [...this.controllers.keys()],
      })
    );
  }

  status() {
    return {
      activeItemIds: this.activeItemIds,
      statusDescription: this.statusDescription,
      pauseReason: this.pauseReason,
      userPaused: this.userPaused,
      displays: this.connectedDisplays,
      assignments: {
        default: this.settings.get('defaultWallpaperID'),
        perDisplay: this.settings.get('perDisplayWallpaperIDs'),
      },
    };
  }

  async describe() {
    const snapshots = {};
    for (const [key, controller] of this.controllers) {
      snapshots[key] = {
        itemId: controller.currentItemId,
        attached: controller.attached,
        hwnd: controller.nativeHandle(),
        bounds: this.physicalBounds(controller.display),
        player: await controller.snapshot(),
      };
    }
    return {
      host: host.describe(),
      conditions: this.conditions.describe(),
      userPaused: this.userPaused,
      win32: { available: win32.available(), reason: win32.unavailableReason() },
      displays: snapshots,
    };
  }
}

module.exports = { WallpaperEngine };
