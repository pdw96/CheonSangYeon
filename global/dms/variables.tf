# Azure MySQL Target Variables
variable "azure_mysql_username" {
  description = "Azure MySQL admin username"
  type        = string
  default     = "sqladmin"
}

variable "azure_mysql_password" {
  description = "Azure MySQL admin password"
  type        = string
  sensitive   = true
}
