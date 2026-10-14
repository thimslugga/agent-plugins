---
name: s3-files
description: Share files through Amazon S3 without public buckets. Upload a local file and get a time-limited download link, mint pre-signed download URLs for objects already in S3, or generate a browser upload page so someone else can send you a file.
license: MIT-0
compatibility: Node.js >= 18; AWS credentials with s3:PutObject and s3:GetObject on the configured bucket
metadata:
  upstream: aws-samples/sample-OpenClaw-on-AWS-with-Bedrock (skills/s3-files-skill), refactored
  version: "1.0.0"
---

# s3-files

Upload files to Amazon S3 and share them with time-limited pre-signed URLs.
No bucket ever needs to be public.

## Setup

```bash
cd <skill-dir>
npm install
cp config.example.json config.json   # then set bucketName and region
```

AWS credentials come from the standard SDK chain (environment variables,
`~/.aws/credentials`, or instance/container role). The IAM policy you need is
in `references/iam-policy.md`.

If `config.json` is missing or incomplete, every script fails fast with a
plain-English message telling you what to fix. `S3_FILES_CONFIG` can point at
an alternate config file.

## Quick reference

| Command | Purpose |
| --- | --- |
| `node scripts/upload.js <file-path> [s3-key]` | Upload a file, get a download link |
| `node scripts/download-url.js <s3-key> [hours]` | Pre-signed URL for an object already in S3 |
| `node scripts/generate-upload-page.js [max-size-mb]` | Browser page so others can send you files |

## Upload a file

```bash
node scripts/upload.js /path/to/report.pdf
```

Output: the S3 key, the friendly download filename, and a download URL that
expires after `defaultExpirationHours` (default 24).

Files are stored under a timestamp prefix (`uploads/1700000000000-report.pdf`)
so uploads never collide, and the download URL carries a `Content-Disposition`
header so the browser saves it as `report.pdf` (no timestamp visible).

Give an explicit key to control the layout: `node scripts/upload.js a.pdf
reports/q1/a.pdf`. Keys are sanitized (no `..` segments, unsafe characters
become `_`) and always kept under the configured `keyPrefix`.

## Generate a download URL

```bash
node scripts/download-url.js uploads/1700000000000-report.pdf 48
```

`hours` is optional (default from config). Pre-signed URLs cannot outlive 7
days; larger values are clamped to that SigV4 limit instead of failing
cryptically.

## Create an upload page

```bash
node scripts/generate-upload-page.js 50   # allow up to 50 MB per file
```

Prints a page URL (valid 24h). Anyone opening it can upload files straight to
your bucket through pre-signed POST credentials embedded in the page (valid 1
hour). Every upload gets a unique key under `uploads/incoming-<page-id>/`, so
two people uploading at once never overwrite each other.

Only generate a page when asked: the URL is a bearer capability, anyone who
has it can upload. See `references/security-notes.md`.

## Programmatic use

```js
const { uploadFile } = require('./scripts/upload.js');
const { generateDownloadUrl } = require('./scripts/download-url.js');
const { generateUploadPage } = require('./scripts/generate-upload-page.js');

const { key, downloadUrl } = await uploadFile('/path/to/file.pdf');
const { url } = await generateDownloadUrl(key, 24);
const { pageUrl } = await generateUploadPage(100);
```

Library functions are quiet and return data (`{ url, key, fileName,
expiresIn }` etc.); the CLI wrappers print human-readable output. Pass
`{ quiet: true }` as the last argument to silence even the library.

## Configuration

`config.json` (see `config.example.json`):

```json
{
  "bucketName": "your-bucket-name",
  "region": "us-east-1",
  "defaultExpirationHours": 24,
  "maxUploadSizeMB": 100,
  "keyPrefix": "uploads"
}
```

`maxUploadSizeMB` applies to both direct uploads and upload pages
(`generate-upload-page.js [max-size-mb]` overrides it per page, capped at the
5 GB S3 POST limit).

## Tests

`npm test` runs the unit tests for the key sanitizer, filename handling,
expiration clamping, and MIME map. They need no AWS credentials.

## Agent guidance

1. Confirm before uploading: state the file path, destination bucket, and how
   long the link will live.
2. Remind the recipient that links expire; never promise a permanent URL.
3. Only create upload pages on explicit request, and say the page lets anyone
   with the URL upload files for one hour.
4. Suggest a bucket lifecycle rule so shared files do not accumulate forever
   (`references/security-notes.md` has the checklist).
5. If a script reports an AWS error, it includes the service message
   (AccessDenied, NoSuchBucket, ...). Use it; do not guess.

## Troubleshooting

- `config.json not found` — copy `config.example.json` to `config.json` and
  fill in `bucketName`/`region`.
- `AccessDenied` — the credentials lack `s3:PutObject`/`s3:GetObject` on the
  bucket; compare against `references/iam-policy.md`.
- `NoSuchBucket` — wrong bucket name or region in `config.json`.
- Upload page loads but uploads fail — the embedded credentials expired after
  1 hour; regenerate the page.
- A download URL 403s — it expired, or the object was deleted/lifecycle-aged.

## Cost notes (us-east-1, approximate)

Storage ~$0.023/GB/month, PUTs ~$0.005/1000, GETs ~$0.0004/1000, first 100
GB/month of transfer out free. A few hundred shared files a month lands well
under $1. Lifecycle rules keep storage from growing silently.
