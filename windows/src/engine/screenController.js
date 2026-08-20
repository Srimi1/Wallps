'use strict';

/**
 * Owns the wallpaper window and player for a single display.
 *
 * Port of Wallps/Engine/WallpaperScreenController.swift, split out of the engine
 * for the same reason the Swift side is two files: the per-display window
 * mechanics and the cross-display policy are separate concerns.
 */

const host = require('./workerw');
const protocolModule = require('../main/protocol');
const { logger } = require('../shared/log');

const log = logger('screen');

/** Owns the window and player for a single display. */
class ScreenController {
  constructor({ BrowserWindow, key, display }) {
    this.BrowserWindow = BrowserWindow;
    this.key = key;
    this.display = display;
    this.window = null;
    this.currentItemId = null;
    this.attached = false;
    this.ready = null;
    /** Last state pushed to the page, so redundant play/pause calls are skipped. */
    this.playing = false;
  }

  get isUsable() {
    return this.window && !this.window.isDestroyed();
  }

  /**
   * Creates the wallpaper window.
   *
   * `transparent` is deliberately false — a WS_CHILD of WorkerW cannot
   * composite alpha, and the video covers the whole frame anyway.
   * `backgroundThrottling: false` matters just as much: without it Chromium
   * throttles a window it considers hidden, and this window is always hidden by
   * definition. Pausing is the policy's decision, not the compositor's.
   */
  create() {
    const bounds = this.display.bounds;
    this.window = new this.BrowserWindow({
      x: bounds.x,
      y: bounds.y,
      width: bounds.width,
      height: bounds.height,
      frame: false,
      transparent: false,
      backgroundColor: '#000000',
      show: false,
      focusable: false,
      skipTaskbar: true,
      hasShadow: false,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      thickFrame: false,
      roundedCorners: false,
      acceptFirstMouse: false,
      enableLargerThanScreen: true,
      title: `Wallps wallpaper (${this.key})`,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        backgroundThrottling: false,
        // No preload: the page is driven with executeJavaScript.
        sandbox: true,
      },
    });

    this.window.setIgnoreMouseEvents(true);
    this.window.setMenu?.(null);
    this.ready = this.window.loadURL(protocolModule.uiURL('wallpaper.html'));
    return this.ready;
  }

  /** Native handle, as a JS number matching the `uintptr_t` bindings. */
  nativeHandle() {
    if (!this.isUsable) return 0;
    const buffer = this.window.getNativeWindowHandle();
    if (!buffer || buffer.length < 8) {
      // 32-bit fallback. The original prototype used a `readInt32LE ? … : …`
      // ternary that always chose this branch, truncating every 64-bit handle.
      return buffer && buffer.length >= 4 ? buffer.readUInt32LE(0) : 0;
    }
    return Number(buffer.readBigUInt64LE(0));
  }

  /** Reparents into the desktop layer. Safe to call again after a re-resolve. */
  attach(physicalBounds) {
    if (!this.isUsable) return false;
    const hwnd = this.nativeHandle();
    if (!hwnd) return false;
    this.attached = host.attach(hwnd, physicalBounds);
    if (!this.attached) {
      // Without the desktop layer the window would float over everything, which
      // is far worse than showing nothing.
      log.warn(`could not attach display ${this.key}; leaving it hidden`);
      return false;
    }
    this.window.showInactive();
    return true;
  }

  reposition(physicalBounds) {
    if (!this.isUsable) return;
    if (this.attached) host.reposition(this.nativeHandle(), physicalBounds);
    else this.window.setBounds(this.display.bounds);
  }

  updateDisplay(display, physicalBounds) {
    this.display = display;
    this.reposition(physicalBounds);
  }

  async run(expression) {
    if (!this.isUsable) return null;
    try {
      await this.ready;
      return await this.window.webContents.executeJavaScript(expression, true);
    } catch (error) {
      log.warn(`script failed on ${this.key}:`, error);
      return null;
    }
  }

  setWallpaper({ url, itemId, objectFit, muted, volume }) {
    this.currentItemId = itemId;
    // A fresh <video> starts paused, so the cached state must reset with it.
    this.playing = false;
    return this.run(
      `window.__wallpaper.setSource(${JSON.stringify(url)}, ${JSON.stringify(objectFit)}) &&
       window.__wallpaper.setAudio(${muted}, ${volume})`
    );
  }

  updatePresentation({ objectFit, muted, volume }) {
    return this.run(
      `window.__wallpaper.setObjectFit(${JSON.stringify(objectFit)}) &&
       window.__wallpaper.setAudio(${muted}, ${volume})`
    );
  }

  clear() {
    this.currentItemId = null;
    this.playing = false;
    return this.run('window.__wallpaper.clear()');
  }

  /**
   * Starts or stops playback.
   *
   * Skips the round-trip when nothing changed — this is called on every 2 s
   * conditions poll, and pushing `play()` into a window that is already playing
   * would be constant needless IPC.
   */
  setPlaying(playing) {
    if (this.playing === playing) return null;
    this.playing = playing;
    return this.run(playing ? 'window.__wallpaper.play()' : 'window.__wallpaper.pause()');
  }

  snapshot() {
    return this.run('window.__wallpaper.snapshot()');
  }

  /** Full teardown: restore the window to the desktop, then close it. */
  tearDown() {
    if (!this.isUsable) return;
    const hwnd = this.nativeHandle();
    if (this.attached && hwnd) host.detach(hwnd);
    this.attached = false;
    try {
      this.window.destroy();
    } catch {
      /* already gone */
    }
    this.window = null;
  }
}

module.exports = { ScreenController };
