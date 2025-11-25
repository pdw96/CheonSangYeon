variable "seoul_key_name" {
  description = "Key pair name for Seoul region EC2 instances"
  type        = string
  default     = ""
}

variable "seoul_ami_id" {
  description = "AMI ID for Seoul region EC2 instances"
  type        = string
  default     = "ami-0c1508b5372d244d7" # Amazon Linux 2023 in Seoul
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# ===== Azure DR VPN Settings =====

variable "azure_vpn_gateway_ip" {
  description = "Public IP address of Azure VPN Gateway"
  type        = string
  default     = "" # Azure 배포 후 설정
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
  description = "Shared key for Azure VPN connection"
  type        = string
  sensitive   = true
  default     = "" # 강력한 키로 설정 (환경변수 권장)
}

variable "enable_azure_dr" {
  description = "Enable Azure DR VPN connection"
  type        = bool
  default     = false # 초기에는 비활성화, Azure 배포 완료 후 활성화
}
