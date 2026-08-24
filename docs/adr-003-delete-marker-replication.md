# ADR-003: Delete Marker Replication

## Context
When you delete a versioned S3 object without specifying a version ID, S3 creates a delete marker rather than permanently removing anything. I had to decide whether those delete markers should replicate to the backup bucket.

## Decision
I disabled delete marker replication.

## Why
The backup bucket exists to be an independent recovery copy. If delete markers replicate, accidentally running `aws s3 rm --recursive` on the primary bucket causes the same deletion to appear in backup automatically. The backup stops being a safety net and starts mirroring the mistake. Keeping delete markers off replication means backup stays intact even if primary gets wiped.

## Revisit if
I need both regions to stay in exact sync including deletions, and there are other controls in place that prevent accidental mass deletes from hitting primary in the first place.