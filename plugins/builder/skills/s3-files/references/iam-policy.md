# Least-privilege IAM policy for s3-files

The skill only needs `PutObject` (uploads, upload pages) and `GetObject`
(presigned downloads are signed with these credentials; the URL holder needs
no IAM identity). Scope both to the single bucket. Replace
`YOUR-BUCKET-NAME` with the `bucketName` from `config.json`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
    }
  ]
}
```

Notes:

- No `s3:ListBucket`, `s3:DeleteObject`, or bucket-policy writes are needed.
- Do not use root credentials. A dedicated IAM user or role for file sharing
  keeps the blast radius small.
- The pre-signed URLs themselves enforce expiry; IAM cannot shorten a URL's
  lifetime below what was requested, but revoking or rotating the signing
  credentials invalidates outstanding URLs early.
