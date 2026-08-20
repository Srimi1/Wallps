'use strict';

/**
 * Renderer entry point: loads data, wires events, and runs the actions.
 *
 * Everything shown here comes from the main process over the `window.wallps`
 * bridge — the local library, the catalog (when one is configured), and the
 * live engine status. There is no bundled catalog: the gallery stays empty
 * until the user points Settings at a `catalog.json` they host.
 */

import { api, state, showToast, guard, $ } from './state.js';
import {
  setTab,
  renderGallery,
  renderLibrary,
  renderActiveDock,
  renderSettings,
  openInspector,
  closeInspector,
  setSimMode,
  ownedCatalogIds,
} from './render.js';

// --- Data loading --------------------------------------------------------

async function refreshLibrary() {
  const items = await guard(api.getLibrary(), 'Could not read your library');
  if (items) state.library = items;
  renderLibrary();
  renderActiveDock();
}

async function refreshStatus() {
  const status = await guard(api.getStatus(), 'Could not read status');
  if (status) state.status = status;
  renderActiveDock();
  renderLibrary();
}

async function refreshSettings() {
  const settings = await guard(api.getSettings(), 'Could not read settings');
  if (settings) state.settings = settings;
  renderSettings();
}

/**
 * Loads the catalog from the URL in Settings.
 *
 * Unlike the macOS build, a failure here does not quietly substitute a
 * built-in list — an empty gallery that says why is more useful than content
 * the user did not choose.
 */
async function refreshCatalog() {
  const url = state.settings?.catalogURLString?.trim();
  if (!url) {
    state.catalogState = 'unconfigured';
    state.catalog = [];
    renderGallery();
    return;
  }

  state.catalogState = 'loading';
  renderGallery();

  try {
    const response = await fetch(url, { cache: 'no-cache' });
    if (!response.ok) throw new Error(`the server returned ${response.status}`);
    const payload = await response.json();
    const entries = Array.isArray(payload?.wallpapers) ? payload.wallpapers : [];
    state.catalog = entries.filter((entry) => entry && entry.id && entry.video);
    state.catalogState = 'loaded';
    state.catalogError = null;
  } catch (error) {
    state.catalog = [];
    state.catalogState = 'failed';
    state.catalogError = error.message;
  }
  renderGallery();
}

// --- Settings ------------------------------------------------------------

async function updateSetting(patch) {
  const updated = await guard(api.updateSettings(patch), 'Could not save settings');
  if (updated) state.settings = updated;
  renderSettings();
}

// --- Actions -------------------------------------------------------------

async function applyWallpaper(itemId) {
  const status = await guard(api.applyWallpaper(itemId, 'all'), 'Could not set the wallpaper');
  if (status) state.status = status;
  renderActiveDock();
  renderLibrary();
}

async function deleteWallpaper(itemId) {
  const item = state.library.find((entry) => entry.id === itemId);
  await guard(api.deleteWallpaper(itemId), 'Could not delete that wallpaper');
  await refreshLibrary();
  await refreshStatus();
  if (item) showToast(`Removed “${item.title}” from your library.`, 'success');
}

/**
 * Downloads a catalog entry into the library.
 *
 * The bytes are fetched here rather than in the main process so the same
 * network stack — and the same failure messages — apply as for the preview
 * images the gallery already loaded.
 */
async function downloadCatalogEntry(entryId) {
  const entry = state.catalog.find((item) => item.id === entryId);
  if (!entry) return;
  if (ownedCatalogIds().has(entryId)) {
    showToast(`“${entry.title}” is already in your library.`, 'success');
    return;
  }
  if (state.busy.has(entryId)) return;

  state.busy.add(entryId);
  renderGallery();
  try {
    showToast(`Downloading “${entry.title}”…`, 'success');
    const response = await fetch(entry.video);
    if (!response.ok) throw new Error(`the server returned ${response.status}`);
    const blob = await response.blob();
    const buffer = new Uint8Array(await blob.arrayBuffer());
    await api.importDownload({
      bytes: buffer,
      filename: entry.video.split('/').pop() || `${entry.id}.mp4`,
      title: entry.title,
      catalogID: entry.id,
      credit: entry.credit ?? null,
      license: entry.license ?? null,
    });
    await refreshLibrary();
    await refreshStatus();
    showToast(`Added “${entry.title}” to your library.`, 'success');
  } catch (error) {
    showToast(`Couldn’t download “${entry.title}”: ${error.message}`);
  } finally {
    state.busy.delete(entryId);
    renderGallery();
  }
}

async function importVideos() {
  const result = await guard(api.importVideos(), 'Import failed');
  await handleImportResult(result);
}

async function importPaths(paths) {
  if (!paths.length) return;
  const result = await guard(api.importPaths(paths), 'Import failed');
  await handleImportResult(result);
}

async function handleImportResult(result) {
  if (!result) return;
  await refreshLibrary();
  await refreshStatus();
  if (result.failures?.length) {
    showToast(result.failures.join('\n'));
  } else if (result.imported?.length) {
    const count = result.imported.length;
    showToast(`Added ${count} ${count === 1 ? 'wallpaper' : 'wallpapers'} to your library.`, 'success');
    setTab('library');
  }
}

// --- Events --------------------------------------------------------------

