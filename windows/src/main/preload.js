const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('wallps', {
  applyWallpaper: (wallpaper) => ipcRenderer.invoke('apply-wallpaper', wallpaper),
  clearWallpaper: () => ipcRenderer.invoke('clear-wallpaper'),
  togglePause: () => ipcRenderer.invoke('toggle-pause'),
  importVideos: () => ipcRenderer.invoke('import-videos'),
  getLibrary: () => ipcRenderer.invoke('get-library'),
  onStatusChange: (callback) => ipcRenderer.on('status-update', (event, data) => callback(data)),
  minimize: () => ipcRenderer.invoke('window-minimize'),
  close: () => ipcRenderer.invoke('window-close')
});
