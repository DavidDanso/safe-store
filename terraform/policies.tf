# Primary S3 Bucket Policy
resource "aws_s3_bucket_policy" "safestore_primary" {
  bucket = aws_s3_bucket.safestore_primary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.safestore_primary.arn,
          "${aws_s3_bucket.safestore_primary.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "EnforceEncryptionHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.safestore_primary.arn}/*"
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = "true"
          }
        }
      }
    ]
  })
}

# Backup S3 Bucket Policy
resource "aws_s3_bucket_policy" "safestore_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.safestore_backup.arn,
          "${aws_s3_bucket.safestore_backup.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyWriteExceptReplicationRole"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${aws_s3_bucket.safestore_backup.arn}/*"
        Condition = {
          ArnNotEquals = {
            "aws:PrincipalArn" = aws_iam_role.safestore_replication.arn
          }
        }
      }
    ]
  })
}

# Primary logs Bucket Policy
resource "aws_s3_bucket_policy" "safestore_logs" {
  bucket = aws_s3_bucket.safestore_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.safestore_logs.arn,
          "${aws_s3_bucket.safestore_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowS3Logging"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.safestore_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = [
              aws_s3_bucket.safestore_primary.arn,
              aws_s3_bucket.safestore_backup.arn
            ]
          }
        }
      }
    ]
  })
}

# Backup logs Bucket Policy
resource "aws_s3_bucket_policy" "safestore_logs_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.safestore_logs_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.safestore_logs_backup.arn,
          "${aws_s3_bucket.safestore_logs_backup.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowS3Logging"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.safestore_logs_backup.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.safestore_backup.arn
          }
        }
      }
    ]
  })
}