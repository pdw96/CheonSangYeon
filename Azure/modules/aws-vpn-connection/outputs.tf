# ===== AWS VPN Connection Module Outputs =====

output "customer_gateway_id" {
  description = "Customer Gateway ID for Azure VPN"
  value       = aws_customer_gateway.azure_dr.id
}

output "vpn_connection_id" {
  description = "VPN Connection ID to Azure"
  value       = aws_vpn_connection.seoul_to_azure.id
}

output "tunnel_1_address" {
  description = "AWS VPN Tunnel 1 Outside IP Address"
  value       = aws_vpn_connection.seoul_to_azure.tunnel1_address
}

output "tunnel_2_address" {
  description = "AWS VPN Tunnel 2 Outside IP Address"
  value       = aws_vpn_connection.seoul_to_azure.tunnel2_address
}

output "tunnel_1_psk" {
  description = "Tunnel 1 Pre-Shared Key (민감 정보)"
  value       = aws_vpn_connection.seoul_to_azure.tunnel1_preshared_key
  sensitive   = true
}

output "tunnel_2_psk" {
  description = "Tunnel 2 Pre-Shared Key (민감 정보)"
  value       = aws_vpn_connection.seoul_to_azure.tunnel2_preshared_key
  sensitive   = true
}

output "transit_gateway_attachment_id" {
  description = "Transit Gateway Attachment ID for VPN Connection"
  value       = aws_vpn_connection.seoul_to_azure.transit_gateway_attachment_id
}

output "vpn_setup_guide" {
  description = "Azure Local Network Gateway 설정 가이드"
  value = join("\n", [
    "",
    "===== Azure Local Network Gateway 설정 =====",
    "",
    "1. Azure Portal에서 Local Network Gateway 업데이트:",
    "   - Name: aws-seoul-lng",
    "   - IP Address: ${aws_vpn_connection.seoul_to_azure.tunnel1_address}",
    "   - Address Space: 20.0.0.0/16 (Seoul VPC CIDR)",
    "",
    "2. Azure CLI로 VPN Connection 생성:",
    "   az network vpn-connection create \\",
    "     --name aws-azure-vpn-connection \\",
    "     --resource-group <YOUR_RG_NAME> \\",
    "     --vnet-gateway1 <VPN_GATEWAY_NAME> \\",
    "     --local-gateway2 aws-seoul-lng \\",
    "     --shared-key \"${var.azure_vpn_shared_key}\" \\",
    "     --location koreacentral",
    "",
    "3. AWS VPN Tunnel 정보:",
    "   - Tunnel 1: ${aws_vpn_connection.seoul_to_azure.tunnel1_address}",
    "   - Tunnel 2: ${aws_vpn_connection.seoul_to_azure.tunnel2_address}",
    "   - Pre-Shared Key: [민감 정보 - terraform output으로 확인]",
    "",
    "4. 연결 확인:",
    "   - Azure Portal: VPN Gateway > Connections",
    "   - AWS Console: VPC > Site-to-Site VPN Connections",
    "=========================================="
  ])
}
