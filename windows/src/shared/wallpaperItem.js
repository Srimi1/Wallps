'use strict';

/**
 * A single wallpaper in the user's library.
 *
 * Port of Wallps/Library/WallpaperItem.swift. The field names and the label
 * formatting are kept identical so a `library.json` written by either platform
 * reads correctly on the other.
 *
 * The video and thumbnail files live inside the library folder under the app's
 * user-data directory; only relative filenames are stored, so the whole library
 * can be moved or backed up as one folder.
 */

/** Imported from a file on disk. */
const SOURCE_LOCAL = 'local';
/** Downloaded from a remote catalog. */
const SOURCE_REMOTE = 'remote';

function makeItem(fields) {
  return {
    id: fields.id,
    title: fields.title,
    videoFilename: fields.videoFilename,
    thumbnailFilename: fields.thumbnailFilename ?? null,
    duration: fields.duration ?? 0,
    pixelWidth: fields.pixelWidth ?? 0,
    pixelHeight: fields.pixelHeight ?? 0,
    source: fields.source ?? SOURCE_LOCAL,
    dateAdded: fields.dateAdded ?? new Date().toISOString(),
    /** Set for catalog downloads, so the gallery can mark them as owned. */
    catalogID: fields.catalogID ?? null,
    codec: fields.codec ?? null,
    frameRate: fields.frameRate ?? null,
    fileSize: fields.fileSize ?? null,
    /** False when this PC must decode the video in software. */
    hardwareDecodable: fields.hardwareDecodable ?? null,
    credit: fields.credit ?? null,
    license: fields.license ?? null,
  };
}

function resolutionLabel(pixelWidth, pixelHeight) {
  if (!(pixelWidth > 0) || !(pixelHeight > 0)) return '—';
  const shortest = Math.min(pixelWidth, pixelHeight);
  if (shortest >= 2160) return '4K';
  if (shortest >= 1080) return `${pixelHeight}p`;
  return `${pixelWidth}×${pixelHeight}`;
}

function durationLabel(duration) {
  if (!Number.isFinite(duration) || duration <= 0) return '—';
  const total = Math.round(duration);
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}

/**
 * Decimal (1000-based) byte formatting, matching macOS `ByteCountFormatter`
 * with `countStyle: .file` — so the same file reports the same size on both
 * platforms.
 */
function fileSizeLabel(bytes) {
  if (bytes === null || bytes === undefined || !Number.isFinite(bytes)) return null;
  if (bytes < 1000) return `${bytes} bytes`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let value = bytes / 1000;
  let unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit += 1;
  }
  return `${value.toFixed(1)} ${units[unit]}`;
}

/**
 * Shown as a warning: software-decoding a 4K video is the one way this app can
 * noticeably hurt a laptop's battery life.
 */
function needsSoftwareDecode(item) {
  return item.hardwareDecodable === false;
}

/** Everything the renderer needs to draw a card, with labels pre-computed. */
function toDisplayModel(item) {
  return {
    ...item,
    resolutionLabel: resolutionLabel(item.pixelWidth, item.pixelHeight),
    durationLabel: durationLabel(item.duration),
    fileSizeLabel: fileSizeLabel(item.fileSize),
    needsSoftwareDecode: needsSoftwareDecode(item),
  };
}

module.exports = {
  SOURCE_LOCAL,
  SOURCE_REMOTE,
  makeItem,
  resolutionLabel,
  durationLabel,
  fileSizeLabel,
  needsSoftwareDecode,
  toDisplayModel,
};
