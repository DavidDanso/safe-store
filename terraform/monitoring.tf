# resource "aws_s3_bucket_logging" "safestore_primary" {
#   bucket = aws_s3_bucket.safestore_primary.id

#   target_bucket = aws_s3_bucket.safestore_logs.id
#   target_prefix = "primary/"
# }

# # NOTE: Backup bucket logging is intentionally omitted.
# # AWS prohibits cross-region S3 access logging (CrossLocationLoggingProhibitted).
# # The backup bucket is in eu-west-1 and the logs bucket is in us-east-1.
# # S3 server access logging requires source and target buckets to be in the same region.

# resource "aws_cloudwatch_metric_alarm" "safestore_primary_storage" {
#   alarm_name          = "safestore-primary-storage-threshold"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "BucketSizeBytes"
#   namespace           = "AWS/S3"
#   period              = "86400" # 24 hours, as S3 storage metrics are updated daily
#   statistic           = "Maximum"
#   threshold           = var.alarm_threshold_gb * 1024 * 1024 * 1024 # GB to Bytes

#   dimensions = {
#     BucketName  = aws_s3_bucket.safestore_primary.id
#     StorageType = "StandardStorage"
#   }

#   alarm_description = "Alarm if primary bucket storage size exceeds configured threshold"
# }
