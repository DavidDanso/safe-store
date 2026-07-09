import sys
import time
import uuid
import boto3
from botocore.exceptions import ClientError

# Configuration - Populate from terraform output primary_bucket_name and backup_bucket_name
PRIMARY_BUCKET_NAME = "safestore-primary-123456789012-us-east-1"
BACKUP_BUCKET_NAME = "safestore-backup-123456789012-eu-west-1"

# Generate a uniquely named test file
KEY_NAME = f"replication_test_{uuid.uuid4().hex}.txt"
FILE_CONTENT = b"SafeStore replication verification content"

MAX_RETRIES = 30
SLEEP_SECONDS = 5

def test_replication():
    # S3 clients for primary and backup regions
    s3_primary = boto3.client('s3')
    s3_backup = boto3.client('s3')

    print("Starting replication test.")
    print(f"Primary Bucket: {PRIMARY_BUCKET_NAME}")
    print(f"Backup Bucket:  {BACKUP_BUCKET_NAME}")
    print(f"Test Key:       {KEY_NAME}")

    # 1. Upload a uniquely named test file to primary
    print("\n1. Uploading test file to primary bucket...")
    try:
        s3_primary.put_object(
            Bucket=PRIMARY_BUCKET_NAME,
            Key=KEY_NAME,
            Body=FILE_CONTENT
        )
        print("Upload to primary successful.")
    except ClientError as e:
        print(f"Error: Failed to upload to primary. Details: {e}")
        sys.exit(1)

    # 2. Poll the backup bucket with retries and a short sleep between each
    print(f"\n2. Polling backup bucket for replicated file (max {MAX_RETRIES} retries)...")
    replicated = False

    for i in range(1, MAX_RETRIES + 1):
        print(f"Attempt {i}/{MAX_RETRIES}: Checking backup bucket...")
        # 3. On each poll, call head_object on the backup bucket for that key
        try:
            s3_backup.head_object(Bucket=BACKUP_BUCKET_NAME, Key=KEY_NAME)
            print("Found: File has replicated to the backup bucket!")
            replicated = True
            break
        except ClientError as e:
            if e.response['ResponseMetadata']['HTTPStatusCode'] == 404:
                print(f"File not found yet. Sleeping for {SLEEP_SECONDS} seconds...")
                time.sleep(SLEEP_SECONDS)
            else:
                print(f"Error checking backup bucket: {e}")
                sys.exit(1)

    if not replicated:
        print("\nFAIL: Replication timed out. File never appeared in the backup bucket.")
        # Cleanup primary
        s3_primary.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
        sys.exit(1)

    # 4. When found, also check head_object on the primary bucket for the x-amz-replication-status metadata
    print("\n4. Checking replication status on the primary bucket...")
    try:
        primary_meta = s3_primary.head_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
        # Boto3 maps 'x-amz-replication-status' header to 'ReplicationStatus' key in response dictionary
        replication_status = primary_meta.get('ReplicationStatus', 'UNKNOWN')
        print(f"Replication status: {replication_status}")

        # 5. Print a clear pass/fail result with the replication status string
        if replication_status == 'COMPLETED':
            print("\nPASS: Replication verified. Status is COMPLETED.")
        else:
            print(f"\nWARNING/FAIL: File exists in backup, but status on primary is '{replication_status}' (expected COMPLETED).")
    except ClientError as e:
        print(f"Error checking primary bucket metadata: {e}")

    # Clean up test files from both buckets
    print("\nCleaning up test files from both buckets...")
    try:
        # Delete from primary
        versions_primary = s3_primary.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)
        for v in versions_primary.get('Versions', []):
            s3_primary.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=v['VersionId'])
        for dm in versions_primary.get('DeleteMarkers', []):
            s3_primary.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=dm['VersionId'])

        # Delete from backup
        versions_backup = s3_backup.list_object_versions(Bucket=BACKUP_BUCKET_NAME, Prefix=KEY_NAME)
        for v in versions_backup.get('Versions', []):
            s3_backup.delete_object(Bucket=BACKUP_BUCKET_NAME, Key=KEY_NAME, VersionId=v['VersionId'])
        for dm in versions_backup.get('DeleteMarkers', []):
            s3_backup.delete_object(Bucket=BACKUP_BUCKET_NAME, Key=KEY_NAME, VersionId=dm['VersionId'])

        print("Cleanup completed.")
    except Exception as e:
        print(f"Error during cleanup: {e}")

if __name__ == "__main__":
    test_replication()
