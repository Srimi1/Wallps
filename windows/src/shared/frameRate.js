'use strict';

/**
 * Frame rate normalisation.
 *
 * macOS reads `nominalFrameRate` straight off the asset track. Chromium exposes
 * no equivalent, so the probe measures it by timing decoded frames — which lands
 * near, but not exactly on, the real rate. Snapping to the nearest standard rate
 * turns "59.87" into the "60 FPS" the card is supposed to show, while leaving
 * genuinely unusual rates alone rather than inventing a plausible lie.
 */

/** Rates worth snapping to, including the NTSC pulldowns. */
const STANDARD_RATES = [
  23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60, 72, 90, 100, 120, 144, 165, 240,
];

/** How far off a measurement may be and still count as that standard rate. */
const TOLERANCE = 0.02; // 2%

function snapFrameRate(measured) {
  if (measured === null || measured === undefined) return null;
  if (!Number.isFinite(measured) || measured <= 0) return null;

  let best = null;
  let bestError = Infinity;
  for (const rate of STANDARD_RATES) {
    const error = Math.abs(measured - rate) / rate;
    if (error < bestError) {
      bestError = error;
      best = rate;
    }
  }
  if (best !== null && bestError <= TOLERANCE) return best;

  // Not close to anything standard — report what was measured, rounded, rather
  // than forcing it onto the nearest familiar number.
  return Math.round(measured * 100) / 100;
}

/** Label for a card badge, e.g. `60 FPS`. Matches `CatalogEntry.displayFPS`. */
function frameRateLabel(frameRate) {
  if (frameRate === null || frameRate === undefined || !Number.isFinite(frameRate)) return null;
  const rounded = Math.round(frameRate);
  // The NTSC rates read as their nominal integer on a badge: 23.976 → 24,
  // 29.97 → 30, 59.94 → 60. The window has to clear 0.06 to cover 59.94, while
  // staying far too tight to disturb a genuinely odd rate like 37.5.
  const shown = Math.abs(frameRate - rounded) <= 0.1 ? rounded : frameRate;
  return `${shown} FPS`;
}

module.exports = { STANDARD_RATES, TOLERANCE, snapFrameRate, frameRateLabel };
