# ADR-002: SSE-S3 vs SSE-KMS for Server-Side Encryption

## Context
All objects in SafeStore need to be encrypted at rest. The choice was between letting S3 manage the key (SSE-S3) or managing my own key through KMS (SSE-KMS).

## Decision
I went with SSE-S3 on all four buckets.

## Why
SSE-S3 gives me AES-256 encryption at rest with no key management overhead and no per-request KMS charges. I don't have a requirement here for custom key rotation schedules or CloudTrail-level visibility into key usage. Adding KMS would add cost and complexity without solving any actual problem SafeStore has.

## Revisit if
A compliance requirement comes in that mandates customer-managed keys with controlled rotation, or I need audit logs showing exactly who accessed which encryption key and when.