# ADR-001: Cross-Region Replication (CRR) vs Same-Region Replication (SRR)

## Context
We need to ensure that data stored in SafeStore is resilient to regional AWS outages and meets strict disaster recovery (DR) requirements for geographic redundancy. Same-Region Replication (SRR) only replicates data within the same region, leaving it vulnerable to region-wide failures.

## Decision
We decided to implement S3 Cross-Region Replication (CRR) to replicate data from the primary region to a geographically distinct backup region.

## Why
CRR provides compliance with disaster recovery regulations by guaranteeing that a copy of the data exists in a separate geographic location. This protects the data against regional failures, catastrophic events, and local compliance requirements. It also ensures lower-latency access to backups for users located in or near the backup region.

## Revisit if
We would change this decision if regulatory requirements change to prohibit data sovereignty transfer outside of the primary region, or if data transfer costs between regions become prohibitively expensive relative to the risk.
