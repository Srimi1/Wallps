// Curated Wallpapers Catalog (Embedded)
const catalogData = [
  {
    id: "wallper-gathering-storm",
    title: "Gathering Storm",
    category: "Nature",
    resolution: "4K XDR",
    fps: "60 FPS",
    mood: "Misty Rain",
    size: "52 MB",
    credit: "Wallper Studios",
    preview: "https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
    colors: ["#3B4252", "#4C566A", "#2E3440"]
  },
  {
    id: "wallper-nte-zankou",
    title: "NTE - Zankou Neon Tokyo",
    category: "Cyberpunk",
    resolution: "4K UHD",
    fps: "60 FPS",
    mood: "Neon Glow",
    size: "61 MB",
    credit: "Zankou Art",
    preview: "https://images.unsplash.com/photo-1514565131-fce0801e5785?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
    colors: ["#81A1C1", "#5E81AC", "#88C0D0"]
  },
  {
    id: "wallper-snow-blossoms",
    title: "Snow & Cherry Blossoms",
    category: "Minimalist",
    resolution: "8K Ultra",
    fps: "60 FPS",
    mood: "Chill Lofi",
    size: "44 MB",
    credit: "Kumo Design",
    preview: "https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
    colors: ["#E5E9F0", "#ECEFF4", "#D8DEE9"]
  },
  {
    id: "wallper-bmw-m3-gtr",
    title: "BMW M3 GTR Night Drift",
    category: "Cars",
    resolution: "4K UHD",
    fps: "60 FPS",
    mood: "Neon Glow",
    size: "53 MB",
    credit: "NFS Garage",
    preview: "https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4",
    colors: ["#88C0D0", "#81A1C1", "#4C566A"]
  },
  {
    id: "wallper-cosmic-odyssey",
    title: "Cosmic Odyssey & Nebulae",
    category: "Sci-Fi",
    resolution: "4K XDR",
    fps: "60 FPS",
    mood: "Cosmic Void",
    size: "73 MB",
    credit: "Cosmic Archive",
    preview: "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
    colors: ["#B48EAD", "#BF616A", "#D08770"]
  },
  {
    id: "wallper-rainy-window",
    title: "Rainy Night Window Cafe",
    category: "Rain & Atmosphere",
    resolution: "4K XDR",
    fps: "60 FPS",
    mood: "Misty Rain",
    size: "47 MB",
    credit: "Lofi Ambience Lab",
    preview: "https://images.unsplash.com/photo-1519692933481-e162a57d6721?w=800&auto=format&fit=crop&q=80",
    video: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
    colors: ["#4C566A", "#434C5E", "#3B4252"]
  }
];

let state = {
  activeTab: "gallery",
  selectedCategory: "All",
  searchQuery: "",
  selectedMood: null,
  selectedRes: null,
  isFilterDrawerOpen: false,
  activeWallpaper: null,
  isPaused: false,
  inspectingItem: null,
  simMode: "win11" // 'win11' or 'mac'
};

function init() {
  renderCategories();
  renderGrid();
  setupEventListeners();

  // Listen for status updates from main process
  if (window.wallps) {
    window.wallps.onStatusChange((data) => {
      state.activeWallpaper = data.activeWallpaper;
      state.isPaused = data.isPaused;
      renderActiveDock();
      renderGrid();
    });
  }
}

function renderCategories() {
  const categories = ["All", "Cyberpunk", "Nature", "Anime", "Minimalist", "Gaming", "Cars", "Sci-Fi", "Rain & Atmosphere"];
  const container = document.getElementById("categoryTrack");
  container.innerHTML = categories.map(cat => `
    <div class="category-pill ${state.selectedCategory === cat ? 'active' : ''}" onclick="selectCategory('${cat}')">
      ${cat}
    </div>
  `).join("");
}

function selectCategory(cat) {
  state.selectedCategory = cat;
  renderCategories();
  renderGrid();
}

function toggleFilterDrawer() {
  state.isFilterDrawerOpen = !state.isFilterDrawerOpen;
  document.getElementById("matrixDrawer").style.display = state.isFilterDrawerOpen ? "grid" : "none";
}

function selectMood(mood) {
  state.selectedMood = state.selectedMood === mood ? null : mood;
  renderGrid();
}

function selectRes(res) {
  state.selectedRes = state.selectedRes === res ? null : res;
  renderGrid();
}

function getFilteredWallpapers() {
  return catalogData.filter(item => {
    const matchesCat = state.selectedCategory === "All" || item.category === state.selectedCategory;
    const matchesSearch = !state.searchQuery || item.title.toLowerCase().includes(state.searchQuery.toLowerCase()) || item.category.toLowerCase().includes(state.searchQuery.toLowerCase());
    const matchesMood = !state.selectedMood || item.mood === state.selectedMood;
    const matchesRes = !state.selectedRes || item.resolution.includes(state.selectedRes);
    return matchesCat && matchesSearch && matchesMood && matchesRes;
  });
}

