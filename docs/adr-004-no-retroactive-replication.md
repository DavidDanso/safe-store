# ADR-004: No Retroactive Replication of Pre-Existing Objects

## Context
S3 replication only kicks in for objects uploaded after the rule is created. Anything already sitting in the bucket before the rule was configured gets ignored — that's just how replication works, not something you can toggle.

## Decision
I didn't backfill any pre-existing objects. No batch job, no script.

## Why
Every file in this project is a synthetic test file uploaded after replication was already running, so there's nothing real to backfill. Adding a backfill workflow — a batch job, a manifest, separate IAM permissions — for a gap that doesn't actually affect this build felt like overengineering. I documented it as a known limitation instead and tested it directly: uploaded a file before replication was configured and confirmed it's absent from the backup bucket. That's more honest than pretending the gap doesn't exist.

## Revisit if
SafeStore ever needs to protect data that already existed before it was deployed. At that point, S3 Batch Operations is the right tool — run a one-time replication job against the existing objects using a manifest.