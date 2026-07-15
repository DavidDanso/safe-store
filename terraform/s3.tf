# Primary S3 Bucket
resource "aws_s3_bucket" "safestore_primary" {
  bucket = local.primary_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "safestore_primary" {
  bucket = aws_s3_bucket.safestore_primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "safestore_primary" {
  bucket = aws_s3_bucket.safestore_primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "safestore_primary" {
  bucket                  = aws_s3_bucket.safestore_primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Backup S3 Bucket
resource "aws_s3_bucket" "safestore_backup" {
  provider = aws.backup
  bucket   = local.backup_bucket_name
  tags     = local.common_tags
}

resource "aws_s3_bucket_versioning" "safestore_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "safestore_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "safestore_backup" {
  provider                = aws.backup
  bucket                  = aws_s3_bucket.safestore_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Primary logs Bucket
resource "aws_s3_bucket" "safestore_logs" {
  bucket = local.logs_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "safestore_logs" {
  bucket = aws_s3_bucket.safestore_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "safestore_logs" {
  bucket                  = aws_s3_bucket.safestore_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Backup logs Bucket
resource "aws_s3_bucket" "safestore_logs_backup" {
  provider = aws.backup
  bucket   = local.logs_backup_bucket_name
  tags     = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "safestore_logs_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_logs_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "safestore_logs_backup" {
  provider                = aws.backup
  bucket                  = aws_s3_bucket.safestore_logs_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Replication Configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  bucket = aws_s3_bucket.safestore_primary.id
  role   = aws_iam_role.safestore_replication.arn

  depends_on = [
    aws_s3_bucket_versioning.safestore_primary,
    aws_s3_bucket_versioning.safestore_backup
  ]

  rule {
    id     = "safestore-replication-rule"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.safestore_backup.arn
      storage_class = "STANDARD"
    }
  }
}

# Route primary bucket logs to the logs bucket
resource "aws_s3_bucket_logging" "primary" {
  bucket        = aws_s3_bucket.safestore_primary.id
  target_bucket = aws_s3_bucket.safestore_logs.id
  target_prefix = "log/primary/"
}

# Route backup bucket logs to the logs bucket
resource "aws_s3_bucket_logging" "backup" {
  provider      = aws.backup
  bucket        = aws_s3_bucket.safestore_backup.id
  target_bucket = aws_s3_bucket.safestore_logs_backup.id
  target_prefix = "log/backup/"
}