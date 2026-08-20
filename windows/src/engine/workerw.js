'use strict';

/**
 * Win32 desktop attachment — the Windows analogue of the `.desktopWindow`
 * NSWindow level used on macOS (Wallps/Engine/WallpaperWindow.swift).
 *
 * macOS has an actual documented window level between the system wallpaper and
 * the desktop icons. Windows has no such thing, so the shell has to be tricked
 * into creating one: sending an undocumented message to `Progman` makes Explorer
 * fork a `WorkerW` window that sits behind the icon layer, and a window
 * reparented into it renders exactly where a wallpaper should.
 *
 * Because the message is undocumented its behaviour differs between Windows
 * builds, so `resolveHost` tries four strategies in order and reports which one
 * worked. That report is the first thing to look at when a machine misbehaves.
 */

const win32 = require('./win32');
const { toWorkerWClient } = require('../shared/geometry');
const { logger } = require('../shared/log');

const log = logger('workerw');

/** wParam/lParam pair that works on current Windows 11 builds. */
const SPAWN_WPARAM_MODERN = 0x0000000d;
const SPAWN_LPARAM_MODERN = 0x00000001;

class DesktopHost {
  constructor() {
    this.hwnd = win32.NULL_HANDLE;
    this.strategy = null;
    /** Every HWND we have reparented, so they can all be restored on quit. */
    this.attached = new Set();
  }

  get isSupported() {
    return win32.available();
  }

  /** True when the cached host window still exists. */
  isAlive() {
    return this.hwnd !== win32.NULL_HANDLE && win32.isWindow(this.hwnd);
  }

  /**
   * Finds the WorkerW that sits *behind* the desktop icons.
   *
   * Explorer's layout after the fork is: a WorkerW that owns `SHELLDLL_DefView`
   * (the icon layer), and immediately after it in Z-order a second, empty
   * WorkerW. That second one is the wallpaper slot.
   */
  findWorkerWBehindIcons() {
    let found = win32.NULL_HANDLE;
    win32.enumWindows((hwnd) => {
      const defView = win32.findWindowEx(hwnd, win32.NULL_HANDLE, 'SHELLDLL_DefView', null);
      if (!defView) return true;
      const sibling = win32.findWindowEx(win32.NULL_HANDLE, hwnd, 'WorkerW', null);
      if (sibling) {
        found = sibling;
        return false; // stop enumerating
      }
      return true;
    });
    return found;
  }

  /**
   * Locates (creating if necessary) the window to reparent wallpaper windows
   * into. Cached, because enumerating every top-level window is not free and
   * this is called on every display change.
   */
  resolveHost({ force = false } = {}) {
    if (!win32.available()) {
      log.warn('Win32 layer unavailable:', win32.unavailableReason());
      return win32.NULL_HANDLE;
    }
    if (!force && this.isAlive()) return this.hwnd;

    const progman = win32.findWindow('Progman', null);
    if (!progman) {
      log.error('Progman not found — the shell is not running as expected');
      this.hwnd = win32.NULL_HANDLE;
      this.strategy = null;
      return win32.NULL_HANDLE;
    }
    log.debug('Progman =', progman);

    // 1. A WorkerW may already exist from a previous run or another app.
    let host = this.findWorkerWBehindIcons();
    let strategy = 'existing-worker-w';

    // 2. Ask the shell to fork one. The modern wParam/lParam pair is what
    //    current Windows 11 builds respond to.
    if (!host) {
      win32.sendMessageTimeout(
        progman,
        win32.WM_SPAWN_WORKER,
        SPAWN_WPARAM_MODERN,
        SPAWN_LPARAM_MODERN
      );
      host = this.findWorkerWBehindIcons();
      strategy = 'spawned-modern';
    }

    // 3. Older Windows 10 builds want the bare form.
    if (!host) {
      win32.sendMessageTimeout(progman, win32.WM_SPAWN_WORKER, 0, 0);
      host = this.findWorkerWBehindIcons();
      strategy = 'spawned-legacy';
    }

    // 4. Some Windows 11 builds keep the WorkerW as a child of Progman rather
    //    than as a top-level sibling, so it never shows up in the enumeration.
    if (!host) {
      host = win32.findWindowEx(progman, win32.NULL_HANDLE, 'WorkerW', null);
      strategy = 'progman-child';
    }

    // 5. Last resort. Parenting to Progman itself still renders behind normal
    //    windows; on some configurations it also hides the desktop icons, which
    //    is worse than no wallpaper — so it is only used when nothing else worked.
    if (!host) {
      host = progman;
      strategy = 'progman-fallback';
      log.warn('Falling back to Progman itself; desktop icons may be hidden');
    }

    this.hwnd = host;
    this.strategy = strategy;
    log.info(`host resolved: hwnd=${host} via ${strategy}`);
    return host;
  }

