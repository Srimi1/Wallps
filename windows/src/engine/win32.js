'use strict';

/**
 * Thin koffi bindings over the Win32 calls the wallpaper engine needs.
 *
 * This replaces the previous approach of shelling out to `powershell -Command`
 * with an inline `Add-Type` P/Invoke, which could not work: the payload was a
 * here-string flattened onto one line, and every failure was swallowed by a
 * `console.warn`.
 *
 * Everything here is guarded so the module is safe to `require` on macOS during
 * development — `isSupported` is false and every call is a no-op. Only x64 and
 * arm64 are targeted, so calling conventions are left unspecified: `__stdcall`
 * is only meaningful on 32-bit x86, which we do not ship.
 *
 * Handles are typed `uintptr_t`, which koffi returns as a plain JS number.
 * Window handles fit comfortably inside the 53-bit safe-integer range.
 */

const NULL_HANDLE = 0;

// --- Constants -----------------------------------------------------------

/** Undocumented Progman message that forks a WorkerW behind the desktop icons. */
const WM_SPAWN_WORKER = 0x052c;
const SMTO_NORMAL = 0x0000;

const GWL_STYLE = -16;
const GWL_EXSTYLE = -20;

const WS_CHILD = 0x40000000;
const WS_POPUP = 0x80000000;
const WS_VISIBLE = 0x10000000;

const WS_EX_NOACTIVATE = 0x08000000;
const WS_EX_TOOLWINDOW = 0x00000080;
const WS_EX_LAYERED = 0x00080000;
const WS_EX_APPWINDOW = 0x00040000;

const HWND_BOTTOM = 1;
const SWP_NOACTIVATE = 0x0010;
const SWP_SHOWWINDOW = 0x0040;
const SWP_FRAMECHANGED = 0x0020;
const SWP_NOZORDER = 0x0004;

const SM_XVIRTUALSCREEN = 76;
const SM_YVIRTUALSCREEN = 77;
const SM_CXVIRTUALSCREEN = 78;
const SM_CYVIRTUALSCREEN = 79;

const SPI_SETDESKWALLPAPER = 0x0014;
const SPI_GETSCREENSAVERRUNNING = 0x0072;
const SPIF_UPDATEINIFILE = 0x01;
const SPIF_SENDCHANGE = 0x02;

const DWMWA_EXTENDED_FRAME_BOUNDS = 9;
const DWMWA_CLOAKED = 14;

/** SHQueryUserNotificationState results that mean "the desktop is not visible". */
const QUNS_BUSY = 2;
const QUNS_RUNNING_D3D_FULL_SCREEN = 3;
const QUNS_PRESENTATION_MODE = 4;

const isSupported = process.platform === 'win32';

let api = null;
let loadError = null;

