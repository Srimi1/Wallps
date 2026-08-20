'use strict';

/**
 * Reads the video codec out of a container, without shelling out to ffprobe.
 *
 * macOS gets this for free from `CMFormatDescriptionGetMediaSubType`
 * (Wallps/Library/VideoProber.swift). Chromium exposes no equivalent to the
 * renderer, so for ISO-BMFF containers (mp4/m4v/mov) the sample-description box
 * is parsed directly, and for WebM the CodecID string is sniffed. That covers
 * every container the app accepts.
 *
 * The value is informational — it drives the inspector's spec table and the
 * hardware-decode hint. An unknown codec is reported as null rather than
 * guessed.
 */

const fsp = require('node:fs/promises');

/** Sample-entry four-character codes that identify a video track. */
const VIDEO_FOURCCS = new Map([
  ['avc1', 'H.264'],
  ['avc3', 'H.264'],
  ['hvc1', 'HEVC'],
  ['hev1', 'HEVC'],
  ['av01', 'AV1'],
  ['vp08', 'VP8'],
  ['vp09', 'VP9'],
  ['mp4v', 'MPEG-4'],
  ['apch', 'ProRes 422 HQ'],
  ['apcn', 'ProRes 422'],
  ['apcs', 'ProRes 422 LT'],
  ['apco', 'ProRes 422 Proxy'],
  ['ap4h', 'ProRes 4444'],
  ['dvh1', 'Dolby Vision'],
  ['dvhe', 'Dolby Vision'],
]);

/** Containers whose top level is an ISO base media file format box tree. */
const ISOBMFF_BOXES = new Set(['ftyp', 'moov', 'mdat', 'free', 'skip', 'wide', 'moof', 'styp']);

/** Boxes worth descending into while hunting for `stsd`. */
const CONTAINER_BOXES = new Set([
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'edts',
  'udta',
  'mvex',
]);

/**
 * Finds the first video sample entry in an ISO-BMFF box tree.
 * @param {Buffer} buf   a buffer positioned at the start of a box sequence
 * @returns {string|null} the four-character code, e.g. 'hvc1'
 */
function findVideoFourCCInBoxes(buf) {
  let offset = 0;
  while (offset + 8 <= buf.length) {
    let size = buf.readUInt32BE(offset);
    const type = buf.toString('latin1', offset + 4, offset + 8);
    let headerSize = 8;

    if (size === 1) {
      if (offset + 16 > buf.length) return null;
      // 64-bit sizes only matter for mdat, which we never descend into.
      const large = buf.readBigUInt64BE(offset + 8);
      size = Number(large);
      headerSize = 16;
    } else if (size === 0) {
      // "extends to end of file"
      size = buf.length - offset;
    }

    if (size < headerSize || offset + size > buf.length) {
      // Truncated or malformed — stop rather than read past the box.
      return null;
    }

    const body = buf.subarray(offset + headerSize, offset + size);

    if (type === 'stsd') {
      // version(1) + flags(3) + entry_count(4), then sample entries.
      if (body.length >= 8) {
        const entries = body.readUInt32BE(4);
        let entryOffset = 8;
        for (let i = 0; i < entries && entryOffset + 8 <= body.length; i++) {
          const entrySize = body.readUInt32BE(entryOffset);
          const format = body.toString('latin1', entryOffset + 4, entryOffset + 8);
          if (VIDEO_FOURCCS.has(format)) return format;
          if (entrySize <= 0) break;
          entryOffset += entrySize;
        }
      }
    } else if (CONTAINER_BOXES.has(type)) {
      const found = findVideoFourCCInBoxes(body);
      if (found) return found;
    }

    offset += size;
  }
  return null;
}

/** True when the buffer starts with a plausible ISO-BMFF box. */
function looksLikeIsoBmff(buf) {
  if (buf.length < 8) return false;
  const type = buf.toString('latin1', 4, 8);
  return ISOBMFF_BOXES.has(type);
}

