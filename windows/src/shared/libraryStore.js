'use strict';

/**
 * The user's wallpaper collection: video files, thumbnails, and a JSON index,
 * all stored in one folder under the app's user-data directory.
 *
 * Port of Wallps/Library/WallpaperLibrary.swift, keeping the same on-disk
 * layout so the two platforms describe a library identically:
 *
 *     Wallps/
 *       library.json          versioned index
 *       Videos/<uuid>.<ext>
 *       Thumbnails/<uuid>.jpg
 *
 * Videos are copied in on import rather than referenced in place. That costs
 * disk, but it means the library keeps working when the original is moved or
 * deleted.
 *
 * Deliberately free of any Electron import so it can be unit-tested the way
 * Tests/WallpsTests/WallpaperLibraryTests.swift tests the macOS original.
 */

const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const { makeItem, SOURCE_LOCAL } = require('./wallpaperItem');

const INDEX_VERSION = 1;

/**
 * Containers Chromium can actually demux. `mkv` is deliberately absent: the
 * previous prototype offered it in the import dialog, but Chromium cannot play
 * Matroska, so those imports failed silently with a black screen.
 */
const SUPPORTED_EXTENSIONS = ['mp4', 'm4v', 'webm', 'mov'];

class LibraryStore {
  constructor(rootDir) {
    this.rootDir = rootDir;
    this.items = [];
    this.lastError = null;
  }

  get videosDir() {
    return path.join(this.rootDir, 'Videos');
  }

  get thumbnailsDir() {
    return path.join(this.rootDir, 'Thumbnails');
  }

  get indexPath() {
    return path.join(this.rootDir, 'library.json');
  }

  ensureFolders() {
    for (const dir of [this.rootDir, this.videosDir, this.thumbnailsDir]) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  // MARK: - Persistence

  load() {
    this.ensureFolders();
    let raw;
    try {
      raw = fs.readFileSync(this.indexPath, 'utf8');
    } catch {
      // A missing index is a brand-new library, not an error.
      this.items = [];
      return;
    }

    try {
      const index = JSON.parse(raw);
      const all = Array.isArray(index.items) ? index.items : [];
      // Drop entries whose video file has disappeared, so a half-deleted
      // library doesn't show broken tiles forever.
      const present = all.filter((item) => fs.existsSync(this.videoPath(item)));
      this.items = present;
      if (present.length !== all.length) this.save();
    } catch (error) {
      this.lastError = `Couldn't read the library index: ${error.message}`;
    }
  }

  save() {
    this.ensureFolders();
    try {
      const payload = JSON.stringify({ version: INDEX_VERSION, items: this.items }, null, 2);
      // Write-then-rename, so an interrupted save cannot truncate the index.
      const tmp = `${this.indexPath}.tmp`;
      fs.writeFileSync(tmp, payload, 'utf8');
      fs.renameSync(tmp, this.indexPath);
    } catch (error) {
      this.lastError = `Couldn't save the library index: ${error.message}`;
    }
  }

  // MARK: - Lookup

  item(id) {
    return this.items.find((entry) => entry.id === id) ?? null;
  }

  itemByIdString(idString) {
    if (!idString || typeof idString !== 'string') return null;
    return this.item(idString);
  }

  containsCatalogItem(catalogID) {
    return this.items.some((entry) => entry.catalogID === catalogID);
  }

  videoPath(item) {
    return path.join(this.videosDir, item.videoFilename);
  }

  thumbnailPath(item) {
    if (!item.thumbnailFilename) return null;
    return path.join(this.thumbnailsDir, item.thumbnailFilename);
  }

  get totalBytes() {
    return this.items.reduce((sum, entry) => sum + (entry.fileSize ?? 0), 0);
  }

  // MARK: - Mutation

  /** Adds an item whose files are already in place and persists the index. */
  add(item) {
    this.items.push(item);
    this.save();
    return item;
  }

  remove(item) {
    try {
      fs.rmSync(this.videoPath(item), { force: true });
    } catch {
      /* the index entry still goes, so a locked file cannot strand a tile */
    }
    const thumb = this.thumbnailPath(item);
    if (thumb) {
      try {
        fs.rmSync(thumb, { force: true });
      } catch {
        /* cosmetic only */
      }
    }
    this.items = this.items.filter((entry) => entry.id !== item.id);
    this.save();
  }

  rename(item, newTitle) {
    const found = this.item(item.id);
    if (!found) return null;
    found.title = newTitle;
    this.save();
    return found;
  }

  // MARK: - Import

  /**
   * Copies a video into the library and indexes it.
   *
   * The caller supplies already-probed metadata and an optional thumbnail
   * buffer, which keeps this class free of Electron and makes the whole
   * pipeline testable. Mirrors `WallpaperLibrary.importVideo`.
   *
   * @param {object}  options
   * @param {string}  options.sourcePath
   * @param {string}  options.title
   * @param {object}  options.probe             { duration, pixelWidth, pixelHeight, frameRate, codec, hardwareDecodable }
   * @param {Buffer}  [options.thumbnail]       JPEG bytes; a missing thumbnail is cosmetic
   * @param {boolean} [options.removeOriginal]  move rather than copy (used for catalog downloads)
   */
  async ingest({
    sourcePath,
    title,
    probe,
    thumbnail = null,
    source = SOURCE_LOCAL,
    catalogID = null,
    credit = null,
    license = null,
    removeOriginal = false,
  }) {
    this.ensureFolders();

    const id = crypto.randomUUID();
    const rawExt = path.extname(sourcePath).replace(/^\./, '').toLowerCase();
    const ext = rawExt || 'mp4';
    const videoFilename = `${id}.${ext}`;
    const destination = path.join(this.videosDir, videoFilename);

    await transferFile(sourcePath, destination, removeOriginal);

    let thumbnailFilename = null;
    if (thumbnail && thumbnail.length) {
      thumbnailFilename = `${id}.jpg`;
      try {
        await fsp.writeFile(path.join(this.thumbnailsDir, thumbnailFilename), thumbnail);
      } catch {
        // A missing thumbnail is cosmetic; the wallpaper still works.
        thumbnailFilename = null;
      }
    }

    let fileSize = null;
    try {
      fileSize = (await fsp.stat(destination)).size;
    } catch {
      /* size is optional */
    }

    return this.add(
      makeItem({
        id,
        title,
        videoFilename,
        thumbnailFilename,
        duration: probe?.duration ?? 0,
        pixelWidth: probe?.pixelWidth ?? 0,
        pixelHeight: probe?.pixelHeight ?? 0,
        source,
        dateAdded: new Date().toISOString(),
        catalogID,
        codec: probe?.codec ?? null,
        frameRate: probe?.frameRate ?? null,
        fileSize,
        hardwareDecodable: probe?.hardwareDecodable ?? null,
        credit,
        license,
      })
    );
  }
}

/** Copies (or moves) a potentially multi-gigabyte file without blocking. */
async function transferFile(source, destination, removeOriginal) {
  await fsp.rm(destination, { force: true });
  if (removeOriginal) {
    try {
      await fsp.rename(source, destination);
      return;
    } catch {
      // rename fails across volumes; fall through to copy-then-delete.
      await fsp.copyFile(source, destination);
      await fsp.rm(source, { force: true });
      return;
    }
  }
  await fsp.copyFile(source, destination);
}

module.exports = { LibraryStore, INDEX_VERSION, SUPPORTED_EXTENSIONS };
