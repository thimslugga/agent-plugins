# Attribution

## Upstream source

This skill is derived from the `s3-files` skill in
[aws-samples/sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock)
(`skills/s3-files-skill/skills/s3-files/`), which is published under the
MIT-0 license. This derivative is also distributed as MIT-0.

## What was changed in the refactor

Bugs fixed:

- `SKILL.md` used a Markdown table where YAML frontmatter belongs, so no
  skill loader could parse it. Replaced with valid frontmatter.
- `sanitizeS3Key` stripped `/` before checking `startsWith('uploads/')`,
  so the documented custom-key example produced `uploads/uploads_custom-name.pdf`.
  The sanitizer now preserves directory structure and only strips unsafe
  characters per path segment.
- Default-path filenames were used raw in the S3 key and flowed unsanitized
  into the `Content-Disposition` header (quote/backslash header-injection
  risk). Filenames are now sanitized for both.
- `config.maxUploadSizeMB` was ignored by `upload.js` (hardcoded 100 MB).
  It now drives the upload limit.
- AWS errors were swallowed and rethrown as "Upload operation failed" /
  "Operation failed", hiding the actionable service message. Errors now
  carry the original message.
- The "built-in rate limiter" was per-process memory, so it could never fire
  for the documented CLI usage. Removed; the false claim is gone from the docs.
- Expiration hours were not validated and could exceed the SigV4 7-day
  maximum, producing a cryptic SDK failure. Now validated and clamped.
- The upload page used one fixed S3 key, so concurrent uploads overwrote
  each other. Each upload now gets a unique key under a per-page prefix via a
  `starts-with` POST policy condition.
- `GetObjectCommand` was imported twice in `generate-upload-page.js`.
- Missing `config.json` crashed with a raw `MODULE_NOT_FOUND`. Now fails fast
  with instructions.

Improvements:

- Spec layout: executables moved to `scripts/`, page template moved to
  `assets/upload-page.html`, IAM and security guidance moved to `references/`.
- Added `scripts/lib.js` shared helpers, `scripts/selftest.js` unit tests
  (`npm test`), root `README.md`, and `agents/openai.yaml`.
- Uploads stream the file body instead of buffering up to 100 MB in memory.
- Upload pages and their keys live under the configured `keyPrefix`.
- `ContentDisposition` on upload includes the filename, so plain GETs also
  download with the friendly name.
- MIME map expanded (video, archives, office formats, markdown, csv...).
- `S3_FILES_CONFIG` env var allows an alternate config path.
- OpenClaw-specific install paths and rules generalized for any agent.