/**
 * WebM/Matroska CodecID sniff.
 *
 * A full EBML parse would be a lot of code for one string, and the CodecID
 * element sits in the Tracks entry near the head of the file in every muxer's
 * output, so a bounded search for the known identifiers is enough.
 */
function findWebmCodec(buf) {
  const text = buf.toString('latin1');
  if (text.includes('V_VP9')) return 'vp09';
  if (text.includes('V_VP8')) return 'vp08';
  if (text.includes('V_AV1')) return 'av01';
  if (text.includes('V_MPEG4/ISO/AVC')) return 'avc1';
  if (text.includes('V_MPEGH/ISO/HEVC')) return 'hvc1';
  return null;
}

function looksLikeMatroska(buf) {
  // EBML magic.
  return buf.length >= 4 && buf.readUInt32BE(0) === 0x1a45dfa3;
}

/** Human-readable name for a four-character code, e.g. 'hvc1' → 'HEVC'. */
function codecDisplayName(fourcc) {
  if (!fourcc) return null;
  return VIDEO_FOURCCS.get(fourcc) ?? fourcc;
}

/**
 * Reads the codec from a buffer holding the head of a file.
 * Exposed separately so it can be tested without touching the disk.
 */
function codecFromBuffer(buf) {
  if (looksLikeMatroska(buf)) return findWebmCodec(buf);
  if (looksLikeIsoBmff(buf)) return findVideoFourCCInBoxes(buf);
  return null;
}

/**
 * Reads the codec from a file on disk.
 *
 * Rather than hoping the metadata sits near the start, this walks the top-level
 * box list by reading only each 8-byte header and seeking past the payload,
 * then reads the `moov` box wherever it turns out to be. That matters because
 * `moov` sits at the *end* of any file not written with faststart — which is
 * most footage straight out of a camera or an editor — while `mdat` in front of
 * it can be gigabytes that must never be read.
 *
 * @param {string} filePath
 * @param {object} [options]
 * @param {number} [options.windowBytes]  cap on how much of `moov` to read
 */
async function codecFromFile(filePath, { windowBytes = 64 * 1024 * 1024 } = {}) {
  let handle;
  try {
    handle = await fsp.open(filePath, 'r');
    const { size } = await handle.stat();
    if (size < 8) return null;

    const header = Buffer.alloc(16);
    await handle.read(header, 0, 16, 0);

    if (looksLikeMatroska(header)) {
      const sniffLength = Math.min(256 * 1024, size);
      const head = Buffer.alloc(sniffLength);
      await handle.read(head, 0, sniffLength, 0);
      return findWebmCodec(head);
    }
    if (!looksLikeIsoBmff(header)) return null;

    let offset = 0;
    // Generous bound; a real file has a handful of top-level boxes.
    for (let guard = 0; guard < 1024 && offset + 8 <= size; guard++) {
      const box = Buffer.alloc(16);
      const { bytesRead } = await handle.read(box, 0, 16, offset);
      if (bytesRead < 8) return null;

      let boxSize = box.readUInt32BE(0);
      const type = box.toString('latin1', 4, 8);
      let headerSize = 8;

      if (boxSize === 1) {
        if (bytesRead < 16) return null;
        boxSize = Number(box.readBigUInt64BE(8));
        headerSize = 16;
      } else if (boxSize === 0) {
        boxSize = size - offset;
      }
      if (boxSize < headerSize) return null;

      if (type === 'moov') {
        const bodyLength = Math.min(boxSize - headerSize, windowBytes, size - offset - headerSize);
        if (bodyLength <= 0) return null;
        const body = Buffer.alloc(bodyLength);
        await handle.read(body, 0, bodyLength, offset + headerSize);
        return findVideoFourCCInBoxes(body);
      }

      offset += boxSize;
    }
    return null;
  } catch {
    return null;
  } finally {
    await handle?.close().catch(() => {});
  }
}

module.exports = {
  VIDEO_FOURCCS,
  codecFromBuffer,
  codecFromFile,
  codecDisplayName,
  findVideoFourCCInBoxes,
  looksLikeIsoBmff,
  looksLikeMatroska,
};
