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
  type        = string
  default     = "50.0.0.0/16" # AWS와 겹치지 않는 범위
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
