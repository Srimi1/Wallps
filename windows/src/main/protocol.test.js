'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { resolveWithin, libraryURL, uiURL, ORIGIN } = require('./protocol');

// The `wallps://` handler maps URL paths onto real files, so this is the one
// place a crafted path could reach outside the library. These pin it shut.

const ROOT = path.resolve('/tmp/wallps-library');

test('resolves a normal path inside the root', () => {
  assert.equal(resolveWithin(ROOT, 'Videos/clip.mp4'), path.join(ROOT, 'Videos', 'clip.mp4'));
});

test('the root itself resolves', () => {
  assert.equal(resolveWithin(ROOT, ''), ROOT);
});

test('refuses traversal out of the root', () => {
  assert.equal(resolveWithin(ROOT, '../secrets.txt'), null);
  assert.equal(resolveWithin(ROOT, 'Videos/../../secrets.txt'), null);
  assert.equal(resolveWithin(ROOT, '../../../../etc/passwd'), null);
});

test('refuses an absolute path that escapes the root', () => {
  assert.equal(resolveWithin(ROOT, '/etc/passwd'), null);
});

// `/tmp/wallps-library-other` shares a string prefix with the root but is a
// different directory — a naive startsWith check would let it through.
test('a sibling directory sharing a name prefix is refused', () => {
  assert.equal(resolveWithin(ROOT, '../wallps-library-other/x.mp4'), null);
});

test('nested paths inside the root are allowed', () => {
  assert.equal(
    resolveWithin(ROOT, 'Thumbnails/abc.jpg'),
    path.join(ROOT, 'Thumbnails', 'abc.jpg')
  );
});

test('URL builders stay on one origin', () => {
  assert.equal(uiURL('index.html'), `${ORIGIN}/ui/index.html`);
  assert.ok(libraryURL('Videos/clip.mp4').startsWith(`${ORIGIN}/library/`));
});

test('library URLs encode characters that would break the path', () => {
  const url = libraryURL('Videos/a b#c?d.mp4');
  assert.ok(!url.includes('#'), 'a bare # would truncate the URL at the fragment');
  assert.ok(!url.includes('?'), 'a bare ? would start a query string');
  assert.ok(url.includes('%23') && url.includes('%3F'));
});

test('backslashes in a relative path are treated as separators', () => {
  assert.equal(libraryURL('Videos\\clip.mp4'), `${ORIGIN}/library/Videos/clip.mp4`);
});