function setupEventListeners() {
  for (const tab of document.querySelectorAll('.nav-tab[data-tab]')) {
    tab.addEventListener('click', () => setTab(tab.dataset.tab));
  }

  $('minBtn').addEventListener('click', () => api.minimize());
  $('closeBtn').addEventListener('click', () => api.close());
  $('addVideoBtn').addEventListener('click', importVideos);

  $('searchInput').addEventListener('input', (event) => {
    state.search = event.target.value;
    renderGallery();
  });

  $('filterToggle').addEventListener('click', () => {
    state.filtersOpen = !state.filtersOpen;
    $('matrixDrawer').style.display = state.filtersOpen ? 'grid' : 'none';
  });

  // Delegated so re-rendered markup never needs listeners re-bound.
  document.addEventListener('click', async (event) => {
    const target = event.target.closest('[data-action], [data-category], [data-mood], [data-res], [data-sort]');
    if (!target) return;

    if (target.dataset.category) {
      state.category = target.dataset.category;
      return renderGallery();
    }
    if (target.dataset.mood) {
      state.mood = state.mood === target.dataset.mood ? null : target.dataset.mood;
      return renderGallery();
    }
    if (target.dataset.res) {
      state.resolution = state.resolution === target.dataset.res ? null : target.dataset.res;
      return renderGallery();
    }
    if (target.dataset.sort) {
      state.sort = target.dataset.sort;
      return renderGallery();
    }

    event.stopPropagation();
    switch (target.dataset.action) {
      case 'apply':
        return applyWallpaper(target.dataset.itemId);
      case 'inspect':
        return openInspector(target.dataset.itemId);
      case 'delete':
        return deleteWallpaper(target.dataset.itemId);
      case 'download':
        return downloadCatalogEntry(target.dataset.catalogId);
      case 'toggle-pause': {
        const status = await guard(api.togglePause(), 'Could not pause');
        if (status) state.status = status;
        return renderActiveDock();
      }
      case 'clear': {
        const status = await guard(api.clearWallpaper('all'), 'Could not clear the wallpaper');
        if (status) state.status = status;
        renderActiveDock();
        return renderLibrary();
      }
      default:
        return undefined;
    }
  });

  // Double-click a library card to apply it, matching the macOS gesture.
  $('libraryGrid').addEventListener('dblclick', (event) => {
    const card = event.target.closest('[data-item-id]');
    if (card) applyWallpaper(card.dataset.itemId);
  });

  $('closeInspectorBtn').addEventListener('click', closeInspector);
  $('modalCloseBtn').addEventListener('click', closeInspector);
  $('modalApplyBtn').addEventListener('click', () => {
    if (state.inspecting) applyWallpaper(state.inspecting.id);
  });
  $('inspectorModal').addEventListener('click', (event) => {
    if (event.target === $('inspectorModal')) closeInspector();
  });
  $('simBtnWin').addEventListener('click', () => setSimMode('win11'));
  $('simBtnMac').addEventListener('click', () => setSimMode('mac'));

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.inspecting) closeInspector();
  });

  // Settings
  $('setGravity').addEventListener('change', (e) => updateSetting({ gravity: e.target.value }));
  $('setMuted').addEventListener('change', (e) => updateSetting({ muted: e.target.checked }));
  $('setVolume').addEventListener('change', (e) => updateSetting({ volume: Number(e.target.value) }));
  $('setPauseOnBattery').addEventListener('change', (e) => updateSetting({ pauseOnBattery: e.target.checked }));
  $('setPauseInLowPowerMode').addEventListener('change', (e) => updateSetting({ pauseInLowPowerMode: e.target.checked }));
  $('setPauseWhenHidden').addEventListener('change', (e) => updateSetting({ pauseWhenHidden: e.target.checked }));
  $('setLaunchAtLogin').addEventListener('change', (e) => updateSetting({ launchAtLogin: e.target.checked }));
  $('setCatalogURL').addEventListener('change', async (e) => {
    await updateSetting({ catalogURLString: e.target.value.trim() });
    await refreshCatalog();
  });
  $('reloadCatalogBtn').addEventListener('click', refreshCatalog);
  $('openFolderBtn').addEventListener('click', () => api.openLibraryFolder());
  $('copyDiagnosticsBtn').addEventListener('click', async () => {
    await guard(api.copyDiagnostics(), 'Could not copy diagnostics');
    showToast('Diagnostics copied to the clipboard.', 'success');
  });

  setupDragAndDrop();
}

function setupDragAndDrop() {
  const overlay = $('dropOverlay');
  let depth = 0;

  document.addEventListener('dragenter', (event) => {
    event.preventDefault();
    depth += 1;
    overlay.classList.add('visible');
  });
  document.addEventListener('dragover', (event) => event.preventDefault());
  document.addEventListener('dragleave', (event) => {
    event.preventDefault();
    depth = Math.max(0, depth - 1);
    if (depth === 0) overlay.classList.remove('visible');
  });
  document.addEventListener('drop', async (event) => {
    event.preventDefault();
    depth = 0;
    overlay.classList.remove('visible');

    const paths = [...(event.dataTransfer?.files ?? [])]
      .map((file) => window.wallps.pathForFile(file))
      .filter(Boolean);
    if (paths.length) await importPaths(paths);
  });
}

// --- Boot ----------------------------------------------------------------

async function init() {
  setTab('gallery');
  setSimMode('win11');
  setupEventListeners();

  api.onStatusChange((status) => {
    state.status = status;
    renderActiveDock();
    renderLibrary();
  });

  await refreshSettings();
  await refreshLibrary();
  await refreshStatus();
  await refreshCatalog();
}

// Module scripts are deferred, so the DOM is already parsed by the time this
// runs — waiting for DOMContentLoaded here would sometimes wait forever.
init();
