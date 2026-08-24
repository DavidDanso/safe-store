import sys
import os
import boto3
from botocore.exceptions import ClientError
import mimetypes

PRIMARY_BUCKET_NAME = "ENTER PRIMARY BUCKET NAME HERE"

# Point this at whatever file you want to test with — image or text,
# doesn't matter, the script figures out the rest from this path.
SOURCE_FILE_PATH = "ENTER SOURCE PATH FOR UPLOAD HERE"

# Key name is derived from the real filename, so the extension is
# correct and mimetypes.guess_type() actually works properly.
KEY_NAME = os.path.basename(SOURCE_FILE_PATH)


def test_recovery():
    s3_client = boto3.client('s3')
    print(f"Starting recovery test on bucket: {PRIMARY_BUCKET_NAME}")

    # Read the real file's bytes from disk — this is what gets uploaded
    # and later compared against, instead of a hardcoded fake string.
    with open(SOURCE_FILE_PATH, 'rb') as f:
        file_content = f.read()

    # 1. Upload the file
    print(f"1. Uploading test file: {KEY_NAME}...")
    content_type, _ = mimetypes.guess_type(KEY_NAME)
    if not content_type:
        content_type = 'application/octet-stream'
    s3_client.put_object(
        Bucket=PRIMARY_BUCKET_NAME,
        Key=KEY_NAME,
        Body=file_content,
        ServerSideEncryption='AES256',
        ContentType=content_type
    )
    print(f"Upload successful. Content-Type: {content_type}")

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
    print("4. Listing object versions to find the current delete marker...")
    versions = s3_client.list_object_versions(Bucket=PRIMARY_BUCKET_NAME, Prefix=KEY_NAME)

    delete_markers = [dm for dm in versions.get('DeleteMarkers', []) if dm['Key'] == KEY_NAME]
    current_marker = next((dm for dm in delete_markers if dm.get('IsLatest')), None)

    if not current_marker:
        print("Error: No current delete marker found!")
        sys.exit(1)

    version_id = current_marker['VersionId']
    print(f"Found current delete marker. VersionId: {version_id}")

    # 5. Delete the delete marker itself to restore the object
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

    # 7. Prove the restored file is identical to the original — now
    # comparing against the real bytes read from disk in step 1
    print("7. Comparing restored object size and content...")
    restored_size = response['ContentLength']
    expected_size = len(file_content)

    if restored_size != expected_size:
        print(f"Error: Size mismatch! Expected {expected_size} bytes, got {restored_size} bytes.")
        sys.exit(1)

    restored_obj = s3_client.get_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)
    restored_content = restored_obj['Body'].read()

    if restored_content != file_content:
        print("Error: Content mismatch!")
        sys.exit(1)

    # Clean up — only runs if everything above passed
    print("Cleaning up test file...")
    s3_client.delete_object(Bucket=PRIMARY_BUCKET_NAME, Key=KEY_NAME)

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