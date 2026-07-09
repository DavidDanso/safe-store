variable "primary_region" {
  type        = string
  description = "Region for the primary and logs buckets"
}

variable "backup_region" {
  type        = string
  description = "Region for the backup bucket"
}

variable "project_name" {
  type        = string
  description = "Used to build bucket names — safestore"
}

variable "environment" {
  type        = string
  description = "Used for tagging — test"
}

variable "account_id" {
  type        = string
  description = "Your AWS account ID, used in bucket names"
}

variable "alarm_threshold_gb" {
  type        = number
  description = "Storage size in GB that triggers the CloudWatch alarm"
}
