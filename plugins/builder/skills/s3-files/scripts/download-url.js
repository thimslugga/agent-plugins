#!/usr/bin/env node
'use strict';

// Mint a pre-signed download URL for an object already in S3.
//
//   node download-url.js <s3-key> [expiration-hours]
//
// Programmatic use:
//   const { generateDownloadUrl } = require('./download-url.js');
//   const { url, key, fileName, expiresIn } = await generateDownloadUrl('uploads/123-report.pdf', 24);

const { loadConfig, displayFileName, resolveExpiresIn } = require('./lib');

async function generateDownloadUrl(key, expirationHours, opts = {}) {
  // Required lazily so usage works without `npm install`.
  const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
  const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
  const config = loadConfig();
  const s3Client = new S3Client({ region: config.region });

  if (!key || typeof key !== 'string') {
    throw new Error('An S3 key is required.');
  }

  const hours =
    expirationHours === undefined || expirationHours === null
      ? config.defaultExpirationHours
      : expirationHours;
  const expiresIn = resolveExpiresIn(hours);
  const fileName = displayFileName(key);
  const log = opts.quiet ? () => {} : console.log.bind(console);

  log(`Generating download URL (expires in ${Math.round(expiresIn / 3600)}h)...`);

  // Pass the AWS error through; "Operation failed" tells the caller nothing.
  const url = await getSignedUrl(
    s3Client,
    new GetObjectCommand({
      Bucket: config.bucketName,
      Key: key,
      // Browser downloads with the friendly name, not the storage key.
      ResponseContentDisposition: `attachment; filename="${fileName}"`,
    }),
    { expiresIn }
  ).catch((err) => {
    throw new Error(`Failed to generate download URL for "${key}": ${err.message}`);
  });

  log(`S3 key: ${key}`);
  log(`Download as: ${fileName}`);

  return { url, key, fileName, expiresIn };
}

// CLI usage
if (require.main === module) {
  const key = process.argv[2];
  const hoursArg = process.argv[3];

  if (!key) {
    console.error('Usage: node scripts/download-url.js <s3-key> [expiration-hours]');
    console.error('Note: pre-signed URLs cannot exceed 7 days (168 hours).');
    process.exit(1);
  }

  (async () => {
    try {
      const { url } = await generateDownloadUrl(
        key,
        hoursArg === undefined ? undefined : Number(hoursArg)
      );
      console.log(`\nDownload URL:\n${url}`);
    } catch (err) {
      console.error(`Error: ${err.message}`);
      process.exit(1);
    }
  })();
}

module.exports = { generateDownloadUrl };
