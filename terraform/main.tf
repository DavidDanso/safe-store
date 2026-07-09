locals {
  primary_bucket_name = "${var.project_name}-primary-${var.account_id}-${var.primary_region}"
  backup_bucket_name  = "${var.project_name}-backup-${var.account_id}-${var.backup_region}"
  logs_bucket_name    = "${var.project_name}-logs-${var.account_id}-${var.primary_region}"

  common_tags = {
    Project     = "SafeStore"
    Environment = var.environment
  }
}