if (isSupported) {
  try {
    const koffi = require('koffi');

    const user32 = koffi.load('user32.dll');
    const dwmapi = koffi.load('dwmapi.dll');
    const shell32 = koffi.load('shell32.dll');
    const kernel32 = koffi.load('kernel32.dll');

    // BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam)
    const EnumWindowsProc = koffi.proto('bool EnumWindowsProc(uintptr_t hwnd, intptr_t lparam)');

    api = {
      koffi,
      EnumWindowsProc,

      FindWindowW: user32.func('uintptr_t FindWindowW(const char16_t *cls, const char16_t *win)'),
      FindWindowExW: user32.func(
        'uintptr_t FindWindowExW(uintptr_t parent, uintptr_t childAfter, const char16_t *cls, const char16_t *win)'
      ),
      SendMessageTimeoutW: user32.func(
        'intptr_t SendMessageTimeoutW(uintptr_t hwnd, uint32_t msg, uintptr_t wParam, intptr_t lParam, uint32_t flags, uint32_t timeout, _Out_ uintptr_t *result)'
      ),
      EnumWindows: user32.func('bool EnumWindows(EnumWindowsProc *proc, intptr_t lparam)'),
      SetParent: user32.func('uintptr_t SetParent(uintptr_t child, uintptr_t newParent)'),
      SetWindowPos: user32.func(
        'bool SetWindowPos(uintptr_t hwnd, uintptr_t insertAfter, int x, int y, int cx, int cy, uint32_t flags)'
      ),
      GetWindowLongPtrW: user32.func('intptr_t GetWindowLongPtrW(uintptr_t hwnd, int index)'),
      SetWindowLongPtrW: user32.func(
        'intptr_t SetWindowLongPtrW(uintptr_t hwnd, int index, intptr_t value)'
      ),
      GetWindowRect: user32.func('bool GetWindowRect(uintptr_t hwnd, _Out_ uint8_t *rect)'),
      IsWindow: user32.func('bool IsWindow(uintptr_t hwnd)'),
      IsWindowVisible: user32.func('bool IsWindowVisible(uintptr_t hwnd)'),
      IsIconic: user32.func('bool IsIconic(uintptr_t hwnd)'),
      GetWindowThreadProcessId: user32.func(
        'uint32_t GetWindowThreadProcessId(uintptr_t hwnd, _Out_ uint32_t *pid)'
      ),
      GetClassNameW: user32.func(
        'int GetClassNameW(uintptr_t hwnd, _Out_ uint8_t *buf, int maxCount)'
      ),
      GetSystemMetrics: user32.func('int GetSystemMetrics(int index)'),
      // Two bindings for one export: `pvParam` is sometimes a null pointer and
      // sometimes an out buffer, and koffi needs to know which at declaration
      // time rather than guessing from the argument.
      SystemParametersInfoW: user32.func(
        'bool SystemParametersInfoW(uint32_t action, uint32_t uiParam, void *pvParam, uint32_t winIni)'
      ),
      SystemParametersInfoW_Out: user32.func(
        'SystemParametersInfoW',
        'bool',
        ['uint32_t', 'uint32_t', koffi.out(koffi.pointer('uint8_t')), 'uint32_t']
      ),
      RegisterWindowMessageW: user32.func(
        'uint32_t RegisterWindowMessageW(const char16_t *name)'
      ),

      DwmGetWindowAttribute: dwmapi.func(
        'int32_t DwmGetWindowAttribute(uintptr_t hwnd, uint32_t attribute, _Out_ uint8_t *value, uint32_t size)'
      ),

      SHQueryUserNotificationState: shell32.func(
        'int32_t SHQueryUserNotificationState(_Out_ int32_t *state)'
      ),

      GetSystemPowerStatus: kernel32.func(
        'bool GetSystemPowerStatus(_Out_ uint8_t *status)'
      ),
    };
  } catch (error) {
    loadError = error;
    api = null;
  }
}

/** True when the Win32 layer actually loaded and calls will do something. */
function available() {
  return api !== null;
}

/** The koffi load failure, if the bindings could not be created. */
function unavailableReason() {
  if (!isSupported) return `not Windows (platform=${process.platform})`;
  return loadError ? loadError.message : null;
}

// --- Helpers -------------------------------------------------------------

function readRectBuffer(buf) {
  return {
    left: buf.readInt32LE(0),
    top: buf.readInt32LE(4),
    right: buf.readInt32LE(8),
    bottom: buf.readInt32LE(12),
  };
}

// --- Wrapped calls -------------------------------------------------------

function findWindow(className, windowName = null) {
  if (!api) return NULL_HANDLE;
  return api.FindWindowW(className, windowName);
}

function findWindowEx(parent, childAfter, className, windowName = null) {
  if (!api) return NULL_HANDLE;
  return api.FindWindowExW(parent, childAfter, className, windowName);
}

/**
 * Sends a message with a timeout and returns the receiver's reply value.
 * Returns null when the send itself failed or timed out.
 */
function sendMessageTimeout(hwnd, msg, wParam, lParam, timeoutMs = 1000) {
  if (!api) return null;
  const result = [0];
  const ok = api.SendMessageTimeoutW(hwnd, msg, wParam, lParam, SMTO_NORMAL, timeoutMs, result);
  return ok === 0 ? null : result[0];
}

/**
 * Enumerates top-level windows. The visitor receives each HWND and may return
 * false to stop early.
 *
 * The koffi trampoline is always released, even if the visitor throws — the
 * registered-callback pool is small and leaking one would eventually break
 * every later enumeration.
 */
