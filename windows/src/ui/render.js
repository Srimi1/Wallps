/**
 * Every function that turns state into DOM.
 *
 * Split from app.js so the rendering and the wiring can be read separately —
 * and to keep both files inside the project's 500-line limit.
 */

import { api, state, MOODS, RESOLUTIONS, SORTS, $, escapeHtml } from './state.js';

// --- Tabs ----------------------------------------------------------------

export function setTab(tab) {
  state.tab = tab;
  for (const el of document.querySelectorAll('.nav-tab[data-tab]')) {
    el.classList.toggle('active', el.dataset.tab === tab);
  }
  for (const view of document.querySelectorAll('.tab-view')) {
    view.hidden = view.dataset.view !== tab;
  }
}

// --- Gallery -------------------------------------------------------------

export function galleryCategories() {
  const found = new Set(state.catalog.map((entry) => entry.category).filter(Boolean));
  return ['All', ...[...found].sort()];
}

export function ownedCatalogIds() {
  return new Set(state.library.map((item) => item.catalogID).filter(Boolean));
}

export function filteredCatalog() {
  const query = state.search.trim().toLowerCase();
  const items = state.catalog.filter((entry) => {
    if (state.category !== 'All' && entry.category !== state.category) return false;
    if (state.mood && entry.mood !== state.mood) return false;
    if (state.resolution && !String(entry.resolution ?? '').includes(state.resolution)) return false;
    if (!query) return true;
    const haystack = [entry.title, entry.category, entry.credit, ...(entry.tags ?? [])]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return haystack.includes(query);
  });

  if (state.sort === 'newest') {
    return [...items].reverse();
  }
  if (state.sort === 'resolution') {
    return [...items].sort((a, b) =>
      String(b.resolution ?? '').localeCompare(String(a.resolution ?? ''))
    );
  }
  // Trending: featured entries first, original order otherwise.
  return [...items].sort((a, b) => Number(Boolean(b.isFeatured)) - Number(Boolean(a.isFeatured)));
}

export function renderChips() {
  $('categoryTrack').innerHTML = galleryCategories()
    .map(
      (cat) =>
        `<div class="category-pill ${state.category === cat ? 'active' : ''}" data-category="${escapeHtml(cat)}">${escapeHtml(cat)}</div>`
    )
    .join('');

  $('moodTokens').innerHTML = MOODS.map(
    (mood) =>
      `<div class="matrix-chip ${state.mood === mood ? 'active' : ''}" data-mood="${escapeHtml(mood)}">${escapeHtml(mood)}</div>`
  ).join('');

  $('resTokens').innerHTML = RESOLUTIONS.map(
    (res) =>
      `<div class="matrix-chip ${state.resolution === res ? 'active' : ''}" data-res="${escapeHtml(res)}">${escapeHtml(res)}</div>`
  ).join('');

  $('sortTokens').innerHTML = SORTS.map(
    (sort) =>
      `<div class="matrix-chip ${state.sort === sort.id ? 'active' : ''}" data-sort="${sort.id}">${escapeHtml(sort.label)}</div>`
  ).join('');
}

export function galleryEmptyMarkup() {
  if (state.catalogState === 'loading') {
    return `<div class="empty-glyph">⏳</div>
            <div class="empty-title">Loading catalog…</div>`;
  }
  if (state.catalogState === 'failed') {
    return `<div class="empty-glyph">⚠️</div>
            <div class="empty-title">Couldn’t load that catalog</div>
            <div class="empty-body">${escapeHtml(state.catalogError ?? 'Unknown error')}.<br>
            Check the Catalog URL in Settings.</div>`;
  }
  if (state.catalogState === 'unconfigured') {
    return `<div class="empty-glyph">✨</div>
            <div class="empty-title">No catalog configured</div>
            <div class="empty-body">
              Wallps ships without a bundled catalog. Point Settings at a
              <code>catalog.json</code> you host to browse one here — or skip it entirely and
              add your own videos under <strong>My Wallpapers</strong>.
            </div>`;
  }
  return `<div class="empty-glyph">🔍</div>
          <div class="empty-title">Nothing matches those filters</div>
          <div class="empty-body">Try clearing the search box or the filter chips.</div>`;
}

