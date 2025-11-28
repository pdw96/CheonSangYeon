# ===== AWS VPN Connection Module =====
# Purpose: Azure 배포 시 AWS Seoul Transit Gateway와 VPN 연결 자동 구성
# Azure VPN Gateway ↔ AWS Transit Gateway Site-to-Site VPN

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Seoul 리전 Terraform State에서 Transit Gateway 정보 가져오기
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = var.seoul_state_bucket
    key    = var.seoul_state_key
    region = var.aws_region
  }
}

# Customer Gateway for Azure VPN Gateway
resource "aws_customer_gateway" "azure_dr" {
  provider   = aws
  bgp_asn    = var.azure_bgp_asn
  ip_address = var.azure_vpn_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name        = "azure-dr-cgw"
    Environment = "DR"
    Purpose     = "Azure DR VPN Connection"
    ManagedBy   = "Terraform-Azure-Module"
  }
}

# Site-to-Site VPN Connection to Azure
resource "aws_vpn_connection" "seoul_to_azure" {
  provider            = aws
  transit_gateway_id  = data.terraform_remote_state.seoul.outputs.transit_gateway_id
  customer_gateway_id = aws_customer_gateway.azure_dr.id
  type                = "ipsec.1"
  static_routes_only  = true # Azure VPN Gateway와의 호환성을 위해 Static Routes 사용

  # Tunnel 1 Options - Azure VPN Gateway 호환 설정
  tunnel1_ike_versions                  = ["ikev2"]
  tunnel1_phase1_encryption_algorithms  = ["AES256"]
  tunnel1_phase1_integrity_algorithms   = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers       = [14]
  tunnel1_phase2_encryption_algorithms  = ["AES256"]
  tunnel1_phase2_integrity_algorithms   = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers       = [14]
  tunnel1_dpd_timeout_seconds           = 30
  tunnel1_preshared_key                 = var.azure_vpn_shared_key

  # Tunnel 2 Options - Azure VPN Gateway 호환 설정
  tunnel2_ike_versions                  = ["ikev2"]
  tunnel2_phase1_encryption_algorithms  = ["AES256"]
  tunnel2_phase1_integrity_algorithms   = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers       = [14]
  tunnel2_phase2_encryption_algorithms  = ["AES256"]
  tunnel2_phase2_integrity_algorithms   = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers       = [14]
  tunnel2_dpd_timeout_seconds           = 30
  tunnel2_preshared_key                 = var.azure_vpn_shared_key

  tags = {
    Name        = "seoul-to-azure-vpn"
    Environment = "DR"
    ManagedBy   = "Terraform-Azure-Module"
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Transit Gateway Route for Azure VNet CIDR
resource "aws_ec2_transit_gateway_route" "azure_vnet" {
  provider                       = aws
  destination_cidr_block         = var.azure_vnet_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.seoul_to_azure.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.seoul.outputs.transit_gateway_route_table_id

  depends_on = [aws_vpn_connection.seoul_to_azure]
}

# Seoul Private Route Table에 Azure VNet 라우트 추가
resource "aws_route" "seoul_private_to_azure" {
  provider               = aws
  route_table_id         = data.terraform_remote_state.seoul.outputs.private_route_table_id
  destination_cidr_block = var.azure_vnet_cidr
  transit_gateway_id     = data.terraform_remote_state.seoul.outputs.transit_gateway_id

  depends_on = [
    aws_vpn_connection.seoul_to_azure
  ]
}
