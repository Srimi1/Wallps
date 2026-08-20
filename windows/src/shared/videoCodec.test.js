'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const {
  codecFromBuffer,
  codecFromFile,
  codecDisplayName,
  looksLikeIsoBmff,
  looksLikeMatroska,
} = require('./videoCodec');

// --- Minimal ISO-BMFF builders -------------------------------------------
// Building real boxes keeps the parser honest about sizes and nesting rather
// than letting it pass on a hand-waved fixture.

function box(type, ...payloads) {
  const body = Buffer.concat(payloads.map((p) => (Buffer.isBuffer(p) ? p : Buffer.from(p))));
  const header = Buffer.alloc(8);
  header.writeUInt32BE(body.length + 8, 0);
  header.write(type, 4, 'latin1');
  return Buffer.concat([header, body]);
}

/** A `stsd` holding one sample entry of the given four-character code. */
function stsd(fourcc) {
  const versionFlags = Buffer.alloc(4);
  const entryCount = Buffer.alloc(4);
  entryCount.writeUInt32BE(1, 0);

  // Sample entry: size + format + 78 bytes of visual sample entry padding.
  const entryBody = Buffer.alloc(78);
  const entry = Buffer.alloc(8 + entryBody.length);
  entry.writeUInt32BE(entry.length, 0);
  entry.write(fourcc, 4, 'latin1');
  entryBody.copy(entry, 8);

  return box('stsd', versionFlags, entryCount, entry);
}

function mp4With(fourcc, { extraTrack = null } = {}) {
  const videoTrak = box('trak', box('mdia', box('minf', box('stbl', stsd(fourcc)))));
  const traks = extraTrack ? [extraTrack, videoTrak] : [videoTrak];
  const ftypPayload = Buffer.concat([
    Buffer.from('isom', 'latin1'),
    Buffer.from([0x00, 0x00, 0x02, 0x00]), // minor_version
    Buffer.from('isomiso2avc1mp41', 'latin1'), // compatible_brands
  ]);
  return Buffer.concat([box('ftyp', ftypPayload), box('moov', ...traks)]);
}

/** An audio track, to prove the parser does not stop at the first stsd it sees. */
const audioTrak = box('trak', box('mdia', box('minf', box('stbl', stsd('mp4a')))));

// --- Tests ---------------------------------------------------------------

test('detects H.264 in an mp4', () => {
  assert.equal(codecFromBuffer(mp4With('avc1')), 'avc1');
});

test('detects HEVC in an mp4', () => {
  assert.equal(codecFromBuffer(mp4With('hvc1')), 'hvc1');
});

test('detects AV1 and VP9', () => {
  assert.equal(codecFromBuffer(mp4With('av01')), 'av01');
  assert.equal(codecFromBuffer(mp4With('vp09')), 'vp09');
});

test('detects ProRes, which macOS can play and Chromium cannot', () => {
  assert.equal(codecFromBuffer(mp4With('apcn')), 'apcn');
  assert.equal(codecDisplayName('apcn'), 'ProRes 422');
});

test('skips the audio track and finds the video one', () => {
  assert.equal(codecFromBuffer(mp4With('hvc1', { extraTrack: audioTrak })), 'hvc1');
});

test('returns null for a file with no video track', () => {
  const audioOnly = Buffer.concat([box('ftyp', Buffer.from('isom')), box('moov', audioTrak)]);
  assert.equal(codecFromBuffer(audioOnly), null);
});

test('does not read past a truncated box', () => {
  const truncated = mp4With('avc1').subarray(0, 20);
  assert.doesNotThrow(() => codecFromBuffer(truncated));
});

test('a box claiming a size larger than the buffer is rejected, not trusted', () => {
  const bogus = Buffer.alloc(16);
  bogus.writeUInt32BE(0xffffff, 0);
  bogus.write('moov', 4, 'latin1');
  assert.equal(codecFromBuffer(bogus), null);
});

test('a zero-size box does not spin forever', () => {
  const zero = Buffer.alloc(32);
  zero.writeUInt32BE(0, 0);
  zero.write('moov', 4, 'latin1');
  // Completes rather than looping; the assertion is that we get here at all.
  assert.doesNotThrow(() => codecFromBuffer(zero));
});

test('recognises container magic', () => {
  assert.equal(looksLikeIsoBmff(mp4With('avc1')), true);
  assert.equal(looksLikeIsoBmff(Buffer.from('not a video file at all')), false);
  assert.equal(looksLikeMatroska(Buffer.from([0x1a, 0x45, 0xdf, 0xa3, 0x00])), true);
});

test('sniffs WebM codec ids', () => {
  const webm = Buffer.concat([
    Buffer.from([0x1a, 0x45, 0xdf, 0xa3]),
    Buffer.alloc(64),
    Buffer.from('V_VP9', 'latin1'),
  ]);
  assert.equal(codecFromBuffer(webm), 'vp09');
});

test('display names fall back to the raw code', () => {
  assert.equal(codecDisplayName('avc1'), 'H.264');
  assert.equal(codecDisplayName('hvc1'), 'HEVC');
  assert.equal(codecDisplayName('zzzz'), 'zzzz');
  assert.equal(codecDisplayName(null), null);
});

test('reads a codec from disk', async () => {
  const file = path.join(os.tmpdir(), `wallps-codec-${crypto.randomUUID()}.mp4`);
  fs.writeFileSync(file, mp4With('hvc1'));
  try {
    assert.equal(await codecFromFile(file), 'hvc1');
  } finally {
    fs.rmSync(file, { force: true });
  }
});

// Files that were not written with faststart keep `moov` at the end.
test('finds moov at the tail of a non-faststart file', async () => {
  const file = path.join(os.tmpdir(), `wallps-codec-${crypto.randomUUID()}.mp4`);
  const mdat = box('mdat', Buffer.alloc(64 * 1024, 7));
  const trailing = Buffer.concat([
    box('ftyp', Buffer.from('isom')),
    mdat,
    box('moov', box('trak', box('mdia', box('minf', box('stbl', stsd('avc1')))))),
  ]);
  fs.writeFileSync(file, trailing);
  try {
    // moov sits after a 64 KB mdat, so this only passes if the box list is walked.
    assert.equal(await codecFromFile(file), 'avc1');
  } finally {
    fs.rmSync(file, { force: true });
  }
});

test('a missing file yields null rather than throwing', async () => {
  assert.equal(await codecFromFile('/definitely/not/here.mp4'), null);
});
