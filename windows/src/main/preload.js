'use strict';

const { contextBridge, ipcRenderer, webUtils } = require('electron');

/**
 * The renderer's entire view of the main process.
 *
 * Every call goes through `invoke` and comes back as `{ ok, value | error }`,
 * so a failure in the main process surfaces as a rejected promise here rather
 * than a silently-swallowed warning. Each channel below has a matching
 * `ipcMain.handle` — the previous preload exposed `getLibrary`, which had no
 * handler at all and rejected on every call.
 */
const invoke = async (channel, ...args) => {
  const result = await ipcRenderer.invoke(channel, ...args);
  if (!result || result.ok !== true) {
    throw new Error(result?.error ?? `${channel} failed`);
  }
  return result.value;
};

contextBridge.exposeInMainWorld('wallps', {
  // Library
  getLibrary: () => invoke('library:list'),
  importVideos: () => invoke('library:import'),
  importPaths: (paths) => invoke('library:import-paths', paths),
  importDownload: (payload) => invoke('library:import-download', payload),

  /**
   * Resolves a dropped `File` to its path on disk.
   *
   * `File.path` was removed in Electron 32; `webUtils.getPathForFile` is the
   * replacement, and it only exists in the preload context — which is why this
   * has to be bridged rather than called from the renderer.
   */
  pathForFile: (file) => {
    try {
      return webUtils.getPathForFile(file) || null;
    } catch {
      return null;
    }
  },
  deleteWallpaper: (id) => invoke('library:delete', id),
  renameWallpaper: (id, title) => invoke('library:rename', id, title),
  revealWallpaper: (id) => invoke('library:reveal', id),
  openLibraryFolder: () => invoke('library:open-folder'),

  // Wallpaper. `target` is 'all' or a display key from status.displays.
  applyWallpaper: (id, target) => invoke('wallpaper:apply', id, target),
  clearWallpaper: (target) => invoke('wallpaper:clear', target),
  togglePause: () => invoke('wallpaper:toggle-pause'),

  // Status
  getStatus: () => invoke('status:get'),
  onStatusChange: (callback) => {
    const listener = (_event, status) => callback(status);
    ipcRenderer.on('status-update', listener);
    return () => ipcRenderer.removeListener('status-update', listener);
  },

  // Settings
  getSettings: () => invoke('settings:get'),
  updateSettings: (patch) => invoke('settings:update', patch),
  resetSettings: () => invoke('settings:reset'),

  // Diagnostics
  copyDiagnostics: () => invoke('diagnostics:copy'),

  // Window chrome
  minimize: () => invoke('window:minimize'),
  close: () => invoke('window:close'),
});
