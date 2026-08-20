'use strict';

/**
 * The `wallps://` scheme.
 *
 * Everything the app renders — its own UI, library videos, thumbnails, and the
 * file being probed during an import — is served through one scheme from one
 * origin. The alternative would be `file://` with `webSecurity: false`, which
 * turns off the same-origin policy for the whole session; this keeps it on.
 *
 * Layout:
 *   wallps://app/ui/index.html            the renderer
 *   wallps://app/library/Videos/<id>.mp4  a library video
 *   wallps://app/library/Thumbnails/<id>.jpg
 *   wallps://app/import/<token>           a file being probed, before it is imported
 *
 * Import tokens are opaque, single-file grants that the probe revokes when it
 * finishes, so an arbitrary path is only reachable for as long as it is
 * actually being read.
 */

const path = require('node:path');
const crypto = require('node:crypto');
const { pathToFileURL } = require('node:url');

const { logger } = require('../shared/log');

const log = logger('protocol');

const SCHEME = 'wallps';
const ORIGIN = `${SCHEME}://app`;

/** Opaque token → absolute path, for files not yet in the library. */
const importGrants = new Map();

/**
 * Must be called before `app.ready`. `stream: true` is what lets `<video>` issue
 * range requests, without which seeking in a large file does not work.
 */
function registerPrivileged(protocol) {
  protocol.registerSchemesAsPrivileged([
    {
      scheme: SCHEME,
      privileges: {
        standard: true,
        secure: true,
        supportFetchAPI: true,
        stream: true,
        corsEnabled: true,
      },
    },
  ]);
}

/** Resolves a path and refuses anything that escapes `root`. */
function resolveWithin(root, relative) {
  const resolvedRoot = path.resolve(root);
  const target = path.resolve(resolvedRoot, relative);
  const prefix = resolvedRoot.endsWith(path.sep) ? resolvedRoot : resolvedRoot + path.sep;
  if (target !== resolvedRoot && !target.startsWith(prefix)) return null;
  return target;
}

function grantImportAccess(filePath) {
  const token = crypto.randomUUID();
  importGrants.set(token, path.resolve(filePath));
  return token;
}

function revokeImportAccess(token) {
  importGrants.delete(token);
}

function importURL(token) {
  return `${ORIGIN}/import/${token}`;
}

function libraryURL(relativePath) {
  const encoded = relativePath.split(/[\\/]/).map(encodeURIComponent).join('/');
  return `${ORIGIN}/library/${encoded}`;
}

function uiURL(file) {
  return `${ORIGIN}/ui/${file}`;
}

function assetURL(file) {
  return `${ORIGIN}/assets/${file}`;
}

/**
 * Installs the handler. `uiDir` is the packaged renderer, `assetsDir` the
 * bundled icons, `libraryDir` the user's library root.
 */
function install({ protocol, net, uiDir, assetsDir, libraryDir }) {
  protocol.handle(SCHEME, async (request) => {
    let url;
    try {
      url = new URL(request.url);
    } catch {
      return new Response('Bad request', { status: 400 });
    }

    const segments = url.pathname.split('/').filter(Boolean).map(decodeURIComponent);
    const [area, ...rest] = segments;

    let filePath = null;
    if (area === 'ui') {
      filePath = resolveWithin(uiDir, rest.join(path.sep));
    } else if (area === 'assets') {
      filePath = resolveWithin(assetsDir, rest.join(path.sep));
    } else if (area === 'library') {
      filePath = resolveWithin(libraryDir, rest.join(path.sep));
    } else if (area === 'import') {
      const granted = importGrants.get(rest[0]);
      filePath = granted ?? null;
    }

    if (!filePath) {
      log.warn('refused', url.pathname);
      return new Response('Not found', { status: 404 });
    }

    try {
      // Only `Range` is forwarded, and forwarding it matters: range support is
      // the difference between seeking working and a 4K file being buffered in
      // full before the first frame shows. The rest of a request's headers
      // (Origin, Sec-Fetch-*, Accept-Encoding…) mean nothing to a file read and
      // are dropped rather than passed to a loader that may reject them.
      const range = request.headers.get('range');
      return await net.fetch(
        pathToFileURL(filePath).toString(),
        range ? { headers: { range } } : undefined
      );
    } catch (error) {
      log.warn('read failed', filePath, error);
      return new Response('Not found', { status: 404 });
    }
  });

  log.info(`installed: ui=${uiDir} assets=${assetsDir} library=${libraryDir}`);
}

module.exports = {
  SCHEME,
  ORIGIN,
  registerPrivileged,
  install,
  grantImportAccess,
  revokeImportAccess,
  importURL,
  libraryURL,
  uiURL,
  assetURL,
  resolveWithin,
};
