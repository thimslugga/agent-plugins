'use strict';

// Shared helpers for the s3-files skill.
// Pure functions (no AWS calls) live here so they can be unit-tested
// via scripts/selftest.js without credentials.

const fs = require('fs');
const path = require('path');

// SigV4 pre-signed URLs cannot outlive 7 days.
const MAX_EXPIRES_IN_SECONDS = 7 * 24 * 3600;
// S3 single-object POST upload limit.
const MAX_POST_SIZE_MB = 5120;

/**
 * Load and validate the skill configuration.
 *
 * Looks for config.json next to the skill root (override with the
 * S3_FILES_CONFIG env var). Throws a human-readable error when the file
 * is missing or incomplete, instead of a raw MODULE_NOT_FOUND.
 */
function loadConfig() {
  const configPath =
    process.env.S3_FILES_CONFIG || path.join(__dirname, '..', 'config.json');

  if (!fs.existsSync(configPath)) {
    throw new Error(
      `config.json not found (looked at ${configPath}). ` +
        'Copy config.example.json to config.json and set "bucketName" and "region".'
    );
  }

  let cfg;
  try {
    cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch (err) {
    throw new Error(`Could not parse ${configPath}: ${err.message}`);
  }

  if (!cfg.bucketName || typeof cfg.bucketName !== 'string') {
    throw new Error(`"${configPath}" must set a "bucketName" string.`);
  }
  if (!cfg.region || typeof cfg.region !== 'string') {
    throw new Error(`"${configPath}" must set a "region" string.`);
  }

  return {
    bucketName: cfg.bucketName,
    region: cfg.region,
    defaultExpirationHours:
      Number.isFinite(Number(cfg.defaultExpirationHours)) &&
      Number(cfg.defaultExpirationHours) > 0
        ? Number(cfg.defaultExpirationHours)
        : 24,
    maxUploadSizeMB:
      Number.isFinite(Number(cfg.maxUploadSizeMB)) &&
      Number(cfg.maxUploadSizeMB) > 0
        ? Number(cfg.maxUploadSizeMB)
        : 100,
    keyPrefix:
      typeof cfg.keyPrefix === 'string' && cfg.keyPrefix.length > 0
        ? cfg.keyPrefix.replace(/^\/+|\/+$/g, '')
        : 'uploads',
  };
}

/**
 * Sanitize an S3 object key while preserving directory structure.
 *
 * - Drops empty, "." and ".." segments (no path traversal).
 * - Keeps "/" separators; every other unsafe character becomes "_".
 * - Truncates to the 1024-byte S3 key limit.
 * - Ensures the key lives under the configured prefix (default "uploads/").
 *
 * Returns null when nothing usable remains (caller falls back to a
 * generated key).
 */
function sanitizeS3Key(key, keyPrefix = 'uploads') {
  if (typeof key !== 'string' || key.length === 0) return null;

  const prefix = String(keyPrefix).replace(/^\/+|\/+$/g, '') || 'uploads';

  const segments = key
    .split('/')
    .filter((seg) => seg && seg !== '.' && seg !== '..' && !/^\.+$/.test(seg))
    .map((seg) => seg.replace(/[^a-zA-Z0-9._-]+/g, '_').replace(/^_+|_+$/g, ''))
    .filter(Boolean);

  if (segments.length === 0) return null;

  // Truncate to the 1024-char S3 limit, reserving room for the prefix that
  // gets prepended below.
  let body = segments.join('/');
  const needsPrefix = body !== prefix && !body.startsWith(prefix + '/');
  body = body.slice(0, needsPrefix ? 1024 - prefix.length - 1 : 1024);
  if (body === prefix) return null; // bare prefix is not a usable key
  return needsPrefix ? `${prefix}/${body}` : body;
}

/**
 * Build the default storage key for an upload: a timestamp prefix under the
 * configured prefix, which prevents collisions and sorts by upload time.
 */
function defaultUploadKey(filePath, keyPrefix = 'uploads') {
  const prefix = String(keyPrefix).replace(/^\/+|\/+$/g, '') || 'uploads';
  const base = sanitizeFileName(path.basename(filePath));
  return `${prefix}/${Date.now()}-${base}`;
}

/**
 * Make a filename safe for the Content-Disposition header and for display.
 * Strips quotes, backslashes and control characters (header-injection
 * hardening) and falls back to "download" when nothing remains.
 */
function sanitizeFileName(name) {
  const base = path.basename(String(name || ''));
  const clean = base.replace(/["\\\r\n\x00-\x1f\x7f]/g, '').trim();
  return clean || 'download';
}

/**
 * Derive the friendly download filename from a storage key:
 * strip any directory, then strip a leading "<digits>-" timestamp prefix
 * left by defaultUploadKey().
 */
function displayFileName(key) {
  const base = path.basename(String(key || ''));
  return sanitizeFileName(base.replace(/^\d+-/, ''));
}

/**
 * Resolve an expiration in hours to SigV4-safe seconds.
 * Throws on non-positive / non-numeric input; clamps to the 7-day
 * SigV4 maximum instead of letting getSignedUrl fail cryptically.
 */
function resolveExpiresIn(hours) {
  const h = Number(hours);
  if (!Number.isFinite(h) || h <= 0) {
    throw new Error(
      `Invalid expiration hours: ${hours}. Must be a positive number.`
    );
  }
  return Math.min(Math.floor(h * 3600), MAX_EXPIRES_IN_SECONDS);
}

/**
 * Clamp a requested max upload size (MB) to something S3 can accept.
 * Throws on non-positive / non-numeric input.
 */
function resolveMaxSizeMB(mb) {
  const n = Number(mb);
  if (!Number.isFinite(n) || n <= 0) {
    throw new Error(`Invalid max size: ${mb}. Must be a positive number of MB.`);
  }
  return Math.min(n, MAX_POST_SIZE_MB);
}

function getContentType(filename) {
  const ext = path.extname(String(filename || '')).toLowerCase();
  const types = {
    '.zip': 'application/zip',
    '.apk': 'application/vnd.android.package-archive',
    '.pdf': 'application/pdf',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.txt': 'text/plain',
    '.md': 'text/markdown',
    '.csv': 'text/csv',
    '.log': 'text/plain',
    '.json': 'application/json',
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.xml': 'application/xml',
    '.yml': 'text/yaml',
    '.yaml': 'text/yaml',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.gz': 'application/gzip',
    '.tar': 'application/x-tar',
    '.tgz': 'application/gzip',
    '.doc': 'application/msword',
    '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx':
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };
  return types[ext] || 'application/octet-stream';
}

module.exports = {
  MAX_EXPIRES_IN_SECONDS,
  MAX_POST_SIZE_MB,
  loadConfig,
  sanitizeS3Key,
  defaultUploadKey,
  sanitizeFileName,
  displayFileName,
  resolveExpiresIn,
  resolveMaxSizeMB,
  getContentType,
};
