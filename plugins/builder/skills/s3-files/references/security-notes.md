# Security notes for s3-files

## Bucket baseline

- Keep Block Public Access on. Nothing in this skill needs a public bucket.
- Enable versioning if overwrites must be recoverable (note: the skill writes
  unique keys by default, so overwrites should be rare).
- Add a lifecycle rule to expire shared files, e.g. delete objects under
  `uploads/` after 30 days. Without one, shared files accumulate silently.
- Server-side encryption (SSE-S3 or SSE-KMS) is orthogonal to pre-signed
  URLs and recommended for anything sensitive.

## Upload pages are bearer capabilities

`generate-upload-page.js` embeds pre-signed POST credentials valid for 1
hour. Anyone with the page URL can upload arbitrary file types up to the size
limit during that window. Treat the URL like a password:

- Only generate a page on explicit request.
- Share it through a private channel, not a public link.
- The 1-hour credential window bounds exposure; the 24-hour page URL only
  serves the (by then inert) page after that.

The POST policy constrains uploads to the page's unique key prefix and the
size limit, but does not restrict content type. If you need type restrictions,
add a `["starts-with", "$Content-Type", ...]` condition in
`scripts/generate-upload-page.js`.

## Pre-signed download URLs

- URLs are unguessable but bearer: anyone with the link can download until it
  expires. Default 24 hours; keep lifetimes as short as the use case allows.
- Filenames placed in `Content-Disposition` are sanitized (quotes,
  backslashes, and control characters stripped) to prevent header injection.

## What the skill does not do

- No rate limiting. The upstream sample claimed a built-in limiter, but it
  was per-process state that could never fire for CLI use, so it was removed
  rather than kept as a false promise. If you need abuse protection, enforce
  it at the caller or with bucket policies.
- No malware scanning of uploaded files. Do not pipe untrusted uploads into
  automated processing without scanning.
- No audit trail beyond S3 server access logging; enable it on the bucket if
  you need to know who downloaded what.
