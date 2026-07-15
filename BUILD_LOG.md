# Build Log
Log of all terraform runs and deployment activities.


## Day 1 — Primary Bucket

- Plain-HTTP PutObject test: failed first try, `Resource` in EnforceHTTPS policy was missing the `/*` object ARN. Fixed by adding both bucket and object ARNs.
- Encryption header deny test: passed first try.
- Confirmed SSE-S3 via `head-object` — `ServerSideEncryption: AES256`.

## Day 2 — Backup Bucket, Replication & IAM Role

- Replication configuration: failed first try — `InvalidRequest: DeleteMarkerReplication must be specified for this version of Cross Region Replication configuration schema`. AWS's replication API requires this field explicitly, even to turn it off. Fixed by adding `delete_marker_replication { status = "Disabled" }` to the rule block — matches ADR-001 (delete markers not replicated), now stated explicitly instead of implied.
- Backup bucket logging: failed first try — `CrossLocationLoggingProhibitted: Cross S3 location logging not allowed`. S3 requires the logs bucket to be in the same region as the bucket it's logging. Original design used one logs bucket in the primary region for both primary and backup — doesn't work cross-region.
  - Decision: added a second logs bucket (`safestore_logs_backup`), deployed in the backup region via `provider = aws.backup`, with its own encryption, public access block, and policy (mirrors the primary logs bucket pattern). Backup's `aws_s3_bucket_logging` resource repointed to this new bucket. See ADR-004.
- Replication configuration: failed second time (different error) — `MissingRequestBodyError: Request Body is empty`. Root cause: Terraform's automatic dependency graph didn't wait for both buckets' versioning to be fully settled on AWS's side before sending the replication config, since bucket, versioning, and replication were all being created in the same apply. Fixed by adding an explicit `depends_on = [aws_s3_bucket_versioning.safestore_primary, aws_s3_bucket_versioning.safestore_backup]` to the replication resource, forcing correct ordering.
- Linked primary bucket to backup bucket via `aws_s3_bucket_replication_configuration`, using the IAM replication role built in `iam.tf`. Role/policy/attachment required to exist first — dependency confirmed correct, no changes needed there.
- `terraform apply` succeeded after the `depends_on` fix. Both errors caught and resolved at `apply` time, no partial/broken state left behind.

## Day 3 — Logging & Lifecycle Policies, Verification

