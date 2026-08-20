/**
 * Shared renderer state and the small helpers every view needs.
 *
 * `state` is a single mutable object imported by both the renderers and the
 * action handlers — they all reference the same instance, so a mutation in one
 * module is visible in the others.
 */

export const api = window.wallps;

export const state = {
  tab: 'gallery',
  library: [],
  catalog: [],
  catalogState: 'idle', // idle | loading | loaded | failed | unconfigured
  catalogError: null,
  settings: null,
  status: {
    activeItemIds: [],
    statusDescription: 'No wallpaper set',
    pauseReason: null,
    userPaused: false,
    displays: [],
  },
  search: '',
  category: 'All',
  mood: null,
  resolution: null,
  sort: 'trending',
  filtersOpen: false,
  inspecting: null,
  busy: new Set(),
};

export const MOODS = ['Neon Glow', 'Obsidian Dark', 'Misty Rain', 'Chill Lofi', 'Ethereal Sunset', 'Cosmic Void', 'Solar Gold'];
export const RESOLUTIONS = ['8K Ultra', '4K XDR', '4K UHD'];
export const SORTS = [
  { id: 'trending', label: 'Trending' },
  { id: 'newest', label: 'Newest Drops' },
  { id: 'resolution', label: 'Highest Resolution' },
];

// --- Utilities -----------------------------------------------------------

export const $ = (id) => document.getElementById(id);

export function escapeHtml(value) {
  return String(value ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
  );
}

let toastTimer = null;
export function showToast(message, kind = 'error') {
  const toast = $('toast');
  toast.textContent = message;
  toast.className = `toast visible ${kind}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    toast.className = 'toast';
  }, kind === 'error' ? 7000 : 3000);
}

/** Runs an API call and surfaces any failure instead of swallowing it. */
export async function guard(promise, context) {
  try {
    return await promise;
  } catch (error) {
    showToast(context ? `${context}: ${error.message}` : error.message);
    return null;
  }
}
