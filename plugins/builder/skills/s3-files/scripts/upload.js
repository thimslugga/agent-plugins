#!/usr/bin/env node
'use strict';

// Upload a local file to S3 and mint a pre-signed download URL.
//
//   node upload.js <file-path> [s3-key]
//
// Programmatic use:
//   const { uploadFile } = require('./upload.js');
//   const { key, downloadUrl, fileName, sizeBytes } = await uploadFile('/tmp/a.pdf');

const fs = require('fs');
const path = require('path');
const {
  loadConfig,
  sanitizeS3Key,
  defaultUploadKey,
  sanitizeFileName,
  getContentType,
} = require('./lib');
const { generateDownloadUrl } = require('./download-url.js');

async function uploadFile(filePath, s3Key) {
  // Required lazily so `--help`/usage works without `npm install`.
  const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
  const config = loadConfig();
  const s3Client = new S3Client({ region: config.region });

  if (!filePath || typeof filePath !== 'string') {
    throw new Error('A file path is required.');
  }
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  const stats = fs.statSync(filePath);
  if (!stats.isFile()) {
    throw new Error(`Not a regular file: ${filePath}`);
  }

  const maxBytes = config.maxUploadSizeMB * 1024 * 1024;
  if (stats.size > maxBytes) {
    throw new Error(
      `File is ${(stats.size / 1048576).toFixed(2)} MB; ` +
        `the configured limit is ${config.maxUploadSizeMB} MB ` +
        `(maxUploadSizeMB in config.json).`
    );
  }

  const fileName = sanitizeFileName(path.basename(filePath));
  const key =
    sanitizeS3Key(s3Key, config.keyPrefix) || defaultUploadKey(filePath, config.keyPrefix);

  // Stream the body instead of buffering the whole file in memory.
  await s3Client.send(
    new PutObjectCommand({
      Bucket: config.bucketName,
      Key: key,
      Body: fs.createReadStream(filePath),
      ContentType: getContentType(fileName),
      ContentLength: stats.size,
      ContentDisposition: `attachment; filename="${fileName}"`,
    })
  );

  // Keep the failure message; callers need the AWS reason (AccessDenied,
  // NoSuchBucket, ...) to troubleshoot.
  let downloadUrl;
  try {
    downloadUrl = (
      await generateDownloadUrl(key, config.defaultExpirationHours, {
        quiet: true,
      })
    ).url;
  } catch (err) {
    throw new Error(
      `Upload succeeded (key: ${key}) but generating the download URL failed: ${err.message}`
    );
  }

  return { key, downloadUrl, fileName, sizeBytes: stats.size };
}

// CLI usage
if (require.main === module) {
  const filePath = process.argv[2];
  const s3Key = process.argv[3];

  if (!filePath) {
    console.error('Usage: node scripts/upload.js <file-path> [s3-key]');
    process.exit(1);
  }

  (async () => {
    try {
      const config = loadConfig();
      console.log(`Uploading ${path.basename(filePath)}...`);
      const { key, downloadUrl, fileName, sizeBytes } = await uploadFile(
        filePath,
        s3Key
      );
      console.log('Upload complete!');
      console.log(`S3 key: ${key} (${(sizeBytes / 1024).toFixed(2)} KB)`);
      console.log(`Download as: ${fileName}`);
      console.log(
        `Download URL (${config.defaultExpirationHours}h):\n${downloadUrl}`
      );
    } catch (err) {
      console.error(`Error: ${err.message}`);
      process.exit(1);
    }
  })();
}

module.exports = { uploadFile };