  /**
   * Reparents a window into the desktop layer and positions it over `bounds`.
   *
   * @param {number} hwnd            native handle of the wallpaper window
   * @param {object} bounds          display rect in **physical pixels**, virtual-screen coords
   * @returns {boolean}              whether the window is now attached
   */
  attach(hwnd, bounds) {
    if (!win32.available() || !hwnd) return false;

    const host = this.resolveHost();
    if (!host) return false;

    win32.setParent(hwnd, host);
    this.applyChildStyles(hwnd);
    this.reposition(hwnd, bounds);
    this.attached.add(hwnd);
    log.info(`attached hwnd=${hwnd} to host=${host}`);
    return true;
  }

  /**
   * `SetParent` alone leaves the window styled as a popup, which makes Windows
   * treat it as a top-level window that happens to have a parent — it can still
   * take focus and appear in Alt-Tab. The style has to be corrected explicitly.
   */
  applyChildStyles(hwnd) {
    const style = win32.getWindowLongPtr(hwnd, win32.GWL_STYLE);
    const childStyle = (((style & ~win32.WS_POPUP) | win32.WS_CHILD) >>> 0);
    win32.setWindowLongPtr(hwnd, win32.GWL_STYLE, childStyle);

    const exStyle = win32.getWindowLongPtr(hwnd, win32.GWL_EXSTYLE);
    const childExStyle =
      (((exStyle | win32.WS_EX_NOACTIVATE | win32.WS_EX_TOOLWINDOW) & ~win32.WS_EX_APPWINDOW) >>> 0);
    win32.setWindowLongPtr(hwnd, win32.GWL_EXSTYLE, childExStyle);
  }

  /**
   * Positions an attached window over a display.
   *
   * After `SetParent` the window's coordinates are relative to WorkerW's client
   * origin, which is the top-left of the *virtual* desktop — negative whenever a
   * monitor sits left of or above the primary one. Passing raw virtual-screen
   * coordinates here is what put the video on the wrong monitor in the previous
   * implementation.
   */
  reposition(hwnd, bounds) {
    if (!win32.available() || !hwnd || !bounds) return false;
    const origin = win32.getVirtualScreenOrigin();
    const client = toWorkerWClient(bounds, origin);
    log.debug(
      `reposition hwnd=${hwnd} bounds=${JSON.stringify(bounds)} ` +
        `origin=${JSON.stringify(origin)} client=${JSON.stringify(client)}`
    );
    return win32.setWindowPos(
      hwnd,
      win32.HWND_BOTTOM,
      client.x,
      client.y,
      client.width,
      client.height,
      win32.SWP_NOACTIVATE | win32.SWP_SHOWWINDOW | win32.SWP_FRAMECHANGED
    );
  }

  /**
   * Restores a window to the normal desktop.
   *
   * Called before closing, so a quit never leaves an orphaned child inside
   * WorkerW — which would survive until the next Explorer restart.
   */
  detach(hwnd) {
    if (!win32.available() || !hwnd) return;
    win32.setParent(hwnd, win32.NULL_HANDLE);
    this.attached.delete(hwnd);
    log.debug(`detached hwnd=${hwnd}`);
  }

  detachAll() {
    for (const hwnd of [...this.attached]) this.detach(hwnd);
  }

  /**
   * Repaints the desktop wallpaper. Without this, quitting can leave the last
   * video frame on screen until something else forces a redraw.
   */
  refreshDesktop() {
    if (!win32.available()) return;
    win32.refreshDesktopWallpaper();
  }

  /** Message Explorer broadcasts after a restart, when WorkerW must be re-found. */
  taskbarCreatedMessage() {
    return win32.registerWindowMessage('TaskbarCreated');
  }

  /** Snapshot for the diagnostics dump. */
  describe() {
    return {
      supported: win32.available(),
      reason: win32.unavailableReason(),
      host: this.hwnd,
      strategy: this.strategy,
      alive: this.isAlive(),
      attachedCount: this.attached.size,
      virtualOrigin: win32.getVirtualScreenOrigin(),
      virtualSize: win32.getVirtualScreenSize(),
    };
  }
}

module.exports = new DesktopHost();
module.exports.DesktopHost = DesktopHost;
