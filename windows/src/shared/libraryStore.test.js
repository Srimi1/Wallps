'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const { LibraryStore, INDEX_VERSION, SUPPORTED_EXTENSIONS } = require('./libraryStore');
const { makeItem } = require('./wallpaperItem');

// Mirrors WallpaperLibraryTests in Tests/WallpsTests/WallpaperLibraryTests.swift.

// Always awaits `fn` before cleaning up — a synchronous `finally` here would
// delete the temp root while an async body was still copying into it.
async function withStore(fn) {
  const root = path.join(os.tmpdir(), `WallpsTests-${crypto.randomUUID()}`);
  const store = new LibraryStore(root);
  try {
    return await fn(store, root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

function sampleItem(overrides = {}) {
  return makeItem({
    id: crypto.randomUUID(),
    title: 'Test',
    videoFilename: 'video.mp4',
    duration: 10,
    pixelWidth: 3840,
    pixelHeight: 2160,
    ...overrides,
  });
}

function writeVideoFile(store, filename) {
  store.ensureFolders();
  fs.writeFileSync(path.join(store.videosDir, filename), 'not really a video');
}

test('mkv is not offered — Chromium cannot demux it', () => {
  assert.ok(!SUPPORTED_EXTENSIONS.includes('mkv'));
  assert.deepEqual(SUPPORTED_EXTENSIONS, ['mp4', 'm4v', 'webm', 'mov']);
});

test('round trips through disk', async () => {
  await withStore((store, root) => {
    writeVideoFile(store, 'video.mp4');
    const item = sampleItem();
    store.add(item);

    const reloaded = new LibraryStore(root);
    reloaded.load();
    assert.equal(reloaded.items.length, 1);
    assert.equal(reloaded.items[0].id, item.id);
    assert.equal(reloaded.items[0].title, 'Test');
  });
});

test('index is written with a version envelope', async () => {
  await withStore((store) => {
    writeVideoFile(store, 'video.mp4');
    store.add(sampleItem());
    const raw = JSON.parse(fs.readFileSync(store.indexPath, 'utf8'));
    assert.equal(raw.version, INDEX_VERSION);
    assert.equal(raw.items.length, 1);
  });
});

// A half-deleted library should not show tiles that can never play.
test('drops entries whose video is gone', async () => {
  await withStore((store, root) => {
    writeVideoFile(store, 'present.mp4');
    store.add(sampleItem({ title: 'Present', videoFilename: 'present.mp4' }));
    store.add(sampleItem({ title: 'Missing', videoFilename: 'missing.mp4' }));

    const reloaded = new LibraryStore(root);
    reloaded.load();
    assert.deepEqual(
      reloaded.items.map((i) => i.title),
      ['Present']
    );
  });
});

test('dropping a missing entry is persisted, not recomputed every load', async () => {
  await withStore((store, root) => {
    writeVideoFile(store, 'present.mp4');
    store.add(sampleItem({ title: 'Present', videoFilename: 'present.mp4' }));
    store.add(sampleItem({ title: 'Missing', videoFilename: 'missing.mp4' }));

    new LibraryStore(root).load();
    const onDisk = JSON.parse(fs.readFileSync(store.indexPath, 'utf8'));
    assert.equal(onDisk.items.length, 1);
  });
});

test('loading an absent library is not an error', async () => {
  await withStore((store) => {
    store.load();
    assert.equal(store.items.length, 0);
    assert.equal(store.lastError, null);
  });
});

test('lookup by id string', async () => {
  await withStore((store) => {
    writeVideoFile(store, 'video.mp4');
    const item = sampleItem();
    store.add(item);

    assert.equal(store.itemByIdString(item.id).id, item.id);
    assert.equal(store.itemByIdString('not-a-uuid'), null);
    assert.equal(store.itemByIdString(null), null);
    assert.equal(store.itemByIdString(undefined), null);
  });
});

test('catalog membership tracks catalogID not title', async () => {
  await withStore((store) => {
    store.add(sampleItem({ title: 'Aurora', catalogID: 'aurora-01' }));
    assert.equal(store.containsCatalogItem('aurora-01'), true);
    // A different catalog entry that happens to share a title is not owned.
    assert.equal(store.containsCatalogItem('aurora-02'), false);
  });
});

test('delete removes files and index entry', async () => {
  await withStore((store) => {
    writeVideoFile(store, 'video.mp4');
    const item = sampleItem();
    store.add(item);

    store.remove(item);
    assert.equal(store.items.length, 0);
    assert.equal(fs.existsSync(store.videoPath(item)), false);
  });
});

test('delete also removes the thumbnail', async () => {
  await withStore((store) => {
    writeVideoFile(store, 'video.mp4');
    const item = sampleItem({ thumbnailFilename: 'thumb.jpg' });
    fs.writeFileSync(path.join(store.thumbnailsDir, 'thumb.jpg'), 'jpeg');
    store.add(item);

    const thumb = store.thumbnailPath(item);
    store.remove(item);
    assert.equal(fs.existsSync(thumb), false);
  });
});

test('rename persists', async () => {
  await withStore((store, root) => {
    writeVideoFile(store, 'video.mp4');
    const item = sampleItem();
    store.add(item);

    store.rename(item, 'Renamed');
    const reloaded = new LibraryStore(root);
    reloaded.load();
    assert.equal(reloaded.items[0].title, 'Renamed');
  });
});

test('totalBytes sums known sizes and ignores unknown ones', async () => {
  await withStore((store) => {
    store.add(sampleItem({ fileSize: 1000 }));
    store.add(sampleItem({ fileSize: 2500 }));
    store.add(sampleItem({ fileSize: null }));
    assert.equal(store.totalBytes, 3500);
  });
});

test('ingest copies the video in and leaves the original alone', async () => {
  await withStore(async (store, root) => {
    const source = path.join(root, 'source.mp4');
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(source, 'video bytes');

    const item = await store.ingest({
      sourcePath: source,
      title: 'Imported',
      probe: { duration: 12, pixelWidth: 3840, pixelHeight: 2160, frameRate: 60, codec: 'avc1' },
      thumbnail: Buffer.from('jpeg bytes'),
    });

    // The original survives — the library never references a file in place.
    assert.equal(fs.existsSync(source), true);
    assert.equal(fs.existsSync(store.videoPath(item)), true);
    assert.equal(fs.existsSync(store.thumbnailPath(item)), true);
    assert.equal(item.title, 'Imported');
    assert.equal(item.pixelWidth, 3840);
    assert.equal(item.fileSize, Buffer.byteLength('video bytes'));
    // Filenames are UUIDs, so a user-supplied title never becomes a path.
    assert.match(item.videoFilename, /^[0-9a-f-]{36}\.mp4$/);
  });
});

test('ingest with removeOriginal moves the file', async () => {
  await withStore(async (store, root) => {
    fs.mkdirSync(root, { recursive: true });
    const source = path.join(root, 'download.mp4');
    fs.writeFileSync(source, 'video bytes');

    await store.ingest({
      sourcePath: source,
      title: 'Downloaded',
      probe: { duration: 8, pixelWidth: 1920, pixelHeight: 1080 },
      removeOriginal: true,
    });

    assert.equal(fs.existsSync(source), false);
  });
});

test('a failed thumbnail is not a failed import', async () => {
  await withStore(async (store, root) => {
    fs.mkdirSync(root, { recursive: true });
    const source = path.join(root, 'source.mp4');
    fs.writeFileSync(source, 'video bytes');

    const item = await store.ingest({
      sourcePath: source,
      title: 'No thumb',
      probe: { duration: 5, pixelWidth: 1920, pixelHeight: 1080 },
      thumbnail: null,
    });

    assert.equal(item.thumbnailFilename, null);
    assert.equal(store.thumbnailPath(item), null);
    assert.equal(fs.existsSync(store.videoPath(item)), true);
  });
});

test('ingest defaults a missing extension to mp4', async () => {
  await withStore(async (store, root) => {
    fs.mkdirSync(root, { recursive: true });
    const source = path.join(root, 'noextension');
    fs.writeFileSync(source, 'video bytes');

    const item = await store.ingest({
      sourcePath: source,
      title: 'Odd',
      probe: { duration: 5, pixelWidth: 1920, pixelHeight: 1080 },
    });

    assert.match(item.videoFilename, /\.mp4$/);
  });
});

test('ingested items survive a reload', async () => {
  await withStore(async (store, root) => {
    fs.mkdirSync(root, { recursive: true });
    const source = path.join(root, 'source.webm');
    fs.writeFileSync(source, 'video bytes');

    const item = await store.ingest({
      sourcePath: source,
      title: 'Persisted',
      probe: { duration: 5, pixelWidth: 1920, pixelHeight: 1080 },
    });

    const reloaded = new LibraryStore(root);
    reloaded.load();
    assert.equal(reloaded.items.length, 1);
    assert.equal(reloaded.items[0].id, item.id);
    assert.match(reloaded.items[0].videoFilename, /\.webm$/);
  });
});
