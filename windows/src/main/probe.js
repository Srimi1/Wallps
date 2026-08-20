'use strict';

/**
 * Video metadata and thumbnail extraction.
 *
 * Port of Wallps/Library/VideoProber.swift + ThumbnailGenerator.swift. Since
 * Chromium is the thing that will actually play the wallpaper, letting Chromium
 * decode the file during import is not a workaround — it is the most accurate
 * possible answer to "can this machine play this video?". A file that fails here
 * would have shown a black rectangle on the desktop.
 *
 * The container's codec is read separately, straight out of the file, because
 * the renderer has no API for it.
 */

const { snapFrameRate } = require('../shared/frameRate');
const { codecFromFile } = require('../shared/videoCodec');
const { logger } = require('../shared/log');
const protocolModule = require('./protocol');

const log = logger('probe');

/** User-facing messages, mirroring Wallps/Support/WallpsError.swift. */
const MESSAGES = {
  notAVideo: (name) => `“${name}” isn’t a video file Wallps can read.`,
  noVideoTrack: (name) => `“${name}” has no video track.`,
  tooShort: (name) => `“${name}” is too short to loop — videos must be at least half a second.`,
  unreadable: (name) => `“${name}” could not be read.`,
};

class ProbeError extends Error {
  constructor(reason, fileName) {
    const builder = MESSAGES[reason] ?? MESSAGES.unreadable;
    super(builder(fileName));
    this.name = 'ProbeError';
    this.reason = reason;
  }
}

class VideoProber {
  /**
   * @param {object} deps
   * @param {typeof import('electron').BrowserWindow} deps.BrowserWindow
   * @param {object} deps.app     Electron `app`, for the GPU feature status
   * @param {string} deps.uiDir   directory holding probe.html
   */
  constructor({ BrowserWindow, app, uiDir }) {
    this.BrowserWindow = BrowserWindow;
    this.app = app;
    this.uiDir = uiDir;
    this.window = null;
    /** Serialises probes — one hidden decoder is plenty, and N at once is not. */
    this.queue = Promise.resolve();
  }

  async ensureWindow() {
    if (this.window && !this.window.isDestroyed()) return this.window;

    this.window = new this.BrowserWindow({
      show: false,
      width: 640,
      height: 360,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        // The probe has to keep decoding while hidden, which is exactly what
        // background throttling would prevent.
        backgroundThrottling: false,
      },
    });
    this.window.on('closed', () => {
      this.window = null;
    });

    await this.window.loadURL(protocolModule.uiURL('probe.html'));
    return this.window;
  }

  destroy() {
    if (this.window && !this.window.isDestroyed()) this.window.destroy();
    this.window = null;
  }

  /**
   * Whether this machine can decode video in hardware.
   *
   * An approximation of `VTIsHardwareDecodeSupported`: Chromium reports one
   * overall video-decode capability rather than a per-codec answer, so this is
   * "the GPU decodes video" rather than "the GPU decodes *this* codec". Good
   * enough for the battery warning it drives, and honest about being a hint.
   */
  hardwareDecodeAvailable() {
    try {
      const status = this.app.getGPUFeatureStatus();
      const value = status?.video_decode;
      if (typeof value !== 'string') return null;
      return value.startsWith('enabled');
    } catch {
      return null;
    }
  }

  /**
   * Probes a file that is not yet in the library.
   * @param {string} filePath
   * @param {string} displayName  used in error messages
   */
  async probe(filePath, displayName) {
    const run = () => this.probeNow(filePath, displayName);
    this.queue = this.queue.then(run, run);
    return this.queue;
  }

  async probeNow(filePath, displayName) {
    const name = displayName ?? filePath;
    const token = protocolModule.grantImportAccess(filePath);
    try {
      const window = await this.ensureWindow();
      const url = protocolModule.importURL(token);
      const result = await window.webContents.executeJavaScript(
        `window.__wallpsProbe(${JSON.stringify(url)}, { timeoutMs: 20000 })`,
        true
      );

      if (!result || !result.ok) {
        const reason = normaliseReason(result?.reason);
        log.warn(`probe failed for ${name}: ${result?.reason}`);
        throw new ProbeError(reason, name);
      }

      const codec = await codecFromFile(filePath);
      const probe = {
        duration: result.duration,
        pixelWidth: result.pixelWidth,
        pixelHeight: result.pixelHeight,
        frameRate: snapFrameRate(result.measuredFrameRate),
        codec,
        hardwareDecodable: this.hardwareDecodeAvailable(),
      };
      log.info(
        `probed ${name}: ${probe.pixelWidth}x${probe.pixelHeight} ` +
          `${probe.duration.toFixed(2)}s ${probe.codec ?? 'codec?'} ${probe.frameRate ?? '?'}fps`
      );
      return { probe, thumbnail: dataUrlToBuffer(result.thumbnail) };
    } finally {
      protocolModule.revokeImportAccess(token);
    }
  }
}

/** Maps a raw failure string from the page onto one of the known reasons. */
function normaliseReason(raw) {
  if (typeof raw !== 'string') return 'unreadable';
  if (raw.includes('noVideoTrack')) return 'noVideoTrack';
  if (raw.includes('tooShort')) return 'tooShort';
  if (raw.includes('notAVideo')) return 'notAVideo';
  if (raw.startsWith('timeout')) return 'unreadable';
  return 'unreadable';
}

function dataUrlToBuffer(dataUrl) {
  if (typeof dataUrl !== 'string') return null;
  const comma = dataUrl.indexOf(',');
  if (comma < 0 || !dataUrl.startsWith('data:')) return null;
  try {
    return Buffer.from(dataUrl.slice(comma + 1), 'base64');
  } catch {
    return null;
  }
}

module.exports = { VideoProber, ProbeError, MESSAGES, normaliseReason, dataUrlToBuffer };
