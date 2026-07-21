import sys
import boto3
from botocore.exceptions import ClientError

PRIMARY_BUCKET_NAME = "safestore-primary-649655225479-us-east-1"
KEY_NAME = "recovery_test_file.bin"
FILE_CONTENT = b"SafeStore recovery test content"


def test_recovery():
    s3_client = boto3.client('s3')
    print(f"Starting recovery test on bucket: {PRIMARY_BUCKET_NAME}")

    # 1. Upload a known test file
    # ServerSideEncryption is required here — the bucket policy denies any
    # PutObject that doesn't explicitly include this header.
    print(f"1. Uploading test file: {KEY_NAME}...")
    s3_client.put_object(
        Bucket=PRIMARY_BUCKET_NAME,
        Key=KEY_NAME,
        Body=FILE_CONTENT,
        ServerSideEncryption='AES256'
    )
    print("Upload successful.")

    # 2. Delete it (standard delete - creates a delete marker, doesn't
    # actually destroy the underlying object version)
    print("2. Deleting test file (standard delete)...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
    print("Delete request sent.")

    # 3. Confirm the file looks gone from a normal caller's perspective
    print("3. Verifying object is gone via head_object...")
    try:
        s3_client.head_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
        print("Error: Object is still accessible!")
        sys.exit(1)
    except ClientError as e:
        if e.response['ResponseMetadata']['HTTPStatusCode'] == 404:
            print("Confirmed: Object is gone (returned 404).")
        else:
            raise e

    # 4. List all versions and find the CURRENT delete marker specifically.
    # Prefix does a partial match, so filter down to this exact key only —
    # matters if this script is ever reused with a dynamic filename later.
    # Don't just grab the first item in the list either — if old test runs
    # left extra delete markers behind, the first one isn't guaranteed to
    # be the active one. IsLatest is the flag S3 itself uses to mark which
    # version/marker is currently "on top."
    print("4. Listing object versions to find the current delete marker...")
    versions = s3_client.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)

    delete_markers = [dm for dm in versions.get('DeleteMarkers', []) if dm['Key'] == KEY_NAME]
    current_marker = next((dm for dm in delete_markers if dm.get('IsLatest')), None)

    if not current_marker:
        print("Error: No current delete marker found!")
        sys.exit(1)

    version_id = current_marker['VersionId']
    print(f"Found current delete marker. VersionId: {version_id}")

    # 5. Delete the delete marker itself (by its own VersionId) — this is
    # what "restores" the file, since it uncovers the real version beneath it
    print(f"5. Deleting delete marker (VersionId: {version_id}) to restore object...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=version_id)
    print("Delete marker deleted.")

    # 6. Confirm the file is accessible again
    print("6. Verifying object is restored via head_object...")
    try:
        response = s3_client.head_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
        print("Confirmed: Object is restored.")
    except ClientError as e:
        print(f"Error: Failed to restore object. Details: {e}")
        sys.exit(1)

    # 7. Prove the restored file is identical to what was originally
    # uploaded — check size first (cheap), then full content (thorough)
    print("7. Comparing restored object size and content...")
    restored_size = response['ContentLength']
    expected_size = len(FILE_CONTENT)

    if restored_size != expected_size:
        print(f"Error: Size mismatch! Expected {expected_size} bytes, got {restored_size} bytes.")
        sys.exit(1)

    restored_obj = s3_client.get_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
    restored_content = restored_obj['Body'].read()

    if restored_content != FILE_CONTENT:
        print("Error: Content mismatch!")
        sys.exit(1)

    # Clean up — only runs if everything above passed. Deliberately left
    # out of a try/finally: if the test fails partway through, the mess
    # stays in the bucket so you can inspect what actually happened.
    print("Cleaning up test file...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)

    # re-list versions AFTER the delete above, since that delete just
    # created a fresh delete marker that also needs to be purged. same
    # exact-key filter applied here too, for the same reason as step 4.
    versions = s3_client.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)
    for v in versions.get('Versions', []):
        if v['Key'] == KEY_NAME:
            s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=v['VersionId'])
    for dm in versions.get('DeleteMarkers', []):
        if dm['Key'] == KEY_NAME:
            s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=dm['VersionId'])

    print("Success: Restored file matches original exactly. Test PASSED.")


if __name__ == "__main__":
    test_recovery()