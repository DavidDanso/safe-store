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

# Logs S3 Bucket
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
