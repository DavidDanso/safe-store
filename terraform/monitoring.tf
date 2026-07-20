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

# Primary bucket storage alarm
resource "aws_cloudwatch_metric_alarm" "safestore_primary_storage" {
  alarm_name          = "safestore-primary-storage-threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400" # 24 hours, as S3 storage metrics are updated daily
  statistic           = "Maximum"
  threshold           = var.alarm_threshold_gb * 1024 * 1024 * 1024 # GB to Bytes

  dimensions = {
    BucketName  = aws_s3_bucket.safestore_primary.id
    StorageType = "StandardStorage"
  }

  alarm_description = "Alarm if primary bucket storage size exceeds configured threshold"
  tags              = local.common_tags
}

# Backup bucket storage alarm
resource "aws_cloudwatch_metric_alarm" "safestore_backup_storage" {
  provider            = aws.backup
  alarm_name          = "safestore-backup-storage-threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400" # 24 hours, as S3 storage metrics are updated daily
  statistic           = "Maximum"
  threshold           = var.alarm_threshold_gb * 1024 * 1024 * 1024 # GB to Bytes

  dimensions = {
    BucketName  = aws_s3_bucket.safestore_backup.id
    StorageType = "StandardStorage"
  }

  alarm_description = "Alarm if backup bucket storage size exceeds configured threshold"
  tags              = local.common_tags
}
