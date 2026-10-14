# s3-files

Agent skill for sharing files through Amazon S3 with time-limited pre-signed
URLs. No bucket ever needs to be public.

Derived from the `s3-files` sample in
[aws-samples/sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock)
(MIT-0), then reviewed for bugs and refactored to the open Agent Skills spec.
See `ATTRIBUTION.md` for the full list of fixes.

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
├── ATTRIBUTION.md           # upstream source and what changed
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
