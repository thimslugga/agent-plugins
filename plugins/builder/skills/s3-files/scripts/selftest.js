#!/usr/bin/env node
'use strict';

// Unit tests for the pure helpers in scripts/lib.js.
// No AWS credentials or network needed: `npm test`.
//
// Exit 0 = all pass, 1 = failure.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  sanitizeS3Key,
  defaultUploadKey,
  sanitizeFileName,
  displayFileName,
  resolveExpiresIn,
  resolveMaxSizeMB,
  getContentType,
  MAX_EXPIRES_IN_SECONDS,
} = require('./lib');

test('sanitizeS3Key preserves directory structure', () => {
  // The upstream version stripped "/" and mangled documented examples.
  assert.equal(
    sanitizeS3Key('uploads/custom-name.pdf'),
    'uploads/custom-name.pdf'
  );
  assert.equal(
    sanitizeS3Key('reports/2026/q1 summary.pdf'),
    'uploads/reports/2026/q1_summary.pdf'
  );
});

test('sanitizeS3Key blocks path traversal', () => {
  assert.equal(sanitizeS3Key('../../etc/passwd'), 'uploads/etc/passwd');
  assert.equal(sanitizeS3Key('uploads/../secret.txt'), 'uploads/secret.txt');
  assert.equal(sanitizeS3Key('/absolute/path.txt'), 'uploads/absolute/path.txt');
});

test('sanitizeS3Key forces the configured prefix', () => {
  assert.equal(sanitizeS3Key('report.pdf'), 'uploads/report.pdf');
  assert.equal(sanitizeS3Key('report.pdf', 'shared'), 'shared/report.pdf');
});

test('sanitizeS3Key returns null for unusable input', () => {
  assert.equal(sanitizeS3Key(null), null);
  assert.equal(sanitizeS3Key(''), null);
  assert.equal(sanitizeS3Key('...'), null);
  assert.equal(sanitizeS3Key('uploads'), null);
});

test('sanitizeS3Key truncates to the 1024-char S3 limit', () => {
  const out = sanitizeS3Key('a'.repeat(2000) + '.txt');
  assert.ok(out.length <= 1024);
  assert.ok(out.startsWith('uploads/'));
});

test('defaultUploadKey builds a timestamped key under the prefix', () => {
  const key = defaultUploadKey('/tmp/report final.pdf');
  assert.match(key, /^uploads\/\d+-report final\.pdf$/);
  const custom = defaultUploadKey('/tmp/x.txt', 'shared');
  assert.ok(custom.startsWith('shared/'));
});

test('sanitizeFileName hardens the Content-Disposition value', () => {
  assert.equal(sanitizeFileName('report.pdf'), 'report.pdf');
  assert.equal(sanitizeFileName('a"b\\c.pdf'), 'abc.pdf');
  assert.equal(sanitizeFileName('evil\r\nHeader: x'), 'evilHeader: x');
  assert.equal(sanitizeFileName(''), 'download');
});

test('displayFileName strips directories and timestamp prefixes', () => {
  assert.equal(
    displayFileName('uploads/1772120357022-report.pdf'),
    'report.pdf'
  );
  // Custom keys without a timestamp keep their basename, not the prefix.
  assert.equal(displayFileName('uploads/custom-name.pdf'), 'custom-name.pdf');
  assert.equal(displayFileName('reports/notes.txt'), 'notes.txt');
});

test('resolveExpiresIn validates and clamps to the SigV4 7-day max', () => {
  assert.equal(resolveExpiresIn(24), 86400);
  assert.equal(resolveExpiresIn(48), 172800);
  assert.equal(resolveExpiresIn(10000), MAX_EXPIRES_IN_SECONDS);
  assert.throws(() => resolveExpiresIn(0), /positive/);
  assert.throws(() => resolveExpiresIn(-5), /positive/);
  assert.throws(() => resolveExpiresIn('soon'), /positive/);
  assert.throws(() => resolveExpiresIn(NaN), /positive/);
});

test('resolveMaxSizeMB validates and clamps to the 5 GB POST limit', () => {
  assert.equal(resolveMaxSizeMB(100), 100);
  assert.equal(resolveMaxSizeMB(99999), 5120);
  assert.throws(() => resolveMaxSizeMB(0), /positive/);
  assert.throws(() => resolveMaxSizeMB('huge'), /positive/);
});

test('getContentType covers common types and falls back safely', () => {
  assert.equal(getContentType('a.pdf'), 'application/pdf');
  assert.equal(getContentType('a.PNG'), 'image/png');
  assert.equal(getContentType('a.mp4'), 'video/mp4');
  assert.equal(getContentType('a.csv'), 'text/csv');
  assert.equal(getContentType('a.docx'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  assert.equal(getContentType('a.unknownext'), 'application/octet-stream');
  assert.equal(getContentType('noext'), 'application/octet-stream');
});
