# ADR-005: Two Logs Buckets, One Per Region

## Context
I originally planned to route access logs from both the primary and backup buckets into one logs bucket sitting in us-east-1. When I applied that config, it failed with CrossLocationLoggingProhibited. Turns out AWS requires the logging destination to be in the same region as the bucket being logged — you can't cross regions.

## Decision
I added a second logs bucket in eu-west-1 specifically for backup's access logs. Primary still logs to the bucket in us-east-1.

## Why
I could've just dropped logging on the backup bucket — it's a SHOULD in the requirements, not a MUST. But having zero visibility on backup access didn't sit right with me. A second bucket costs nothing at this scale, both buckets stay properly monitored, and it matches what AWS actually allows instead of trying to work around it. That's also what I'd do in a real production setup.

## Revisit if
AWS ever supports cross-region log delivery natively. At that point, consolidating back to one logs bucket would be a straightforward cleanup.