function renderGrid() {
  const items = getFilteredWallpapers();
  const grid = document.getElementById("cardsGrid");

  grid.innerHTML = items.map(item => {
    const isActive = state.activeWallpaper && state.activeWallpaper.id === item.id;
    return `
      <div class="wallpaper-card ${isActive ? 'active-desktop' : ''}" ondblclick="applyWallpaper('${item.id}')">
        <div class="card-artwork">
          <img src="${item.preview}" alt="${item.title}" loading="lazy" />
          
          ${isActive ? `
            <div class="card-badge-top-left">● ACTIVE DESKTOP</div>
          ` : ''}

          <div class="card-badges-top-right">
            <span class="badge-tag cyan">${item.resolution}</span>
            <span class="badge-tag emerald">${item.fps}</span>
          </div>

          <div class="card-hover-actions">
            <button class="btn-apply" onclick="event.stopPropagation(); applyWallpaper('${item.id}')">
              ${isActive ? '✓ Active Wallpaper' : '✨ Set as Wallpaper'}
            </button>
            <button class="btn-inspect" onclick="event.stopPropagation(); inspectWallpaper('${item.id}')" title="Inspect & Simulator">
              👁
            </button>
          </div>
        </div>

        <div class="card-footer">
          <div class="card-title-row">
            <span class="card-title">${item.title}</span>
            <span class="card-mood">${item.mood}</span>
          </div>
          <div class="card-meta-row">
            <span>${item.category}</span>
            <span>·</span>
            <span>${item.size}</span>
            <span>·</span>
            <span>${item.credit}</span>
          </div>
        </div>
      </div>
    `;
  }).join("");
}

function applyWallpaper(id) {
  const item = catalogData.find(w => w.id === id);
  if (!item) return;

  state.activeWallpaper = item;
  renderActiveDock();
  renderGrid();

  if (window.wallps) {
    window.wallps.applyWallpaper(item);
  }
}

function clearWallpaper() {
  state.activeWallpaper = null;
  renderActiveDock();
  renderGrid();

  if (window.wallps) {
    window.wallps.clearWallpaper();
  }
}

function togglePause() {
  state.isPaused = !state.isPaused;
  renderActiveDock();

  if (window.wallps) {
    window.wallps.togglePause();
  }
}

function renderActiveDock() {
  const dock = document.getElementById("activeDock");
  if (state.activeWallpaper) {
    dock.innerHTML = `
      <div class="active-dock-info">
        <img class="dock-thumb" src="${state.activeWallpaper.preview}" />
        <div>
          <div class="dock-text-title">
            <span class="dot"></span>
            ${state.activeWallpaper.title}
          </div>
          <div class="dock-text-sub">
            ${state.isPaused ? 'Playback Paused' : 'Playing on Primary Display · 60.0 FPS'}
          </div>
        </div>
      </div>
      <div class="dock-controls">
        <button class="dock-btn" onclick="togglePause()">
          ${state.isPaused ? '▶ Resume' : '⏸ Pause'}
        </button>
        <button class="dock-btn" onclick="clearWallpaper()">
          ✕ Clear Desktop
        </button>
      </div>
    `;
  } else {
    dock.innerHTML = `
      <div class="active-dock-info">
        <span style="color: var(--cyber-cyan);">✨</span>
        <span style="font-size: 12px; color: var(--ink-secondary);">
          Select any 4K video wallpaper to instantly set it on your desktop
        </span>
      </div>
    `;
  }
}

function inspectWallpaper(id) {
  const item = catalogData.find(w => w.id === id);
  if (!item) return;
  state.inspectingItem = item;

  const modal = document.getElementById("inspectorModal");
  modal.style.display = "flex";
  document.getElementById("modalTitle").innerText = item.title;
  document.getElementById("modalArtist").innerText = `Artwork by ${item.credit}`;
  document.getElementById("simVideo").src = item.video;
  document.getElementById("specRes").innerText = `${item.resolution} (3840×2160)`;
  document.getElementById("specFps").innerText = `${item.fps} Smooth`;
  document.getElementById("specSize").innerText = item.size;

  const isActive = state.activeWallpaper && state.activeWallpaper.id === item.id;
  const btn = document.getElementById("modalApplyBtn");
  btn.innerText = isActive ? "✓ Active on Desktop" : "✨ Set as Live Wallpaper";
}

function closeInspector() {
  state.inspectingItem = null;
  document.getElementById("inspectorModal").style.display = "none";
  document.getElementById("simVideo").pause();
}

function setSimMode(mode) {
  state.simMode = mode;
  document.getElementById("simBtnWin").classList.toggle("active", mode === 'win11');
  document.getElementById("simBtnMac").classList.toggle("active", mode === 'mac');

  document.getElementById("simTaskbarWin11").style.display = mode === 'win11' ? 'flex' : 'none';
  document.getElementById("simMenubarMac").style.display = mode === 'mac' ? 'flex' : 'none';
}

function setupEventListeners() {
  document.getElementById("searchInput").addEventListener("input", (e) => {
    state.searchQuery = e.target.value;
    renderGrid();
  });

  document.getElementById("minBtn").addEventListener("click", () => {
    if (window.wallps) window.wallps.minimize();
  });

  document.getElementById("closeBtn").addEventListener("click", () => {
    if (window.wallps) window.wallps.close();
  });
}

document.addEventListener("DOMContentLoaded", init);
