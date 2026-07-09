# ADR-003: Delete Marker Replication

## Context
When an object is deleted from a versioned bucket without specifying a version ID, S3 creates a delete marker. We must determine whether these delete markers should be replicated to the backup bucket, which impacts how file deletions and recovery behave across regions.

## Decision
We decided to enable Delete Marker Replication in the replication configuration of the primary bucket.

## Why
Enabling delete marker replication ensures that standard deletes on the primary bucket are mirrored in the backup bucket, keeping the active views of both buckets synchronized. Without delete marker replication, a file deleted in the primary bucket would remain visible in the backup bucket, causing drift between the primary and recovery states.

## Revisit if
We would change this decision if our compliance rules require the backup bucket to act as an append-only archive where deletes are never mirrored under any circumstances.
