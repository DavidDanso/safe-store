# Primary bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "safestore_primary" {
  bucket = aws_s3_bucket.safestore_primary.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "clean-up-primary-delete-markers"
    status = "Enabled"
    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }
}

# Backup bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "safestore_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_backup.id

  rule {
    id     = "expire-backup-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "clean-up-backup-delete-markers"
    status = "Enabled"
    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }
}

# Logs bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "safestore_logs" {
  bucket = aws_s3_bucket.safestore_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 1
    }
  }
}

# Backup logs bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "safestore_logs_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_logs_backup.id

  rule {
    id     = "expire-old-logs-backup"
    status = "Enabled"
    filter {}

    expiration {
      days = 1
    }
  }
}
