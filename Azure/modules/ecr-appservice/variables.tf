variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "app_service_plan_name" {
  description = "App Service Plan name"
  type        = string
}

variable "app_service_sku" {
  description = "App Service Plan SKU (e.g., B1, P1v2, P2v3)"
  type        = string
  default     = "B1"
}

variable "web_app_name" {
  description = "Web App name (must be globally unique)"
  type        = string
}

variable "ecr_registry_url" {
  description = "AWS ECR registry URL (e.g., 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com)"
  type        = string
}

variable "ecr_image_name" {
  description = "ECR image name with tag (e.g., myapp:latest)"
  type        = string
}

variable "ecr_username" {
  description = "ECR username (AWS)"
  type        = string
  default     = "AWS"
}

variable "ecr_password" {
  description = "ECR password (docker login token)"
  type        = string
  sensitive   = true
}

variable "app_environment" {
  description = "Application environment (production, staging, etc.)"
  type        = string
  default     = "production"
}

variable "always_on" {
  description = "Keep app always on"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "https_only" {
  description = "Only allow HTTPS traffic"
  type        = bool
  default     = true
}

variable "vnet_integration_enabled" {
  description = "Enable VNet integration"
  type        = bool
  default     = true
}

variable "app_subnet_id" {
  description = "App Service subnet ID for VNet integration"
  type        = string
  default     = null
}

variable "database_connection_enabled" {
  description = "Enable database connection settings"
  type        = bool
  default     = false
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "3306"
}

variable "additional_app_settings" {
  description = "Additional app settings"
  type        = map(string)
  default     = {}
}

variable "custom_domain" {
  description = "Custom domain name (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
