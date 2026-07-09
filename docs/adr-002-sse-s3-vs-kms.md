# ADR-002: SSE-S3 vs SSE-KMS for Server-Side Encryption

## Context
All data stored in SafeStore must be encrypted at rest. We must decide between Amazon S3-managed keys (SSE-S3) and AWS KMS-managed keys (SSE-KMS) to meet our security requirements while minimizing operational overhead and KMS costs.

## Decision
We decided to use Amazon S3-managed encryption keys (SSE-S3) as the default encryption mechanism for all three buckets.

## Why
SSE-S3 provides strong AES-256 encryption at rest without the additional complexity, policy management, and per-request costs associated with AWS Key Management Service (KMS). Since our recovery and validation scripts run in simple automated environments, avoiding cross-account and cross-region KMS key sharing reduces potential points of failure and access control complexity.

## Revisit if
We would change this decision if security policies change to require customer-managed keys (CMKs) with custom key rotation schedules, or if envelope encryption with fine-grained KMS key policies becomes a mandatory compliance requirement.
