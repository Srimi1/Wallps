const { app, BrowserWindow, ipcMain, Tray, Menu, dialog, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const engine = require('../engine/workerw');

let mainWindow = null;
let wallpaperWindows = [];
let tray = null;
let activeWallpaper = null;
let isPaused = false;

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1040,
    height: 680,
    minWidth: 940,
    minHeight: 620,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#050508',
    icon: path.join(__dirname, '../../assets/icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.loadFile(path.join(__dirname, '../ui/index.html'));

  mainWindow.on('close', (event) => {
    // Hide to tray on close
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });
}

function createWallpaperWindows(videoUrl) {
  // Close existing wallpaper windows
  wallpaperWindows.forEach(win => {
    try { win.close(); } catch (e) {}
  });
  wallpaperWindows = [];

  const displays = screen.getAllDisplays();

  displays.forEach((display) => {
    const win = new BrowserWindow({
      x: display.bounds.x,
      y: display.bounds.y,
      width: display.bounds.width,
      height: display.bounds.height,
      frame: false,
      transparent: true,
      enableLargerThanScreen: true,
      hasShadow: false,
      focusable: false,
      skipTaskbar: true,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true
      }
    });

    win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          * { margin: 0; padding: 0; overflow: hidden; background: #000; }
          video { width: 100vw; height: 100vh; object-fit: cover; }
        </style>
      </head>
      <body>
        <video id="v" src="${videoUrl}" autoplay loop muted playsinline></video>
      </body>
      </html>
    `)}`);

    const hwnd = win.getNativeWindowHandle();
    engine.attachToDesktop(hwnd.readInt32LE ? hwnd.readInt32LE(0) : hwnd.readBigInt64LE(0));
    wallpaperWindows.push(win);
  });
}

function createTray() {
  const iconPath = path.join(__dirname, '../../assets/icon.ico');
  if (fs.existsSync(iconPath)) {
    tray = new Tray(iconPath);
  } else {
    tray = new Tray(path.join(__dirname, '../../assets/icon.ico'));
  }

  const contextMenu = Menu.buildFromTemplate([
    { label: 'Wallps 1.0', enabled: false },
    { type: 'separator' },
    { label: 'Open Wallps', click: () => mainWindow.show() },
    {
      label: 'Pause / Resume',
      click: () => {
        isPaused = !isPaused;
        broadcastStatus();
      }
    },
    {
      label: 'Clear Wallpaper',
      click: () => {
        wallpaperWindows.forEach(win => win.close());
        wallpaperWindows = [];
        activeWallpaper = null;
        broadcastStatus();
      }
    },
    { type: 'separator' },
    { label: 'Quit Wallps', click: () => { app.isQuitting = true; app.quit(); } }
  ]);

  tray.setToolTip('Wallps 4K Live Wallpapers');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => mainWindow.show());
}

function broadcastStatus() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('status-update', {
      activeWallpaper,
      isPaused
    });
  }
}

// IPC Handlers
ipcMain.handle('apply-wallpaper', (event, wallpaper) => {
  activeWallpaper = wallpaper;
  createWallpaperWindows(wallpaper.video);
  broadcastStatus();
  return { success: true };
});

ipcMain.handle('clear-wallpaper', () => {
  wallpaperWindows.forEach(win => win.close());
  wallpaperWindows = [];
  activeWallpaper = null;
  broadcastStatus();
  return { success: true };
});

ipcMain.handle('toggle-pause', () => {
  isPaused = !isPaused;
  wallpaperWindows.forEach(win => {
    win.webContents.executeJavaScript(`
      const v = document.getElementById('v');
      if (v) { ${isPaused} ? v.pause() : v.play(); }
    `);
  });
  broadcastStatus();
  return { isPaused };
});

ipcMain.handle('window-minimize', () => mainWindow.minimize());
ipcMain.handle('window-close', () => mainWindow.hide());

ipcMain.handle('import-videos', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: 'Video Files', extensions: ['mp4', 'mov', 'webm', 'mkv'] }
    ]
  });
  return result.filePaths;
});

app.whenReady().then(() => {
  createMainWindow();
  createTray();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
    else mainWindow.show();
  });
});

app.on('window-all-closed', (e) => {
  // Prevent app from quitting when windows close
  e.preventDefault();
});
