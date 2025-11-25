output "seoul_vpc_id" {
  description = "Seoul VPC ID"
  value       = data.terraform_remote_state.global_vpc.outputs.seoul_vpc_id
}

output "idc_vpc_id" {
  description = "IDC VPC ID"
  value       = data.terraform_remote_state.global_vpc.outputs.seoul_idc_vpc_id
}

output "idc_cgw_instance_id" {
  description = "IDC CGW Instance ID"
  value       = module.idc.cgw_instance_id
}

output "idc_cgw_instance_public_ip" {
  description = "IDC CGW Instance Public IP"
  value       = module.idc.cgw_instance_public_ip
}

output "idc_db_instance_id" {
  description = "IDC DB Instance ID"
  value       = module.idc.db_instance_id
}

output "idc_db_instance_private_ip" {
  description = "IDC DB Instance Private IP"
  value       = module.idc.db_instance_private_ip
}

output "idc_db_instance_public_ip" {
  description = "IDC DB Instance Public IP (임시)"
  value       = module.idc.db_instance_public_ip
}

output "customer_gateway_id" {
  description = "Customer Gateway ID"
  value       = aws_customer_gateway.idc.id
}

output "vpn_connection_id" {
  description = "VPN Connection ID"
  value       = aws_vpn_connection.seoul_to_idc.id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "seoul_beanstalk_subnet_ids" {
  description = "Seoul Elastic Beanstalk Subnet IDs"
  value       = data.terraform_remote_state.global_vpc.outputs.seoul_private_beanstalk_subnet_ids
}

output "aws_managed_vpn_status" {
  description = "AWS Managed VPN Status"
  value       = "AWS Managed VPN Connection established between Seoul Transit Gateway and IDC Customer Gateway"
}

output "vpn_tunnel_addresses" {
  description = "VPN Tunnel IP Addresses"
  value = {
    tunnel_1_address = aws_vpn_connection.seoul_to_idc.tunnel1_address
    tunnel_2_address = aws_vpn_connection.seoul_to_idc.tunnel2_address
    idc_cgw_ip       = module.idc.cgw_instance_public_ip
  }
}

output "beanstalk_application_name" {
  description = "Elastic Beanstalk Application Name"
  value       = aws_elastic_beanstalk_application.seoul_app.name
}

output "beanstalk_environment_name" {
  description = "Elastic Beanstalk Environment Name"
  value       = aws_elastic_beanstalk_environment.seoul_env.name
}

output "beanstalk_environment_url" {
  description = "Elastic Beanstalk Environment URL"
  value       = aws_elastic_beanstalk_environment.seoul_env.endpoint_url
}

output "beanstalk_cname" {
  description = "Elastic Beanstalk CNAME"
  value       = aws_elastic_beanstalk_environment.seoul_env.cname
}

# ===== Azure DR VPN Outputs =====

output "azure_customer_gateway_id" {
  description = "Customer Gateway ID for Azure DR"
  value       = var.enable_azure_dr && length(aws_customer_gateway.azure_dr) > 0 ? aws_customer_gateway.azure_dr[0].id : null
}

output "azure_vpn_connection_id" {
  description = "VPN Connection ID to Azure DR"
  value       = var.enable_azure_dr && length(aws_vpn_connection.seoul_to_azure) > 0 ? aws_vpn_connection.seoul_to_azure[0].id : null
}

output "azure_vpn_tunnel_addresses" {
  description = "Azure VPN Tunnel IP Addresses (AWS 측)"
  value = var.enable_azure_dr && length(aws_vpn_connection.seoul_to_azure) > 0 ? {
    tunnel_1_address = aws_vpn_connection.seoul_to_azure[0].tunnel1_address
    tunnel_2_address = aws_vpn_connection.seoul_to_azure[0].tunnel2_address
    azure_cgw_ip     = var.azure_vpn_gateway_ip
  } : null
}

output "azure_vpn_tunnel_psk" {
  description = "Azure VPN Tunnel Pre-Shared Keys (민감 정보)"
  value = var.enable_azure_dr && length(aws_vpn_connection.seoul_to_azure) > 0 ? {
    tunnel_1_psk = aws_vpn_connection.seoul_to_azure[0].tunnel1_preshared_key
    tunnel_2_psk = aws_vpn_connection.seoul_to_azure[0].tunnel2_preshared_key
  } : null
  sensitive = true
}

# Azure DR VPN 설정 가이드 (locals에서 생성)
locals {
  azure_dr_guide = var.enable_azure_dr && length(aws_vpn_connection.seoul_to_azure) > 0 ? join("\n", [
    "",
    "===== AWS-AZURE DR VPN 설정 완료 =====",
    "",
    "AWS VPN Tunnel 1: ${aws_vpn_connection.seoul_to_azure[0].tunnel1_address}",
    "AWS VPN Tunnel 2: ${aws_vpn_connection.seoul_to_azure[0].tunnel2_address}",
    "Azure VPN Gateway: ${var.azure_vpn_gateway_ip}",
    "",
    "Azure 측에서 다음 정보를 사용하여 Local Network Gateway 업데이트:",
    "",
    "1. Azure Portal > Local Network Gateway (aws-seoul-lng)",
    "2. Gateway IP Address: ${aws_vpn_connection.seoul_to_azure[0].tunnel1_address}",
    "3. Address Space: 20.0.0.0/16",
    "4. BGP Settings:",
    "   - ASN: ${aws_ec2_transit_gateway.main.amazon_side_asn}",
    "   - BGP Peering Address: [AWS VPN Tunnel BGP 주소 확인 필요]",
    "",
    "5. Connection 재생성:",
    "   az network vpn-connection delete \\",
    "     --name aws-azure-vpn-connection \\",
    "     --resource-group <RG_NAME>",
    "",
    "   az network vpn-connection create \\",
    "     --name aws-azure-vpn-connection \\",
    "     --resource-group <RG_NAME> \\",
    "     --vnet-gateway1 <VPN_GATEWAY_NAME> \\",
    "     --local-gateway2 aws-seoul-lng \\",
    "     --shared-key \"$${var.azure_vpn_shared_key}\" \\",
    "     --enable-bgp",
    "",
    "=========================================="
  ]) : "Azure DR이 비활성화되었습니다. enable_azure_dr=true로 설정하세요."
}

output "azure_dr_setup_guide" {
  description = "Azure DR VPN 설정 가이드"
  value       = local.azure_dr_guide
}
