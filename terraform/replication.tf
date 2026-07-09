resource "aws_s3_bucket_replication_configuration" "safestore" {
  # Must have bucket versioning enabled first before this resource can be created.
  depends_on = [
    aws_s3_bucket_versioning.safestore_primary,
    aws_s3_bucket_versioning.safestore_backup
  ]

  role   = aws_iam_role.safestore_replication.arn
  bucket = aws_s3_bucket.safestore_primary.id

  rule {
    id     = "safestore-replication-rule"
    status = "Enabled"

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.safestore_backup.arn
      storage_class = "STANDARD"
    }
  }
}
