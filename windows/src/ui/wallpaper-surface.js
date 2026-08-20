'use strict';

// The wallpaper surface for one display.
//
// Driven from the main process via executeJavaScript rather than IPC, so
// this page needs no preload and no node integration at all.
//
// Looping uses the native `loop` attribute. macOS uses AVPlayerLooper for
// a guaranteed gapless loop; `loop` is seamless in Chromium for the muted,
// audio-free clips that make good wallpapers, and the fallback if a seam
// ever shows is a second buffered <video> swapped at the loop point.

const video = document.getElementById('surface');

window.__wallpaper = {
  setSource(url, objectFit) {
    if (objectFit) video.style.objectFit = objectFit;
    if (video.getAttribute('src') === url) return true;
    video.setAttribute('src', url);
    video.load();
    return true;
  },

  setObjectFit(objectFit) {
    video.style.objectFit = objectFit;
    return true;
  },

  clear() {
    video.pause();
    video.removeAttribute('src');
    video.load();
    return true;
  },

  play() {
    // Chromium rejects play() while the window is still being set up; a
    // rejected promise here is not an error worth surfacing, the next
    // refreshPlayback tick will try again.
    const result = video.play();
    if (result && typeof result.catch === 'function') result.catch(() => {});
    return true;
  },

  pause() {
    video.pause();
    return true;
  },

  setAudio(muted, volume) {
    video.muted = muted;
    video.volume = Math.min(1, Math.max(0, volume));
    return true;
  },

  /** Playback rate and position, for the diagnostics dump. */
  snapshot() {
    return {
      paused: video.paused,
      currentTime: video.currentTime,
      readyState: video.readyState,
      hasSource: video.hasAttribute('src'),
      error: video.error ? video.error.code : null,
    };
  },
};
