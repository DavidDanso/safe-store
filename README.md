# SafeStore

SafeStore is a Terraform-built S3 backup and recovery system that makes accidental deletion recoverable in minutes and survives a full regional AWS outage.

## Problem Statement

A developer ran `aws s3 rm --recursive` on the wrong folder. No versioning or backup existed, and the data was permanently lost. SafeStore was built by David Danso (David Danso Cloud Labs) to make that specific failure mode recoverable.

## Architecture

![Architecture](./architecture.svg)
<!-- Note: architecture.svg should be added to the repo root -->

SafeStore provisions infrastructure across two AWS regions: `us-east-1` (primary) and `eu-west-1` (backup).

- **Primary Bucket (`safestore-primary-<account-id>-us-east-1`)**: Deployed in `us-east-1` with versioning enabled, SSE-S3 encryption (AES256) enforced, and all Public Access Block settings enabled.
- **Backup Bucket (`safestore-backup-<account-id>-eu-west-1`)**: Deployed in `eu-west-1` with versioning enabled, SSE-S3 encryption enforced, and Public Access Block settings enabled. Bucket policy denies non-HTTPS requests and blocks `PutObject`, `DeleteObject`, and `DeleteObjectVersion` for all principals except the replication role.
- **Primary Logs Bucket (`safestore-logs-primary-<account-id>-us-east-1`)**: Receives S3 server access logs for the primary bucket in `us-east-1`.
- **Backup Logs Bucket (`safestore-logs-backup-<account-id>-eu-west-1`)**: Receives S3 server access logs for the backup bucket in `eu-west-1`. Two separate log buckets are required because AWS requires access-log delivery to remain in the same region as the source bucket.
- **Replication Flow**: One-way asynchronous Cross-Region Replication (CRR) replicates objects from primary to backup. An IAM role (`safestore-replication-role`) assumed by `s3.amazonaws.com` handles replication.

## What This Does NOT Do

- **Does not backfill existing objects**: Objects uploaded before replication was configured are not automatically replicated to the backup bucket.
- **Does not replicate delete markers**: Deleting an object in the primary bucket creates a delete marker locally, but the deletion does not propagate to the backup bucket.
- **Does not consolidate logs into a single bucket**: AWS restricts S3 server access logging to target buckets in the same region as the source bucket.
- **Does not alert in real time on storage metrics**: CloudWatch reports S3 `BucketSizeBytes` metrics once per day.

## Prerequisites

- AWS CLI installed and configured
- Terraform (AWS provider `hashicorp/aws ~> 6.0`)
- Python 3.x with Boto3 package (`pip install boto3`)
- AWS IAM permissions to create S3 buckets, IAM roles/policies, and CloudWatch alarms

## Setup / Deployment

1. Clone the repository:
```bash
git clone https://github.com/DavidDanso/safe-store.git
cd safestore
```

2. Create a `terraform.tfvars` file in `[terraform/](./terraform)`:
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

4. Run plan to verify resource creation:
```bash
terraform plan
```

5. Apply the infrastructure:
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
/terraform       → all infrastructure code
/scripts          → recover.py, check_replication.py
/docs             → ADR.md (architecture decision records)
architecture.svg  → architecture diagram (add to repo root)
BUILD_LOG.md      → raw log of what broke and how it was fixed
TEST_RESULTS.md   → PRD test case results with evidence
```

- Infrastructure code: `[terraform/](./terraform)`
- Verification scripts: `[scripts/recover.py](./scripts/recover.py)` and `[scripts/check_replication.py](./scripts/check_replication.py)`
- Architecture Decision Records: `[ADR.md](./docs/ADR.md)`
- Build log: `[BUILD_LOG.md](./BUILD_LOG.md)`
- Test results: `[TEST_RESULTS.md](./TEST_RESULTS.md)`

## Usage

### Recovery Verification Script (`scripts/recover.py`)

Run the script to verify deletion recovery:
```bash
python3 scripts/recover.py
```

Script execution sequence:
1. Uploads a test object to the primary bucket.
2. Deletes the object to generate a delete marker.
3. Confirms the object returns a 404/missing status via `head_object`.
4. Queries object versions and locates the current delete marker using `IsLatest`.
5. Deletes the delete marker using its specific `VersionId`.
6. Verifies the object is restored and matches the original size and content.
7. Deletes test object versions to leave the bucket clean.

### Replication Verification Script (`scripts/check_replication.py`)

Run the script to check replication state:
```bash
python3 scripts/check_replication.py
```

Script execution sequence:
1. Uploads a uniquely-named test object to the primary bucket.
2. Polls the backup bucket until the object appears.
3. Checks `ReplicationStatus` metadata on the primary object.
4. Reports pass/fail status.

*(Note: See [Known issues / open items](#known-issues--open-items) regarding current execution status.)*

## Key Design Decisions

| Decision | Selection | Rationale | Record |
|---|---|---|---|
| Delete Marker Replication | Disabled | Prevents an accidental deletion on the primary bucket from wiping the copy on the backup bucket. | `[ADR-001](./docs/ADR.md)` |
| Replication Strategy | Cross-Region Replication (CRR) | Same-Region Replication (SRR) cannot guarantee recovery if the primary AWS region experiences an outage. | `[ADR-002](./docs/ADR.md)` |
| Retroactive Replication | Excluded | S3 replication does not backfill pre-existing objects; backfilling requires separate batch operations. | `[ADR-003](./docs/ADR.md)` |
| Logging Architecture | Two regional log buckets | AWS rules require access logging target buckets to reside in the same region as the source bucket. | `[ADR-004](./docs/ADR.md)` |
| Encryption Provider | SSE-S3 (AES256) | Avoids KMS key management fees and policy overhead since customer key rotation auditing was not required. | N/A |

## Testing

Test details and evidence are recorded in `[TEST_RESULTS.md](./TEST_RESULTS.md)`.

- **Confirmed PASS**: 8 of 10 PRD test cases verified using CLI output, script executions, or console inspection.
- **Unverified Test Cases (2 total)**:
  - Direct verification of SSE-S3 encryption header on a replicated object inside the backup bucket.
  - Direct verification that an object uploaded prior to replication configuration remains absent from the backup bucket.

## Cost

- **Budget Ceiling**: $0.05 total AWS spend.
- **Confirmation**: Verified in AWS Cost Explorer filtered by tag `Project=SafeStore`.

## Teardown

1. Destroy all infrastructure:
```bash
cd terraform
terraform destroy
```

2. Confirm resource destruction:
   - Run `aws s3 ls` to confirm all 5 buckets (`primary`, `backup`, `primary logs`, `backup logs`, and any temporary test buckets) are deleted.
   - Check IAM in AWS Console to confirm `safestore-replication-role` is deleted.
   - Check CloudWatch in `us-east-1` and `eu-west-1` to confirm `BucketSizeBytes` alarms are removed.

## Known Issues / Open Items

- `scripts/check_replication.py` contains a bug where both Boto3 clients default to the same region because `region_name` is not explicitly assigned to the backup client. The script has not yet completed a successful run.
- Two PRD test cases (backup object encryption and no-backfill behavior) are pending direct verification.
- Resource tagging: `Project=SafeStore`, `Environment=test`.

## License

<TODO: add license>
