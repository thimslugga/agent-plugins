#!/usr/bin/env node
'use strict';

// Create a browser upload page so someone else can send you a file.
//
//   node generate-upload-page.js [max-size-mb]
//
// The page embeds pre-signed POST credentials (valid 1 hour). Each file
// uploaded through the page lands under a unique key, so multiple uploads
// never overwrite each other.
//
// Programmatic use:
//   const { generateUploadPage } = require('./generate-upload-page.js');
//   const { pageUrl, pageKey, keyPrefix } = await generateUploadPage(50);

const fs = require('fs');
const path = require('path');
const { loadConfig, resolveMaxSizeMB } = require('./lib');

// Upload credentials embedded in the page are valid for 1 hour;
// the page URL itself is valid for 24 hours.
const POST_EXPIRES_SECONDS = 3600;
const PAGE_URL_EXPIRES_SECONDS = 24 * 3600;

async function generateUploadPage(maxSizeMB, opts = {}) {
  // Required lazily so usage works without `npm install`.
  const {
    S3Client,
    PutObjectCommand,
    GetObjectCommand,
  } = require('@aws-sdk/client-s3');
  const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
  const { createPresignedPost } = require('@aws-sdk/s3-presigned-post');
  const config = loadConfig();
  const s3Client = new S3Client({ region: config.region });
  const log = opts.quiet ? () => {} : console.log.bind(console);

  const maxSize =
    maxSizeMB === undefined || maxSizeMB === null
      ? config.maxUploadSizeMB
      : resolveMaxSizeMB(maxSizeMB);

  // One prefix per page; the browser mints a unique key per upload under it.
  const keyPrefix = `${config.keyPrefix}/incoming-${Date.now()}/`;

  log(`Max file size: ${maxSize} MB`);
  log(`Upload credentials valid for 1 hour; page URL valid for 24 hours.`);

  const { url, fields } = await createPresignedPost(s3Client, {
    Bucket: config.bucketName,
    // The "$key" placeholder is required by createPresignedPost; the real
    // constraint is the starts-with condition below, and the page's JS sets
    // a unique key per upload.
    Key: `${keyPrefix}\${filename}`,
    Conditions: [
      ['starts-with', '$key', keyPrefix],
      ['content-length-range', 0, maxSize * 1024 * 1024],
    ],
    Expires: POST_EXPIRES_SECONDS,
  }).catch((err) => {
    throw new Error(`Failed to create upload credentials: ${err.message}`);
  });

  const templatePath = path.join(__dirname, '..', 'assets', 'upload-page.html');
  const html = fs
    .readFileSync(templatePath, 'utf8')
    .replace('__UPLOAD_URL__', JSON.stringify(url))
    .replace('__UPLOAD_FIELDS__', JSON.stringify(fields))
    .replace('__KEY_PREFIX__', JSON.stringify(keyPrefix))
    .replace('__MAX_SIZE__', String(maxSize));

  const pageKey = `${config.keyPrefix}/upload-page-${Date.now()}.html`;
  await s3Client
    .send(
      new PutObjectCommand({
        Bucket: config.bucketName,
        Key: pageKey,
        Body: html,
        ContentType: 'text/html',
      })
    )
    .catch((err) => {
      throw new Error(`Failed to store the upload page: ${err.message}`);
    });

  const pageUrl = await getSignedUrl(
    s3Client,
    new GetObjectCommand({ Bucket: config.bucketName, Key: pageKey }),
    { expiresIn: PAGE_URL_EXPIRES_SECONDS }
  ).catch((err) => {
    throw new Error(`Failed to sign the page URL: ${err.message}`);
  });

  log(`\nUpload page ready:`);
  log(`Page URL (24h): ${pageUrl}`);
  log(`Files will land under: ${keyPrefix}`);

  return { pageUrl, pageKey, keyPrefix };
}

// CLI usage
if (require.main === module) {
  const maxSizeArg = process.argv[2];

  (async () => {
    try {
      await generateUploadPage(
        maxSizeArg === undefined ? undefined : Number(maxSizeArg)
      );
    } catch (err) {
      console.error(`Error: ${err.message}`);
      process.exit(1);
    }
  })();
}

module.exports = { generateUploadPage };