export function renderGallery() {
  renderChips();

  const items = filteredCatalog();
  const grid = $('galleryGrid');
  const empty = $('galleryEmpty');

  $('galleryCount').textContent = state.catalogState === 'loaded' ? String(state.catalog.length) : '—';

  if (!items.length) {
    grid.innerHTML = '';
    grid.style.display = 'none';
    empty.style.display = 'flex';
    empty.innerHTML = galleryEmptyMarkup();
    return;
  }

  grid.style.display = 'grid';
  empty.style.display = 'none';

  const owned = ownedCatalogIds();
  grid.innerHTML = items
    .map((entry) => {
      const isOwned = owned.has(entry.id);
      const isBusy = state.busy.has(entry.id);
      return `
      <div class="wallpaper-card" data-catalog-id="${escapeHtml(entry.id)}">
        <div class="card-artwork">
          ${
            entry.preview
              ? `<img src="${escapeHtml(entry.preview)}" alt="${escapeHtml(entry.title)}" loading="lazy" />`
              : '<div class="thumb-placeholder">🎞</div>'
          }
          ${isBusy ? '<div class="card-progress">Downloading…</div>' : ''}
          <div class="card-badges-top-right">
            <span class="badge-tag cyan">${escapeHtml(entry.resolution ?? '4K')}</span>
            <span class="badge-tag emerald">${escapeHtml(entry.fps ? `${entry.fps} FPS` : '60 FPS')}</span>
          </div>
          <div class="card-hover-actions">
            <button class="btn-apply" data-action="download" data-catalog-id="${escapeHtml(entry.id)}">
              ${isOwned ? '✓ In your library' : '⬇ Add to Library'}
            </button>
          </div>
        </div>
        <div class="card-footer">
          <div class="card-title-row">
            <span class="card-title">${escapeHtml(entry.title)}</span>
            <span class="card-mood">${escapeHtml(entry.mood ?? '')}</span>
          </div>
          <div class="card-meta-row">
            <span>${escapeHtml(entry.category ?? 'Uncategorised')}</span>
            ${entry.credit ? `<span>·</span><span>${escapeHtml(entry.credit)}</span>` : ''}
            ${entry.license ? `<span>·</span><span>${escapeHtml(entry.license)}</span>` : ''}
          </div>
        </div>
      </div>`;
    })
    .join('');
}

// --- Library -------------------------------------------------------------

export function renderLibrary() {
  const grid = $('libraryGrid');
  const empty = $('libraryEmpty');
  const active = new Set(state.status.activeItemIds ?? []);

  $('librarySubtitle').textContent = state.library.length
    ? `${state.library.length} imported ${state.library.length === 1 ? 'wallpaper' : 'wallpapers'}, stored on this PC.`
    : 'Videos you have imported, stored on this PC.';

  if (!state.library.length) {
    grid.innerHTML = '';
    grid.style.display = 'none';
    empty.style.display = 'flex';
    empty.innerHTML = `
      <div class="empty-glyph">🎞</div>
      <div class="empty-title">No wallpapers yet</div>
      <div class="empty-body">
        Drag a video anywhere onto this window, or use <strong>Add Video…</strong>.<br>
        Supported formats: <code>.mp4</code> <code>.m4v</code> <code>.webm</code> <code>.mov</code>
      </div>`;
    return;
  }

  grid.style.display = 'grid';
  empty.style.display = 'none';

  grid.innerHTML = state.library
    .map((item) => {
      const isActive = active.has(item.id);
      return `
      <div class="wallpaper-card ${isActive ? 'active-desktop' : ''}" data-item-id="${escapeHtml(item.id)}">
        <div class="card-artwork">
          ${
            item.thumbnailURL
              ? `<img src="${escapeHtml(item.thumbnailURL)}" alt="${escapeHtml(item.title)}" loading="lazy" />`
              : '<div class="thumb-placeholder">🎞</div>'
          }
          ${isActive ? '<div class="card-badge-top-left">● ACTIVE DESKTOP</div>' : ''}
          <div class="card-badges-top-right">
            <span class="badge-tag cyan">${escapeHtml(item.resolutionLabel)}</span>
            ${item.frameRateLabel ? `<span class="badge-tag emerald">${escapeHtml(item.frameRateLabel)}</span>` : ''}
          </div>
          <div class="card-hover-actions">
            <button class="btn-apply" data-action="apply" data-item-id="${escapeHtml(item.id)}">
              ${isActive ? '✓ Active Wallpaper' : '✨ Set as Wallpaper'}
            </button>
            <button class="btn-inspect" data-action="inspect" data-item-id="${escapeHtml(item.id)}" title="Inspect &amp; Simulator">👁</button>
            <button class="btn-inspect btn-danger" data-action="delete" data-item-id="${escapeHtml(item.id)}" title="Delete from library">🗑</button>
          </div>
        </div>
        <div class="card-footer">
          <div class="card-title-row">
            <span class="card-title">${escapeHtml(item.title)}</span>
            <span class="card-mood">${escapeHtml(item.durationLabel)}</span>
          </div>
          <div class="card-meta-row">
            ${item.codecLabel ? `<span>${escapeHtml(item.codecLabel)}</span><span>·</span>` : ''}
            <span>${escapeHtml(item.fileSizeLabel ?? '—')}</span>
            ${item.needsSoftwareDecode ? '<span>·</span><span class="card-warning">software decode</span>' : ''}
          </div>
        </div>
      </div>`;
    })
    .join('');
}