function enumWindows(visitor) {
  if (!api) return;
  const { koffi } = api;
  const callback = koffi.register(
    (hwnd) => {
      try {
        return visitor(hwnd) !== false;
      } catch {
        return false;
      }
    },
    koffi.pointer(api.EnumWindowsProc)
  );
  try {
    api.EnumWindows(callback, 0);
  } finally {
    koffi.unregister(callback);
  }
}

function setParent(child, newParent) {
  if (!api) return NULL_HANDLE;
  return api.SetParent(child, newParent);
}

function setWindowPos(hwnd, insertAfter, x, y, cx, cy, flags) {
  if (!api) return false;
  return api.SetWindowPos(hwnd, insertAfter, x, y, cx, cy, flags);
}

function getWindowLongPtr(hwnd, index) {
  if (!api) return 0;
  return api.GetWindowLongPtrW(hwnd, index);
}

function setWindowLongPtr(hwnd, index, value) {
  if (!api) return 0;
  return api.SetWindowLongPtrW(hwnd, index, value);
}

/** Window bounds including the invisible resize border. See `getFrameBounds`. */
function getWindowRect(hwnd) {
  if (!api) return null;
  const buf = Buffer.alloc(16);
  if (!api.GetWindowRect(hwnd, buf)) return null;
  return readRectBuffer(buf);
}

/**
 * The window's *visible* bounds.
 *
 * `GetWindowRect` includes the invisible drop-shadow/resize border DWM adds,
 * which on a maximised window overhangs the monitor and inflates the measured
 * coverage. `DWMWA_EXTENDED_FRAME_BOUNDS` is what the user actually sees, so
 * that is what occlusion should measure. Falls back to `GetWindowRect` when DWM
 * declines (it returns an HRESULT, and does for some windows).
 */
function getFrameBounds(hwnd) {
  if (!api) return null;
  const buf = Buffer.alloc(16);
  const hr = api.DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, buf, 16);
  if (hr !== 0) return getWindowRect(hwnd);
  return readRectBuffer(buf);
}

/**
 * True when DWM reports the window as cloaked — the state a window on another
 * virtual desktop, or a suspended UWP app, sits in. Cloaked windows are still
 * "visible" to `IsWindowVisible` but cover nothing, so they must not count as
 * occluding. This is the Windows analogue of the alpha/layer filtering in
 * OcclusionDetector.swift.
 */
function isCloaked(hwnd) {
  if (!api) return false;
  const buf = Buffer.alloc(4);
  const hr = api.DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, buf, 4);
  if (hr !== 0) return false;
  return buf.readUInt32LE(0) !== 0;
}

function isWindow(hwnd) {
  return api ? api.IsWindow(hwnd) : false;
}

function isWindowVisible(hwnd) {
  return api ? api.IsWindowVisible(hwnd) : false;
}

function isIconic(hwnd) {
  return api ? api.IsIconic(hwnd) : false;
}

function getWindowProcessId(hwnd) {
  if (!api) return 0;
  const pid = [0];
  api.GetWindowThreadProcessId(hwnd, pid);
  return pid[0];
}

function getClassName(hwnd) {
  if (!api) return '';
  const maxChars = 256;
  const buf = Buffer.alloc(maxChars * 2);
  const written = api.GetClassNameW(hwnd, buf, maxChars);
  if (written <= 0) return '';
  return buf.toString('utf16le', 0, written * 2);
}

function getSystemMetrics(index) {
  return api ? api.GetSystemMetrics(index) : 0;
}

/** Top-left of the virtual desktop, which is WorkerW's client origin. */
function getVirtualScreenOrigin() {
  return {
    x: getSystemMetrics(SM_XVIRTUALSCREEN),
    y: getSystemMetrics(SM_YVIRTUALSCREEN),
  };
}

function getVirtualScreenSize() {
  return {
    width: getSystemMetrics(SM_CXVIRTUALSCREEN),
    height: getSystemMetrics(SM_CYVIRTUALSCREEN),
  };
}

/**
 * Asks the shell to repaint the desktop wallpaper.
 *
 * Used after detaching, so quitting does not leave the last video frame burned
 * onto the desktop. Passing a null path means "re-apply whatever is configured".
 */
