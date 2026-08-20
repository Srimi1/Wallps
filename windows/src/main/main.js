'use strict';

const {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  Menu,
  dialog,
  shell,
  clipboard,
  screen,
  powerMonitor,
  powerSaveBlocker,
  protocol,
  net,
} = require('electron');
const path = require('node:path');

const protocolModule = require('./protocol');
const { Library } = require('./library');
const { VideoProber } = require('./probe');
const { SettingsStore } = require('../shared/settings');
const { SUPPORTED_EXTENSIONS } = require('../shared/libraryStore');
const { ConditionsMonitor } = require('../engine/conditions');
const { trayMenuTemplate } = require('../shared/trayMenu');
const { WallpaperEngine } = require('../engine/engine');
const host = require('../engine/workerw');
const { logger, dump } = require('../shared/log');

const log = logger('main');

const UI_DIR = path.join(__dirname, '..', 'ui');
const ASSETS_DIR = path.join(__dirname, '..', '..', 'assets');
const ICON_PATH = path.join(ASSETS_DIR, 'icon.ico');

let mainWindow = null;
let tray = null;
let settings = null;
let library = null;
let prober = null;
let engine = null;
let conditions = null;
let isQuitting = false;

// Two instances would fight over the WorkerW slot and leave the desktop in a
// mess, so the second one hands off to the first and exits.
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => showMainWindow());
  protocolModule.registerPrivileged(protocol);
  app.whenReady().then(bootstrap).catch((error) => {
    log.error('startup failed:', error);
    dialog.showErrorBox('Wallps failed to start', String(error?.stack ?? error));
    app.quit();
  });
}

async function bootstrap() {
  const userData = app.getPath('userData');

  settings = new SettingsStore(path.join(userData, 'settings.json'));
  settings.load();

  protocolModule.install({
    protocol,
    net,
    uiDir: UI_DIR,
    assetsDir: ASSETS_DIR,
    libraryDir: userData,
  });

  prober = new VideoProber({ BrowserWindow, app, uiDir: UI_DIR });
  library = new Library({ rootDir: userData, prober });
  library.load();

  conditions = new ConditionsMonitor({ screen, powerMonitor });
  engine = new WallpaperEngine({
    BrowserWindow,
    screen,
    powerSaveBlocker,
    settings,
    library,
    conditions,
  });
  engine.on('changed', broadcastStatus);

  registerIpc();
  createMainWindow();
  createTray();

  await engine.start();
  applyLaunchAtLogin(settings.get('launchAtLogin'));
  watchForExplorerRestart();

  log.info(`ready — userData=${userData}`);
  log.info('desktop host:', JSON.stringify(host.describe()));
}

// --- Windows -------------------------------------------------------------

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1040,
    height: 680,
    minWidth: 940,
    minHeight: 620,
    frame: false,
    show: false,
    backgroundColor: '#08080A',
    icon: ICON_PATH,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  // A renderer exception would otherwise be invisible from the terminal, which
  // matters most on a machine we cannot attach a debugger to.
  mainWindow.webContents.on('console-message', (event) => {
    const level = event.level === 'error' || event.level === 'warning' ? 'warn' : 'debug';
    log[level](`renderer(${event.lineNumber}): ${event.message}`);
  });
  mainWindow.webContents.on('did-fail-load', (_event, code, description, url) => {
    log.error(`renderer failed to load ${url}: ${description} (${code})`);
  });
  mainWindow.webContents.on('render-process-gone', (_event, details) => {
    log.error('renderer process gone:', JSON.stringify(details));
  });

  mainWindow.loadURL(protocolModule.uiURL('index.html'));
  mainWindow.once('ready-to-show', () => mainWindow.show());

  // Closing the window hides to the tray — the wallpaper keeps running, which
  // is the whole point of the app.
  mainWindow.on('close', (event) => {
    if (isQuitting) return;
    event.preventDefault();
    mainWindow.hide();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function showMainWindow() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    createMainWindow();
    return;
  }
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
}

// --- Tray ----------------------------------------------------------------

/** Mirrors the menu-bar extra in Wallps/UI/MenuBarContent.swift. */
function buildTrayMenu() {
  return Menu.buildFromTemplate(
    trayMenuTemplate({
      status: engine ? engine.status() : undefined,
      recent: library ? library.displayModels() : [],
      actions: {
        togglePause: () => engine.toggleUserPaused(),
        openLibrary: showMainWindow,
        applyWallpaper: (id) => engine.assign(id, 'all'),
        clearWallpaper: () => engine.assign(null, 'all'),
        copyDiagnostics,
        quit: () => {
          isQuitting = true;
          app.quit();
        },
      },
    })
  );
}

function createTray() {
  try {
    tray = new Tray(ICON_PATH);
  } catch (error) {
    // The .ico is a Windows resource; on macOS, where the app only runs for UI
    // work, failing to build a tray icon must not stop the app from starting.
    log.warn('tray unavailable:', error);
    return;
  }
  tray.setToolTip('Wallps — 4K live wallpapers');
  tray.setContextMenu(buildTrayMenu());
  tray.on('double-click', showMainWindow);
}

function refreshTray() {
  if (tray && !tray.isDestroyed()) tray.setContextMenu(buildTrayMenu());
}

// --- Status broadcast ----------------------------------------------------

function broadcastStatus() {
  refreshTray();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('status-update', engine.status());
  }
}

// --- Explorer restarts ---------------------------------------------------

