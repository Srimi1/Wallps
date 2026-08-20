'use strict';

/**
 * The library, wired to the Electron-side probe.
 *
 * `LibraryStore` holds all the disk logic and stays free of Electron so it can
 * be unit-tested; this class adds the import pipeline that needs a renderer to
 * decode video. Mirrors the split between `WallpaperLibrary.importVideo` and
 * `VideoProber`/`ThumbnailGenerator` on macOS.
 */

const path = require('node:path');
const os = require('node:os');
const fsp = require('node:fs/promises');
const crypto = require('node:crypto');

const { LibraryStore, SUPPORTED_EXTENSIONS } = require('../shared/libraryStore');
const { toDisplayModel, SOURCE_REMOTE } = require('../shared/wallpaperItem');
const { frameRateLabel } = require('../shared/frameRate');
const { codecDisplayName } = require('../shared/videoCodec');
const { logger } = require('../shared/log');
const protocolModule = require('./protocol');

const log = logger('library');

class Library {
  constructor({ rootDir, prober }) {
    this.store = new LibraryStore(rootDir);
    this.prober = prober;
    this.lastError = null;
  }

  load() {
    this.store.load();
    log.info(`loaded ${this.store.items.length} items from ${this.store.rootDir}`);
  }

  get items() {
    return this.store.items;
  }

  get rootDir() {
    return this.store.rootDir;
  }

  item(id) {
    return this.store.item(id);
  }

  /** Everything the renderer needs to draw a card, newest first. */
  displayModels() {
    return [...this.store.items]
      .sort((a, b) => String(b.dateAdded).localeCompare(String(a.dateAdded)))
      .map((item) => ({
        ...toDisplayModel(item),
        thumbnailURL: item.thumbnailFilename
          ? protocolModule.libraryURL(`Thumbnails/${item.thumbnailFilename}`)
          : null,
        videoURL: protocolModule.libraryURL(`Videos/${item.videoFilename}`),
        codecLabel: codecDisplayName(item.codec),
        frameRateLabel: frameRateLabel(item.frameRate),
      }));
  }

  /**
   * Imports videos the user picked or dropped, reporting any that failed.
   *
   * Each file is probed before anything is copied, so an unreadable file never
   * leaves a stray gigabyte in the library.
   */
  async importFiles(filePaths) {
    const imported = [];
    const failures = [];

    for (const filePath of filePaths) {
      const displayName = path.basename(filePath);
      const title = displayName.replace(/\.[^.]+$/, '');
      try {
        const extension = path.extname(filePath).replace(/^\./, '').toLowerCase();
        if (extension && !SUPPORTED_EXTENSIONS.includes(extension)) {
          // Named explicitly rather than left to fail as a black rectangle.
          throw new Error(
            `“${displayName}” is a .${extension} file, which Wallps for Windows can’t play. ` +
              `Supported formats: ${SUPPORTED_EXTENSIONS.map((e) => `.${e}`).join(', ')}.`
          );
        }

        const { probe, thumbnail } = await this.prober.probe(filePath, displayName);
        const item = await this.store.ingest({
          sourcePath: filePath,
          title,
          probe,
          thumbnail,
        });
        imported.push(item);
        log.info(`imported ${displayName} as ${item.id}`);
      } catch (error) {
        log.warn(`import failed for ${displayName}:`, error);
        failures.push(error.message ?? String(error));
      }
    }

    this.lastError = failures.length ? failures.join('\n') : null;
    return { imported, failures };
  }

  /**
   * Imports bytes the renderer downloaded from a catalog.
   *
   * Mirrors `CatalogStore.download(_:into:)`: the file lands in a temp
   * location, goes through the same probe-and-ingest path as a local import,
   * and is moved rather than copied so nothing is left behind. Carrying the
   * `catalogID` is what lets the gallery mark the entry as owned.
   */
  async importDownload({ bytes, filename, title, catalogID, credit, license }) {
    const extension = path.extname(filename ?? '').replace(/^\./, '').toLowerCase();
    if (extension && !SUPPORTED_EXTENSIONS.includes(extension)) {
      throw new Error(
        `“${title}” is a .${extension} file, which Wallps for Windows can’t play. ` +
          `Supported formats: ${SUPPORTED_EXTENSIONS.map((e) => `.${e}`).join(', ')}.`
      );
    }

    const staging = path.join(
      os.tmpdir(),
      `wallps-download-${crypto.randomUUID()}.${extension || 'mp4'}`
    );
    await fsp.writeFile(staging, Buffer.from(bytes));

    try {
      const { probe, thumbnail } = await this.prober.probe(staging, title);
      const item = await this.store.ingest({
        sourcePath: staging,
        title,
        probe,
        thumbnail,
        source: SOURCE_REMOTE,
        catalogID: catalogID ?? null,
        credit: credit ?? null,
        license: license ?? null,
        removeOriginal: true,
      });
      log.info(`downloaded ${title} as ${item.id}`);
      return item;
    } finally {
      await fsp.rm(staging, { force: true }).catch(() => {});
    }
  }

  delete(id) {
    const item = this.store.item(id);
    if (!item) return false;
    this.store.remove(item);
    log.info(`deleted ${id}`);
    return true;
  }

  rename(id, title) {
    const item = this.store.item(id);
    if (!item) return false;
    this.store.rename(item, title);
    return true;
  }

  takeLastError() {
    const error = this.lastError ?? this.store.lastError;
    this.lastError = null;
    this.store.lastError = null;
    return error;
  }
}

module.exports = { Library };
