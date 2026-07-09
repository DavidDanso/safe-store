import sys
import boto3
from botocore.exceptions import ClientError

# Configuration - Populate from terraform output primary_bucket_name
PRIMARY_BUCKET_NAME = "safestore-primary-123456789012-us-east-1"
KEY_NAME = "recovery_test_file.txt"
FILE_CONTENT = b"SafeStore recovery test content"

def test_recovery():
    s3_client = boto3.client('s3')
    print(f"Starting recovery test on bucket: {PRIMARY_BUCKET_NAME}")

    # 1. Upload a known test file
    print(f"1. Uploading test file: {KEY_NAME}...")
    s3_client.put_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, Body=FILE_CONTENT)
    print("Upload successful.")

    # 2. Delete it (standard delete - creates a delete marker)
    print("2. Deleting test file (standard delete)...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
    print("Delete request sent.")

    # 3. Call head_object - confirms the file looks gone
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

    # 4. List all versions - finds the delete marker by its type
    print("4. Listing object versions to find the delete marker...")
    versions = s3_client.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)

    delete_markers = versions.get('DeleteMarkers', [])
    if not delete_markers:
        print("Error: No delete markers found!")
        sys.exit(1)

    # Get the latest delete marker
    latest_delete_marker = delete_markers[0]
    version_id = latest_delete_marker['VersionId']
    print(f"Found delete marker. VersionId: {version_id}")

    # 5. Delete the delete marker using its specific VersionId
    print(f"5. Deleting delete marker (VersionId: {version_id}) to restore object...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=version_id)
    print("Delete marker deleted.")

    # 6. Call head_object again - confirms the file is restored
    print("6. Verifying object is restored via head_object...")
    try:
        response = s3_client.head_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
        print("Confirmed: Object is restored.")
    except ClientError as e:
        print(f"Error: Failed to restore object. Details: {e}")
        sys.exit(1)

    # 7. Compare content or size - confirms the restored file matches the original
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

    # Clean up the test file
    print("Cleaning up test file...")
    # Delete the active version
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
    # List and delete all remaining versions to keep the bucket clean
    versions = s3_client.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)
    for v in versions.get('Versions', []):
        s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=v['VersionId'])
    for dm in versions.get('DeleteMarkers', []):
        s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME, VersionId=dm['VersionId'])

    print("Success: Restored file matches original exactly. Test PASSED.")

if __name__ == "__main__":
    test_recovery()