// --- Active dock ---------------------------------------------------------

export function renderActiveDock() {
  const dock = $('activeDock');
  const activeIds = state.status.activeItemIds ?? [];

  if (!activeIds.length) {
    dock.innerHTML = `
      <div class="active-dock-info">
        <span style="color: var(--cyber-cyan);">✨</span>
        <span style="font-size: 12px; color: var(--ink-secondary);">
          Select any video wallpaper to instantly set it on your desktop
        </span>
      </div>`;
    return;
  }

  const item = state.library.find((entry) => entry.id === activeIds[0]);
  const subtitle = state.status.pauseReason ?? state.status.statusDescription;

  dock.innerHTML = `
    <div class="active-dock-info">
      ${item?.thumbnailURL ? `<img class="dock-thumb" src="${escapeHtml(item.thumbnailURL)}" />` : ''}
      <div>
        <div class="dock-text-title">
          <span class="dot"></span>
          ${escapeHtml(state.status.statusDescription)}
        </div>
        <div class="dock-text-sub">${escapeHtml(subtitle)}</div>
      </div>
    </div>
    <div class="dock-controls">
      <button class="dock-btn" data-action="toggle-pause">
        ${state.status.userPaused ? '▶ Resume' : '⏸ Pause'}
      </button>
      <button class="dock-btn" data-action="clear">✕ Clear Desktop</button>
    </div>`;
}

// --- Inspector -----------------------------------------------------------

export function openInspector(itemId) {
  const item = state.library.find((entry) => entry.id === itemId);
  if (!item) return;
  state.inspecting = item;

  $('inspectorModal').style.display = 'flex';
  $('modalTitle').textContent = item.title;
  $('modalArtist').textContent = item.credit ? `Artwork by ${item.credit}` : 'Imported from this PC';
  $('simVideo').src = item.videoURL;
  $('badgeRes').textContent = item.resolutionLabel;
  $('badgeFps').textContent = item.frameRateLabel ?? '—';
  $('specRes').textContent =
    item.pixelWidth && item.pixelHeight
      ? `${item.resolutionLabel} (${item.pixelWidth}×${item.pixelHeight})`
      : '—';
  $('specFps').textContent = item.frameRateLabel ?? 'Unknown';
  $('specCodec').textContent = item.codecLabel ?? 'Unknown';
  $('specDuration').textContent = item.durationLabel;
  $('specSize').textContent = item.fileSizeLabel ?? '—';
  $('specDecode').textContent =
    item.hardwareDecodable === null || item.hardwareDecodable === undefined
      ? 'Unknown'
      : item.hardwareDecodable
        ? 'GPU accelerated'
        : 'Software (higher battery use)';

  const isActive = (state.status.activeItemIds ?? []).includes(item.id);
  $('modalApplyBtn').textContent = isActive ? '✓ Active on Desktop' : '✨ Set as Live Wallpaper';
}

export function closeInspector() {
  state.inspecting = null;
  $('inspectorModal').style.display = 'none';
  const video = $('simVideo');
  video.pause();
  video.removeAttribute('src');
  video.load();
}

export function setSimMode(mode) {
  $('simBtnWin').classList.toggle('active', mode === 'win11');
  $('simBtnMac').classList.toggle('active', mode === 'mac');
  $('simTaskbarWin11').style.display = mode === 'win11' ? 'flex' : 'none';
  $('simMenubarMac').style.display = mode === 'mac' ? 'flex' : 'none';
}

// --- Settings ------------------------------------------------------------

export function renderSettings() {
  const s = state.settings;
  if (!s) return;
  $('setGravity').value = s.gravity;
  $('setMuted').checked = s.muted;
  $('setVolume').value = s.volume;
  $('volumeRow').style.display = s.muted ? 'none' : 'flex';
  $('setPauseOnBattery').checked = s.pauseOnBattery;
  $('setPauseInLowPowerMode').checked = s.pauseInLowPowerMode;
  $('setPauseWhenHidden').checked = s.pauseWhenHidden;
  $('setCatalogURL').value = s.catalogURLString;
  $('setLaunchAtLogin').checked = s.launchAtLogin;
}
