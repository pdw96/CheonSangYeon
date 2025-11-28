# ===== AWS VPN Connection Module Variables =====

variable "aws_region" {
  description = "AWS Seoul region"
  type        = string
  default     = "ap-northeast-2"
}

variable "seoul_state_bucket" {
  description = "S3 bucket name for Seoul Terraform state"
  type        = string
}

variable "seoul_state_key" {
  description = "S3 key for Seoul Terraform state"
  type        = string
  default     = "seoul/terraform.tfstate"
}

variable "azure_vpn_gateway_ip" {
  description = "Public IP address of Azure VPN Gateway (from azurerm_public_ip.vpn_gateway)"
  type        = string
}

variable "azure_bgp_asn" {
  description = "BGP ASN of Azure VPN Gateway"
  type        = number
  default     = 65515
}

variable "azure_vnet_cidr" {
  description = "CIDR block of Azure VNet"
  type        = string
  default     = "50.0.0.0/16"
}

variable "azure_vpn_shared_key" {
  description = "Shared key for VPN connection (must match Azure side)"
  type        = string
  sensitive   = true
}