/**
 * Explorer restarting destroys every WorkerW and orphans our windows. Explorer
 * broadcasts `TaskbarCreated` when it comes back, which is the cue to re-attach.
 */
function watchForExplorerRestart() {
  if (process.platform !== 'win32' || !mainWindow) return;
  const message = host.taskbarCreatedMessage();
  if (!message) return;
  try {
    mainWindow.hookWindowMessage(message, () => {
      // Explorer is still setting itself up when it broadcasts; re-attaching
      // immediately finds no WorkerW.
      setTimeout(() => engine.reattachAll('explorer restarted'), 1500);
    });
    log.info(`watching for TaskbarCreated (message ${message})`);
  } catch (error) {
    log.warn('could not hook TaskbarCreated:', error);
  }
}

// --- Diagnostics ---------------------------------------------------------

async function copyDiagnostics() {
  let details = {};
  try {
    details = await engine.describe();
  } catch (error) {
    details = { error: String(error) };
  }
  const report = [
    `Wallps ${app.getVersion()} — diagnostics`,
    `Electron ${process.versions.electron} / Chrome ${process.versions.chrome}`,
    `${process.platform} ${process.arch} ${require('node:os').release()}`,
    '',
    JSON.stringify(details, null, 2),
    '',
    '--- log ---',
    dump(),
  ].join('\n');
  clipboard.writeText(report);
  log.info('diagnostics copied to clipboard');
}

// --- Launch at login -----------------------------------------------------

function applyLaunchAtLogin(enabled) {
  try {
    app.setLoginItemSettings({
      openAtLogin: Boolean(enabled),
      path: process.execPath,
      args: ['--hidden'],
    });
  } catch (error) {
    log.warn('could not update launch-at-login:', error);
  }
}

// --- IPC -----------------------------------------------------------------

function registerIpc() {
  const handle = (channel, fn) => {
    ipcMain.handle(channel, async (_event, ...args) => {
      try {
        return { ok: true, value: await fn(...args) };
      } catch (error) {
        log.warn(`ipc ${channel} failed:`, error);
        return { ok: false, error: error?.message ?? String(error) };
      }
    });
  };

  handle('library:list', () => library.displayModels());
  handle('library:import', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      title: 'Add videos to your library',
      properties: ['openFile', 'multiSelections'],
      filters: [{ name: 'Video Files', extensions: SUPPORTED_EXTENSIONS }],
    });
    if (result.canceled || !result.filePaths.length) return { imported: [], failures: [] };
    return importPaths(result.filePaths);
  });
  handle('library:import-paths', (paths) => importPaths(paths));
  handle('library:import-download', async (payload) => {
    const item = await library.importDownload(payload);
    if (!engine.hasActiveWallpaper) await engine.assign(item.id, 'all');
    broadcastStatus();
    return item.id;
  });
  handle('library:delete', async (id) => {
    const removed = library.delete(id);
    if (removed) await engine.wallpaperRemoved(id);
    return removed;
  });
  handle('library:rename', (id, title) => library.rename(id, title));
  handle('library:reveal', (id) => {
    const item = library.item(id);
    if (!item) return false;
    shell.showItemInFolder(path.join(library.rootDir, 'Videos', item.videoFilename));
    return true;
  });
  handle('library:open-folder', () => shell.openPath(library.rootDir));

  handle('wallpaper:apply', async (id, target) => {
    await engine.assign(id, target ?? 'all');
    return engine.status();
  });
  handle('wallpaper:clear', async (target) => {
    await engine.assign(null, target ?? 'all');
    return engine.status();
  });
  handle('wallpaper:toggle-pause', () => {
    engine.toggleUserPaused();
    return engine.status();
  });

  handle('status:get', () => engine.status());
  handle('settings:get', () => settings.all());
  handle('settings:update', async (patch) => {
    const before = settings.all();
    const after = settings.update(patch);
    if (after.launchAtLogin !== before.launchAtLogin) applyLaunchAtLogin(after.launchAtLogin);
    await engine.applyAssignments();
    return after;
  });
  handle('settings:reset', async () => {
    const values = settings.reset();
    applyLaunchAtLogin(values.launchAtLogin);
    await engine.applyAssignments();
    return values;
  });

  handle('diagnostics:copy', () => copyDiagnostics().then(() => true));

  handle('window:minimize', () => mainWindow?.minimize());
  handle('window:close', () => mainWindow?.hide());
}

async function importPaths(filePaths) {
  const { imported, failures } = await library.importFiles(filePaths);
  // First import on a fresh install should feel instant, so it goes straight to
  // the desktop — matching AppState.importVideos on macOS.
  if (imported.length && !engine.hasActiveWallpaper) {
    await engine.assign(imported[0].id, 'all');
  }
  broadcastStatus();
  return { imported: imported.map((item) => item.id), failures };
}

// --- Lifecycle -----------------------------------------------------------

app.on('window-all-closed', () => {
  // Deliberately empty: this is a tray app, and the wallpaper outlives its
  // windows. (The previous implementation called preventDefault() here, which
  // does nothing — the event is not cancellable.)
});

app.on('before-quit', () => {
  isQuitting = true;
});

app.on('will-quit', async (event) => {
  if (!engine) return;
  event.preventDefault();
  try {
    await engine.stop();
    prober?.destroy();
  } catch (error) {
    log.warn('shutdown error:', error);
  } finally {
    engine = null;
    app.quit();
  }
});
