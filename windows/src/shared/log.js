'use strict';

/**
 * Diagnostics log with an in-memory ring buffer.
 *
 * The WorkerW attachment is undocumented and varies by Windows build, so when
 * it misbehaves on a user's machine the only practical debugging channel is
 * "have them paste the log". `WALLPS_DEBUG=1` mirrors everything to stderr;
 * the ring buffer is always kept so the tray's "Copy diagnostics" item can hand
 * back the recent history even when the app was started normally.
 *
 * Mirrors the `WALLPS_DEBUG_PLAYBACK` hook in Wallps/Engine/WallpaperEngine.swift.
 */

const MAX_ENTRIES = 500;

const enabled = process.env.WALLPS_DEBUG === '1' || process.env.WALLPS_DEBUG === 'true';
const entries = [];
let sequence = 0;

function record(level, scope, message) {
  const entry = { seq: ++sequence, at: new Date().toISOString(), level, scope, message };
  entries.push(entry);
  if (entries.length > MAX_ENTRIES) entries.shift();
  return entry;
}

function format(entry) {
  return `[${entry.at}] ${entry.level.toUpperCase().padEnd(5)} ${entry.scope}: ${entry.message}`;
}

function emit(level, scope, args) {
  const message = args
    .map((a) => (typeof a === 'string' ? a : safeStringify(a)))
    .join(' ');
  const entry = record(level, scope, message);
  // Warnings and errors always surface; debug output only with the env var, so
  // normal runs stay quiet.
  if (enabled || level === 'warn' || level === 'error') {
    process.stderr.write(`${format(entry)}\n`);
  }
}

function safeStringify(value) {
  if (value instanceof Error) return `${value.name}: ${value.message}`;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

/** Creates a logger bound to a scope, e.g. `logger('workerw')`. */
function logger(scope) {
  return {
    debug: (...args) => emit('debug', scope, args),
    info: (...args) => emit('info', scope, args),
    warn: (...args) => emit('warn', scope, args),
    error: (...args) => emit('error', scope, args),
  };
}

/** The whole ring buffer as text, for the tray's "Copy diagnostics" item. */
function dump() {
  return entries.map(format).join('\n');
}

function clear() {
  entries.length = 0;
}

module.exports = { logger, dump, clear, enabled, MAX_ENTRIES };
