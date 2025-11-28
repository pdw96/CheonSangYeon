variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "dms_state_key" {
  description = "State key for DMS remote state"
  type        = string
  default     = "terraform/global-dms/terraform.tfstate"
}

variable "aurora_state_key" {
  description = "State key for Aurora remote state"
  type        = string
  default     = "terraform/global-aurora/terraform.tfstate"
}

variable "source_endpoint_id" {
  description = "Source endpoint ID"
  type        = string
  default     = "source-aurora-mysql"
}

variable "target_endpoint_id" {
  description = "Target endpoint ID"
  type        = string
  default     = "target-azure-mysql"
}

variable "source_database_name" {
  description = "Source database name"
  type        = string
  default     = "globaldb"
}

variable "target_database_name" {
  description = "Target database name"
  type        = string
}

variable "source_username" {
  description = "Source database username"
  type        = string
  sensitive   = true
}

variable "source_password" {
  description = "Source database password"
  type        = string
  sensitive   = true
}

variable "target_username" {
  description = "Target database username"
  type        = string
  sensitive   = true
}

variable "target_password" {
  description = "Target database password"
  type        = string
  sensitive   = true
}

variable "azure_mysql_endpoint" {
  description = "Azure MySQL endpoint (FQDN or private IP)"
  type        = string
}

variable "ssl_mode" {
  description = "SSL mode for connections"
  type        = string
  default     = "none"
}

variable "extra_connection_attributes" {
  description = "Extra connection attributes"
  type        = string
  default     = "initstmt=SET FOREIGN_KEY_CHECKS=0"
}

variable "replication_task_id" {
  description = "Replication task ID"
  type        = string
  default     = "aurora-to-azure-migration-task"
}

variable "migration_type" {
  description = "Migration type (full-load, cdc, full-load-and-cdc)"
  type        = string
  default     = "full-load"
}

variable "transform_schema" {
  description = "Transform source schema name to target schema name"
  type        = bool
  default     = true
}

variable "target_table_prep_mode" {
  description = "Target table preparation mode"
  type        = string
  default     = "DROP_AND_CREATE"
}

variable "enable_logging" {
  description = "Enable CloudWatch logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "auto_start_migration" {
  description = "Automatically start migration task after creation"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
