# ===== Azure General Settings =====

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-dr-multicloud"
}

variable "azure_location" {
  description = "Azure region for DR resources"
  type        = string
  default     = "koreacentral" # Seoul과 지리적으로 가까운 한국 중부
}

# ===== Azure Network Settings =====

variable "vnet_name" {
  description = "Name of the Azure Virtual Network"
  type        = string
  default     = "vnet-dr-multicloud"
}

variable "vnet_address_space" {
  description = "Address space for Azure VNet"
  type        = list(string)
  default     = ["50.0.0.0/16"] # AWS와 겹치지 않는 범위
}

variable "app_subnet_cidr" {
  description = "CIDR block for App Service subnet"
  type        = string
  default     = "50.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR block for Database subnet"
  type        = string
  default     = "50.0.2.0/24"
}

variable "gateway_subnet_cidr" {
  description = "CIDR block for VPN Gateway subnet"
  type        = string
  default     = "50.0.255.0/24"
}

# ===== Azure MySQL Settings =====

variable "mysql_server_name" {
  description = "Name of the Azure MySQL Flexible Server"
  type        = string
  default     = "mysql-dr-multicloud"
}

variable "mysql_admin_username" {
  description = "Administrator username for MySQL"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

variable "mysql_admin_password" {
  description = "Administrator password for MySQL"
  type        = string
  sensitive   = true
  # 실제 사용 시 terraform.tfvars 또는 환경변수로 설정
}

variable "mysql_sku_name" {
  description = "SKU name for MySQL Flexible Server"
  type        = string
  default     = "GP_Standard_D2ds_v4" # General Purpose, 2 vCores, 8GB RAM
}

variable "mysql_storage_gb" {
  description = "Storage size in GB for MySQL"
  type        = number
  default     = 100
}

variable "mysql_database_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "webapp_db"
}

# ===== Azure App Service Settings =====

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "plan-dr-multicloud"
}

variable "app_service_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "P1v3" # Premium v3, 2 vCores, 8GB RAM
}

variable "web_app_name" {
  description = "Name of the Web App"
  type        = string
  default     = "webapp-dr-multicloud"
}

# ===== ECR Settings (for Container Deployment) =====

variable "deploy_app_service" {
  description = "Deploy App Service with ECR image. Set to true after ECR image is ready."
  type        = bool
  default     = false
}

variable "ecr_registry_url" {
  description = "AWS ECR registry URL (without https://)"
  type        = string
  default     = "" # 예: 150502622488.dkr.ecr.ap-northeast-2.amazonaws.com
}

variable "ecr_image_name" {
  description = "ECR image name with tag"
  type        = string
  default     = "" # 예: my-app:latest
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
  default     = ""
}

# ===== Azure Storage Settings =====

variable "storage_account_name" {
  description = "Name of the Storage Account (must be globally unique)"
  type        = string
  default     = "stdrmulticloud"
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

# ===== Azure VPN Gateway Settings =====

variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  type        = string
  default     = "vpngw-dr-multicloud"
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw2" # 1.25 Gbps, Zone-redundant
}

variable "azure_bgp_asn" {
  description = "Azure BGP ASN for VPN Gateway"
  type        = number
  default     = 65515
}

variable "aws_bgp_asn" {
  description = "AWS BGP ASN for Transit Gateway"
  type        = number
  default     = 64512
}

variable "aws_vpn_gateway_ip" {
  description = "Public IP of AWS VPN endpoint (from AWS VPN Connection)"
  type        = string
  default     = "" # Terraform apply 후 AWS VPN에서 가져와 설정
}

variable "aws_bgp_peering_address" {
  description = "BGP peering address from AWS VPN tunnel"
  type        = string
  default     = "" # AWS VPN Connection 생성 후 설정
}

variable "vpn_shared_key" {
  description = "Shared key for VPN connection"
  type        = string
  sensitive   = true
  default     = "" # 강력한 키로 설정 필요
}

# ===== Monitoring Settings =====

variable "alert_email" {
  description = "Email address for DR alerts"
  type        = string
  default     = "admin@example.com"
}

# ===== DR Strategy Settings =====

variable "enable_auto_failover" {
  description = "Enable automatic failover to Azure DR"
  type        = bool
  default     = false # 초기에는 수동 failover
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "failover_threshold" {
  description = "Number of failed health checks before failover"
  type        = number
  default     = 3
}

# ===== Replication Settings =====

variable "enable_continuous_replication" {
  description = "Enable continuous data replication from AWS to Azure"
  type        = bool
  default     = true
}

variable "replication_lag_threshold_seconds" {
  description = "Maximum acceptable replication lag in seconds"
  type        = number
  default     = 60
}

variable "enable_auto_dms_migration" {
  description = "Automatically start DMS migration task after Azure deployment"
  type        = bool
  default     = false
}

# ===== Route53 DNS Settings =====

variable "create_azure_dns_record" {
  description = "Create Route53 DNS record for Azure endpoint (azure.domain.com)"
  type        = bool
  default     = true
}

variable "enable_failover_routing" {
  description = "Enable Route53 failover routing (Primary: AWS, Secondary: Azure)"
  type        = bool
  default     = false
}
