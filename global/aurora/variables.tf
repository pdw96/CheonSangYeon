variable "idc_app_secret_arn" {
  description = "Secrets Manager ARN that stores the IDC application user password"
  type        = string
}

variable "aurora_admin_secret_arn" {
  description = "Secrets Manager ARN that stores the Aurora admin password"
  type        = string
}
