// Offscreen metadata + thumbnail extraction.
//
// macOS gets all of this from AVFoundation (Wallps/Library/VideoProber.swift
// and ThumbnailGenerator.swift). Chromium has no equivalent API in the main
// process, so a hidden page decodes the file and reports back — which has
// the useful side effect that anything this page cannot read is exactly
// what the wallpaper window would not have been able to play either.
'use strict';

const MIN_DURATION = 0.5; // matches VideoProber.minimumDuration
const THUMBNAIL_AT = 0.4; // matches ThumbnailGenerator: 40% in
const THUMBNAIL_MAX = 640; // matches ThumbnailGenerator.maximumSize
const THUMBNAIL_QUALITY = 0.85;

function once(target, event, timeoutMs, label) {
  return new Promise((resolve, reject) => {
    const cleanup = () => {
      clearTimeout(timer);
      target.removeEventListener(event, onEvent);
      target.removeEventListener('error', onError);
    };
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error(`timeout:${label}`));
    }, timeoutMs);
    const onEvent = () => {
      cleanup();
      resolve();
    };
    const onError = () => {
      cleanup();
      reject(new Error('notAVideo'));
    };
    target.addEventListener(event, onEvent, { once: true });
    target.addEventListener('error', onError, { once: true });
  });
}

/**
 * Measures the real frame rate by timing decoded frames.
 *
 * `requestVideoFrameCallback` reports each presented frame's media timestamp,
 * so the frame interval is the gap between consecutive timestamps.
 *
 * The obvious formula — total frames over total media time — is wrong under
 * load: `presentedFrames` counts frames actually shown, so every dropped frame
 * biases the answer *downwards* (a 60 fps clip measured 55.4 that way). Gaps do
 * not have that problem, because a drop makes one gap large and leaves the rest
 * alone. Taking a low percentile of the sorted gaps therefore reads through
 * dropped frames to the true interval.
 *
 * Always resolves — an unknown frame rate is not a failed import.
 */
function estimateFrameRate(video, timeoutMs) {
  if (typeof video.requestVideoFrameCallback !== 'function') {
    return Promise.resolve(null);
  }
  return new Promise((resolve) => {
    const gaps = [];
    let previous = null;
    let settled = false;

    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        video.pause();
      } catch {}
      resolve(value);
    };

    const conclude = () => {
      if (gaps.length < 4) return finish(null);
      gaps.sort((a, b) => a - b);
      // 25th percentile: below any doubled gap left by a dropped frame, and
      // above the near-zero gaps two callbacks on one frame can produce.
      const interval = gaps[Math.floor(gaps.length * 0.25)];
      finish(interval > 0 ? 1 / interval : null);
    };

    const timer = setTimeout(conclude, timeoutMs);

    const onFrame = (_now, meta) => {
      if (settled) return;
      if (previous !== null) {
        const gap = meta.mediaTime - previous;
        // Discard duplicates and absurd jumps (a seek, or a stall).
        if (gap > 0.0005 && gap < 1) gaps.push(gap);
      }
      previous = meta.mediaTime;

      if (gaps.length >= 24) return conclude();
      video.requestVideoFrameCallback(onFrame);
    };

    video.requestVideoFrameCallback(onFrame);
    video.play().catch(() => finish(null));
  });
}

window.__wallpsProbe = async function probe(url, options) {
  const opts = options || {};
  const timeoutMs = opts.timeoutMs || 20000;

  const video = document.createElement('video');
  video.preload = 'auto';
  video.muted = true;
  video.playsInline = true;
  video.crossOrigin = 'anonymous';
  document.body.appendChild(video);

  try {
    video.src = url;
    await once(video, 'loadedmetadata', timeoutMs, 'metadata');

    const pixelWidth = video.videoWidth;
    const pixelHeight = video.videoHeight;
    // An audio-only file loads happily but has no video dimensions.
    if (!pixelWidth || !pixelHeight) throw new Error('noVideoTrack');

    const duration = video.duration;
    if (!Number.isFinite(duration) || duration <= 0) throw new Error('notAVideo');
    // Anything shorter than half a second just stutters as a loop.
    if (duration < MIN_DURATION) throw new Error('tooShort');

    const measuredFrameRate = await estimateFrameRate(video, Math.min(timeoutMs, 4000));

    // Intros and fades make poor thumbnails, so sample from 40% in.
    let thumbnail = null;
    try {
      video.currentTime = duration * THUMBNAIL_AT;
      await once(video, 'seeked', timeoutMs, 'seek');

      const scale = Math.min(1, THUMBNAIL_MAX / Math.max(pixelWidth, pixelHeight));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(pixelWidth * scale));
      canvas.height = Math.max(1, Math.round(pixelHeight * scale));
      const ctx = canvas.getContext('2d');
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      thumbnail = canvas.toDataURL('image/jpeg', THUMBNAIL_QUALITY);
    } catch {
      // A missing thumbnail is cosmetic; the wallpaper still works.
      thumbnail = null;
    }

    return {
      ok: true,
      duration,
      pixelWidth,
      pixelHeight,
      measuredFrameRate,
      thumbnail,
    };
  } catch (error) {
    return { ok: false, reason: String(error && error.message ? error.message : error) };
  } finally {
    video.removeAttribute('src');
    try {
      video.load();
    } catch {}
    video.remove();
  }
};
