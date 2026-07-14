# Build Log

Log of all terraform runs and deployment activities.


## Day 1 — Primary Bucket

- Plain-HTTP PutObject test: failed first try, `Resource` in EnforceHTTPS policy was missing the `/*` object ARN. Fixed by adding both bucket and object ARNs.
- Encryption header deny test: passed first try.
- Confirmed SSE-S3 via `head-object` — `ServerSideEncryption: AES256`.