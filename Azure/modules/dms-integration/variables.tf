variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "mysql_server_name" {
  description = "MySQL Flexible Server name"
  type        = string
}

variable "mysql_admin_username" {
  description = "MySQL administrator username"
  type        = string
}

variable "mysql_admin_password" {
  description = "MySQL administrator password"
  type        = string
  sensitive   = true
}

variable "mysql_sku_name" {
  description = "MySQL SKU name (e.g., B_Standard_B1ms, GP_Standard_D2ds_v4)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_version" {
  description = "MySQL version"
  type        = string
  default     = "8.0.21"
}

variable "mysql_storage_gb" {
  description = "MySQL storage size in GB"
  type        = number
  default     = 20
}

variable "mysql_iops" {
  description = "MySQL IOPS"
  type        = number
  default     = 360
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_charset" {
  description = "Database charset"
  type        = string
  default     = "utf8mb4"
}

variable "database_collation" {
  description = "Database collation"
  type        = string
  default     = "utf8mb4_unicode_ci"
}

variable "db_subnet_id" {
  description = "Database subnet ID"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name for MySQL"
  type        = string
  default     = "mysql-dr.private.mysql.database.azure.com"
}

variable "aws_vpc_cidr_start" {
  description = "AWS VPC CIDR start IP for firewall rule"
  type        = string
  default     = "20.0.0.0"
}

variable "aws_vpc_cidr_end" {
  description = "AWS VPC CIDR end IP for firewall rule"
  type        = string
  default     = "20.255.255.255"
}

variable "maintenance_day" {
  description = "Maintenance window day of week (0-6, 0=Sunday)"
  type        = number
  default     = 0
}

variable "maintenance_hour" {
  description = "Maintenance window start hour (0-23)"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
