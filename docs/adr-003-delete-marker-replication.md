# ADR-003: Delete Marker Replication

## Context
When an object is deleted from a versioned bucket without specifying a version ID, S3 creates a delete marker. We must determine whether these delete markers should be replicated to the backup bucket, which impacts how file deletions and recovery behave across regions.

## Decision
We decided to disable Delete Marker Replication in the replication configuration of the primary bucket.

## Why
Disabling delete marker replication ensures that if an object is accidentally deleted in the primary bucket, the deletion is not mirrored to the backup bucket. This maintains the backup bucket as a more secure, independent recovery safety net, preventing accidental deletions from propagating across regions and protecting against destructive actions or operational mistakes.

## Revisit if
We would change this decision if our operational workflows require strict real-time synchronization of the active file list between regions, and the risk of accidental deletion propagation is mitigated by other controls.
