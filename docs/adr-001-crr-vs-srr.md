# ADR-001: Cross-Region Replication (CRR) vs Same-Region Replication (SRR)

## Context
SafeStore's whole purpose is surviving a regional AWS outage. I had to decide
whether to keep the backup in the same region or replicate it to a completely
separate one.

## Decision
I went with Cross-Region Replication — primary in us-east-1, backup in eu-west-1.

## Why
SRR keeps both copies inside the same AWS region. If that region goes down,
primary and backup go down together, which defeats the point of having a backup
at all. CRR puts the backup in a separate geography so a single regional failure
can't take out both at once.

## Revisit if
A data sovereignty requirement forces everything to stay in one region, or
cross-region transfer costs become a real concern at higher data volumes.