output "primary_bucket_name" {
  value       = aws_s3_bucket.safestore_primary.id
  description = "The name of the primary S3 bucket"
}

output "backup_bucket_name" {
  value       = aws_s3_bucket.safestore_backup.id
  description = "The name of the backup S3 bucket"
}

output "logs_bucket_name" {
  value       = aws_s3_bucket.safestore_logs.id
  description = "The name of the logs S3 bucket"
}

output "primary_bucket_arn" {
  value       = aws_s3_bucket.safestore_primary.arn
  description = "The ARN of the primary S3 bucket"
}

output "backup_bucket_arn" {
  value       = aws_s3_bucket.safestore_backup.arn
  description = "The ARN of the backup S3 bucket"
}

output "replication_role_arn" {
  value       = aws_iam_role.safestore_replication.arn
  description = "The ARN of the IAM replication role"
}
