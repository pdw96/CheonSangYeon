variable "idc_app_secret_arn" {
  description = "Secrets Manager ARN that stores the IDC application user password"
  type        = string
}

variable "aurora_admin_secret_arn" {
  description = "Secrets Manager ARN that stores the Aurora admin password"
  type        = string
}

variable "idc_app_username" {
  description = "Username for the IDC source database"
  type        = string
  default     = "idcuser"
}

variable "aurora_admin_username" {
  description = "Username for the Aurora target database"
  type        = string
  default     = "admin"
}
