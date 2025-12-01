# ===== App Service Settings =====

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "plan-ecr-dr"
}

variable "app_service_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "B1"
}

variable "web_app_name" {
  description = "Name of the Web App"
  type        = string
  default     = "webapp-dr-multicloud"
}

# ===== ECR Settings =====

variable "ecr_registry_url" {
  description = "AWS ECR registry URL (without https://)"
  type        = string
  default     = "150502622488.dkr.ecr.ap-northeast-2.amazonaws.com"
}

variable "ecr_image_name" {
  description = "ECR image name with tag"
  type        = string
  default     = "seoul-portal-seoul-frontend:latest"
}

variable "ecr_username" {
  description = "ECR username (AWS)"
  type        = string
  default     = "AWS"
  sensitive   = true
}

variable "ecr_password" {
  description = "ECR password (AWS ECR auth token)"
  type        = string
  sensitive   = true
}

# ===== Database Settings =====

variable "mysql_admin_username" {
  description = "MySQL administrator username"
  type        = string
  default     = "azureadmin"
  sensitive   = true
}

variable "mysql_admin_password" {
  description = "MySQL administrator password"
  type        = string
  sensitive   = true
}
