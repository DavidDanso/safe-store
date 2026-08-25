# SafeStore

SafeStore is a Terraform-built S3 backup and recovery system that makes accidental deletion recoverable in minutes and survives a full regional AWS outage.

## Contents

- [Problem Statement](#problem-statement)
- [Architecture](#architecture)
- [What This Does NOT Do](#what-this-does-not-do)
- [Prerequisites](#prerequisites)
- [Setup / Deployment](#setup--deployment)
- [Repository Structure](#repository-structure)
- [Usage](#usage)
- [Key Design Decisions](#key-design-decisions)
- [Testing](#testing)
- [Cost](#cost)
- [Teardown](#teardown)

## Problem Statement

A developer ran `aws s3 rm --recursive` on the wrong folder. No versioning or backup existed, and the data was permanently lost. SafeStore was built by David Danso (David Danso Cloud Labs) to make that specific failure mode recoverable.

## Architecture

<table width="100%"> 
  <tr>
    <td width="100%">        
    <img src="https://github.com/DavidDanso/safe-store/blob/main/docs/architecture.png?raw=true" />
    </td> 
  </tr>
</table>

SafeStore provisions infrastructure across two AWS regions: `us-east-1` (primary) and `eu-west-1` (backup).

- **Primary Bucket** (`safestore-primary-<account-id>-us-east-1`): versioning enabled, SSE-S3 encryption (AES256) enforced, all Public Access Block settings enabled.
- **Backup Bucket** (`safestore-backup-<account-id>-eu-west-1`): versioning enabled, SSE-S3 encryption enforced, Public Access Block enabled. Bucket policy denies non-HTTPS requests and blocks `PutObject`, `DeleteObject`, and `DeleteObjectVersion` for all principals except the replication role.
- **Primary Logs Bucket** (`safestore-logs-primary-<account-id>-us-east-1`): receives S3 server access logs for the primary bucket.
- **Backup Logs Bucket** (`safestore-logs-backup-<account-id>-eu-west-1`): receives S3 server access logs for the backup bucket. Two separate log buckets are required because AWS requires access-log delivery to remain in the same region as the source bucket.
- **Replication**: one-way asynchronous Cross-Region Replication (CRR) from primary to backup, authorized by a dedicated IAM role (`safestore-replication-role`) that only `s3.amazonaws.com` can assume.
- **Lifecycle Management**: primary and backup automatically expire noncurrent versions after 30 days and clean up delete markers once nothing is left beneath them. Both logs buckets expire objects after 90 days. Nothing accumulates indefinitely.
- **Monitoring**: a CloudWatch alarm watches `BucketSizeBytes` on primary, and — beyond what was originally required — a second alarm watches backup too, since delete markers aren't replicated and backup can grow independently of primary over time. This metric is reported by AWS once per day, not continuously.

## What This Does NOT Do

- **Does not backfill existing objects** — objects uploaded before replication was configured are not automatically replicated to backup.
- **Does not replicate delete markers** — deleting an object in primary creates a delete marker locally; that deletion does not propagate to backup.
- **Does not consolidate logs into a single bucket** — AWS requires access-log target buckets to be in the same region as the source bucket.
- **Does not alert in real time** — CloudWatch reports S3 `BucketSizeBytes` once per day, not continuously.

## Prerequisites

- AWS account with access to `us-east-1` and `eu-west-1`
- A dedicated IAM user for deployment — not root — with MFA enabled
- AWS CLI installed and configured
- Terraform (AWS provider `hashicorp/aws ~> 6.0`)
- Python 3.x with Boto3 (`pip install boto3`)
- IAM permissions to create S3 buckets, IAM roles/policies, and CloudWatch alarms

## Setup / Deployment

1. Clone the repository:
```bash
git clone https://github.com/DavidDanso/safe-store.git
cd safestore
```

2. Create a `terraform.tfvars` file in [`terraform/`](./terraform):
```hcl
account_id         = "YOUR_ACCOUNT_ID_HERE"
primary_region     = "us-east-1"
backup_region      = "eu-west-1"
alarm_threshold_gb = 1
```

3. Initialize Terraform:
```bash
cd terraform
terraform init
```

4. Review the plan:
```bash
terraform plan
```

5. Apply:
```bash
terraform apply
```

6. Run the verification scripts:
```bash
python3 ../scripts/recover.py
python3 ../scripts/check_replication.py
```

## Repository Structure

```
/terraform        → all infrastructure code
/scripts          → recover.py, check_replication.py
/docs             → ADR.md (architecture decision records)
BUILD_LOG.md      → raw log of what broke and how I fixed it
TEST_RESULTS.md   → Test case results with evidence
```

## Usage

### Recovery Verification — [`scripts/recover.py`](./scripts/recover.py)

```bash
python3 scripts/recover.py
```

1. Uploads a test object to the primary bucket.
2. Deletes the object, creating a delete marker.
3. Confirms the object returns 404 via `head_object`.
4. Finds the current delete marker via `IsLatest`.
5. Deletes the delete marker by its `VersionId`, restoring the object.
6. Verifies the restored object matches the original size and content.
7. Cleans up test versions, leaving the bucket clean.

### Replication Verification — [`scripts/check_replication.py`](./scripts/check_replication.py)

```bash
python3 scripts/check_replication.py
```

1. Uploads a uniquely-named test object to primary.
2. Polls the backup bucket until the object appears.
3. Checks `ReplicationStatus` metadata on the primary object.
4. Reports pass/fail.

## Key Design Decisions

| Decision | Selection | Rationale |
|---|---|---|
| Delete Marker Replication | Disabled | Prevents an accidental deletion on primary from also wiping the backup copy. |
| Replication Strategy | Cross-Region Replication (CRR) | Same-Region Replication can't guarantee recovery if the primary region has an outage. |
| Retroactive Replication | Excluded | S3 replication doesn't backfill pre-existing objects by default; that requires a separate batch operation. |
| Logging Architecture | Two regional log buckets | AWS requires access-log target buckets to be in the same region as the source bucket. |
| Encryption Provider | SSE-S3 (AES256) | Avoids KMS key management cost and overhead; no requirement here for key rotation control or usage auditing. |
| Storage Monitoring | Alarm on both primary and backup | Delete markers aren't replicated, so backup can diverge in size from primary over time — primary-only monitoring could miss abnormal growth specific to backup. |

## Testing

Full evidence recorded in [TEST_RESULTS.md](./TEST_RESULTS.md). Day-by-day build history — real errors and how they were fixed — is in [BUILD_LOG.md](./BUILD_LOG.md).

## Cost

- Budget ceiling: **$0.05** total AWS spend.
- Confirmed via Cost Explorer, filtered by tag `Project=SafeStore`.

## Teardown

No KMS key exists in this project, so there's no ongoing charge either way — safe to leave running for demos or tear down immediately.

1. Destroy all infrastructure:
```bash
cd terraform
terraform destroy
```

2. Confirm nothing was left behind:
   - `aws s3 ls` — confirm all 4 buckets (primary, backup, primary logs, backup logs) are gone.
   - IAM console — confirm `safestore-replication-role` is gone.
   - CloudWatch, in both `us-east-1` and `eu-west-1` — confirm the `BucketSizeBytes` alarms are gone.


## Author
David Danso - Initial work - [GitHub Profile](https://github.com/DavidDanso)

##### Email: davidkellybrownson@gmail.com

### Happy Coding!