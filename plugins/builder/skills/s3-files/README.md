# s3-files

Agent skill for sharing files through Amazon S3 with time-limited pre-signed
URLs. No bucket ever needs to be public.

Derived from the `s3-files` sample in
[aws-samples/sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock)
(MIT-0), then reviewed for bugs and refactored to the open Agent Skills spec.
See Attribution for the full list of fixes.

## What it does

- `scripts/upload.js` — upload a local file, get a download link
- `scripts/download-url.js` — pre-signed download URL for an object already in S3
- `scripts/generate-upload-page.js` — browser page so someone else can send you files

Files are stored under a timestamp prefix (`uploads/<ts>-name.ext`) to avoid
collisions, while download URLs carry a `Content-Disposition` header so the
browser saves the friendly filename.

## Layout

```
s3-files/
├── SKILL.md                 # the contract: setup, commands, agent guidance
├── README.md                # this file
├── package.json             # deps (@aws-sdk/* v3), npm scripts
├── config.example.json      # copy to config.json and fill in
├── scripts/
│   ├── lib.js               # shared helpers (config, sanitizers, clamps)
│   ├── upload.js
│   ├── download-url.js
│   ├── generate-upload-page.js
│   └── selftest.js          # unit tests for lib.js (no AWS needed)
├── assets/
│   └── upload-page.html     # browser upload page template
├── references/
│   ├── iam-policy.md        # least-privilege IAM policy
│   └── security-notes.md    # security checklist
└── agents/
    └── openai.yaml          # OpenAI agent adaptation notes
```

## Usage

```bash
npm install
cp config.example.json config.json   # set bucketName and region

node scripts/upload.js ./report.pdf
node scripts/download-url.js uploads/1700000000000-report.pdf 48
node scripts/generate-upload-page.js 50
npm test
```

AWS credentials come from the standard SDK chain (env vars,
`~/.aws/credentials`, instance/container role). The IAM policy you need is in
`references/iam-policy.md`.

## Testing

`npm test` runs `scripts/selftest.js` (Node's built-in test runner) against
the pure helpers: key sanitization, path-traversal rejection, expiration
clamping to the SigV4 7-day maximum, upload-size validation, and the MIME map.
No credentials or network required. Live S3 paths are not covered by automated
tests; verify against a real bucket before relying on them.

## Compatibility

Node.js >= 18. AWS credentials with `s3:PutObject` and `s3:GetObject` on the
configured bucket (policy in `references/iam-policy.md`).

## Attribution

### Upstream source

This skill is derived from the `s3-files` skill in
[aws-samples/sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock)
(`skills/s3-files-skill/skills/s3-files/`), which is published under the
MIT-0 license. This derivative is also distributed as MIT-0.

### What was changed in the refactor

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