function refreshDesktopWallpaper() {
  if (!api) return false;
  return api.SystemParametersInfoW(
    SPI_SETDESKWALLPAPER,
    0,
    null,
    SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
  );
}

function isScreensaverRunning() {
  if (!api) return false;
  const buf = Buffer.alloc(4);
  if (!api.SystemParametersInfoW_Out(SPI_GETSCREENSAVERRUNNING, 0, buf, 0)) return false;
  return buf.readUInt32LE(0) !== 0;
}

/**
 * Whether the shell considers the user unavailable — which covers a fullscreen
 * D3D game, presentation mode, and full-screen video. This is the closest
 * Windows has to macOS's "a fullscreen Space is covering the desktop".
 */
function queryUserNotificationState() {
  if (!api) return null;
  const state = [0];
  const hr = api.SHQueryUserNotificationState(state);
  if (hr !== 0) return null;
  return state[0];
}

/**
 * True for an exclusive-fullscreen game or presentation mode.
 *
 * Deliberately excludes `QUNS_BUSY`, which also fires for any ordinary
 * full-screen window — the per-display coverage poll already catches those, and
 * treating BUSY as "pause everything" would stop the wallpaper on a second
 * monitor the user is still looking at.
 */
function isFullscreenAppRunning() {
  const state = queryUserNotificationState();
  if (state === null) return false;
  return state === QUNS_RUNNING_D3D_FULL_SCREEN || state === QUNS_PRESENTATION_MODE;
}

/**
 * Reads SYSTEM_POWER_STATUS.
 *
 * Layout: BYTE ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag,
 * then DWORD BatteryLifeTime, BatteryFullLifeTime.
 *
 * `SystemStatusFlag & 1` is Battery Saver — the analogue of macOS Low Power
 * Mode, and the reason this call is here rather than relying on Electron's
 * `powerMonitor`, which does not expose it.
 */
function getSystemPowerStatus() {
  if (!api) return null;
  const buf = Buffer.alloc(12);
  if (!api.GetSystemPowerStatus(buf)) return null;
  const acLineStatus = buf.readUInt8(0);
  return {
    acLineStatus,
    batteryFlag: buf.readUInt8(1),
    batteryLifePercent: buf.readUInt8(2),
    systemStatusFlag: buf.readUInt8(3),
    /** 0 = on battery, 1 = plugged in, 255 = unknown (most desktops). */
    onBattery: acLineStatus === 0,
    batterySaverOn: (buf.readUInt8(3) & 1) !== 0,
  };
}

function registerWindowMessage(name) {
  if (!api) return 0;
  return api.RegisterWindowMessageW(name);
}

module.exports = {
  isSupported,
  available,
  unavailableReason,

  NULL_HANDLE,
  WM_SPAWN_WORKER,
  GWL_STYLE,
  GWL_EXSTYLE,
  WS_CHILD,
  WS_POPUP,
  WS_VISIBLE,
  WS_EX_NOACTIVATE,
  WS_EX_TOOLWINDOW,
  WS_EX_LAYERED,
  WS_EX_APPWINDOW,
  HWND_BOTTOM,
  SWP_NOACTIVATE,
  SWP_SHOWWINDOW,
  SWP_FRAMECHANGED,
  SWP_NOZORDER,
  QUNS_BUSY,
  QUNS_RUNNING_D3D_FULL_SCREEN,
  QUNS_PRESENTATION_MODE,

  findWindow,
  findWindowEx,
  sendMessageTimeout,
  enumWindows,
  setParent,
  setWindowPos,
  getWindowLongPtr,
  setWindowLongPtr,
  getWindowRect,
  getFrameBounds,
  isCloaked,
  isWindow,
  isWindowVisible,
  isIconic,
  getWindowProcessId,
  getClassName,
  getSystemMetrics,
  getVirtualScreenOrigin,
  getVirtualScreenSize,
  refreshDesktopWallpaper,
  isScreensaverRunning,
  queryUserNotificationState,
  isFullscreenAppRunning,
  getSystemPowerStatus,
  registerWindowMessage,
};
