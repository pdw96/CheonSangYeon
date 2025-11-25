# ===== Azure Resource Group =====

output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.dr.name
}

output "resource_group_location" {
  description = "Location of the Azure Resource Group"
  value       = azurerm_resource_group.dr.location
}

# ===== Azure Network =====

output "vnet_id" {
  description = "ID of the Azure Virtual Network"
  value       = azurerm_virtual_network.dr.id
}

output "vnet_name" {
  description = "Name of the Azure Virtual Network"
  value       = azurerm_virtual_network.dr.name
}

output "app_subnet_id" {
  description = "ID of the App Service subnet"
  value       = azurerm_subnet.app.id
}

output "db_subnet_id" {
  description = "ID of the Database subnet"
  value       = azurerm_subnet.db.id
}

output "gateway_subnet_id" {
  description = "ID of the Gateway subnet"
  value       = azurerm_subnet.gateway.id
}

# ===== Azure MySQL =====
# MySQL 리소스가 비활성화되어 주석 처리

# output "mysql_server_fqdn" {
#   description = "FQDN of the Azure MySQL Flexible Server"
#   value       = azurerm_mysql_flexible_server.dr.fqdn
# }

# output "mysql_server_name" {
#   description = "Name of the Azure MySQL Flexible Server"
#   value       = azurerm_mysql_flexible_server.dr.name
# }

# output "mysql_database_name" {
#   description = "Name of the MySQL database"
#   value       = azurerm_mysql_flexible_database.webapp.name
# }

# output "mysql_connection_string" {
#   description = "MySQL connection string (without password)"
#   value       = "Server=${azurerm_mysql_flexible_server.dr.fqdn};Database=${azurerm_mysql_flexible_database.webapp.name};Uid=${var.mysql_admin_username};Port=3306"
#   sensitive   = true
# }

# ===== Azure App Service =====

output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.dr.id
}

output "web_app_id" {
  description = "ID of the Web App"
  value       = azurerm_linux_web_app.dr.id
}

output "web_app_name" {
  description = "Name of the Web App"
  value       = azurerm_linux_web_app.dr.name
}

output "web_app_default_hostname" {
  description = "Default hostname of the Web App"
  value       = azurerm_linux_web_app.dr.default_hostname
}

output "web_app_outbound_ips" {
  description = "Outbound IP addresses of the Web App"
  value       = azurerm_linux_web_app.dr.outbound_ip_addresses
}

# ===== Azure Storage =====

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.dr.name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.dr.primary_blob_endpoint
}

output "backups_container_name" {
  description = "Name of the backups container"
  value       = azurerm_storage_container.backups.name
}

output "assets_container_name" {
  description = "Name of the static assets container"
  value       = azurerm_storage_container.assets.name
}

# ===== Azure VPN Gateway =====

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "vpn_gateway_bgp_asn" {
  description = "BGP ASN of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.bgp_settings[0].asn
}

output "vpn_gateway_bgp_peering_address" {
  description = "BGP peering address of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses[0].default_addresses[0]
}

output "vpn_connection_id" {
  description = "ID of the VPN connection to AWS"
  value       = azurerm_virtual_network_gateway_connection.aws_azure.id
}

# ===== AWS Route53 Health Check =====

output "route53_health_check_id" {
  description = "ID of the Route53 health check for Azure DR"
  value       = aws_route53_health_check.azure_dr.id
}

# ===== DR Configuration Summary =====

output "dr_status" {
  description = "DR environment status summary"
  value = {
    region                    = azurerm_resource_group.dr.location
    web_app_url               = "https://${azurerm_linux_web_app.dr.default_hostname}"
    database_endpoint         = "MySQL disabled due to quota limitation"
    vpn_status                = "configured"
    high_availability_enabled = true
    backup_enabled            = true
    monitoring_enabled        = true
  }
}

output "failover_instructions" {
  description = "Instructions for manual failover to Azure DR"
  value = <<-EOT
    
    ===== AZURE DR FAILOVER INSTRUCTIONS =====
    
    1. AWS Primary Region 장애 확인:
       - CloudWatch 대시보드에서 AWS Seoul 리전 상태 확인
       - Route53 Health Check 상태 확인
    
    2. Azure DR 환경 상태 확인:
       - Azure Portal에서 App Service 상태 확인
       - MySQL Flexible Server 상태 확인
       - VPN 연결 상태 확인
    
    3. Route53 DNS Failover 실행:
       aws route53 change-resource-record-sets \
         --hosted-zone-id <YOUR_HOSTED_ZONE_ID> \
         --change-batch '{
           "Changes": [{
             "Action": "UPSERT",
             "ResourceRecordSet": {
               "Name": "www.yourdomain.com",
               "Type": "CNAME",
               "TTL": 60,
               "ResourceRecords": [{"Value": "${azurerm_linux_web_app.dr.default_hostname}"}]
             }
           }]
         }'
    
    4. 데이터베이스 동기화 확인:
       - Azure MySQL에 최신 데이터가 복제되었는지 확인
       - 필요 시 마지막 백업 복원
    
    5. 애플리케이션 설정 업데이트:
       - DR 모드로 전환된 것 확인
       - 로깅 및 모니터링 확인
    
    6. 트래픽 전환 완료 확인:
       - 실제 사용자 트래픽이 Azure로 전환되었는지 확인
       - 응답 시간 및 에러율 모니터링
    
    ===== ROLLBACK (AWS로 복구) =====
    
    1. AWS 리전 복구 확인
    2. Route53 DNS를 다시 AWS로 변경
    3. 데이터베이스 역동기화 (필요 시)
    4. AWS CloudFront 캐시 초기화
    
    ==========================================
  EOT
}

output "vpn_setup_guide" {
  description = "Guide for setting up AWS-Azure VPN connection"
  value = <<-EOT
    
    ===== AWS-AZURE VPN SETUP GUIDE =====
    
    Azure VPN Gateway Public IP: ${azurerm_public_ip.vpn_gateway.ip_address}
    Azure BGP ASN: ${azurerm_virtual_network_gateway.vpn.bgp_settings[0].asn}
    Azure BGP Peering Address: ${azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses[0].default_addresses[0]}
    
    AWS 측에서 다음 작업 수행:
    
    1. AWS VPN Connection 생성:
       - Customer Gateway 생성 (Azure VPN Gateway Public IP 사용)
       - VPN Connection을 Transit Gateway에 연결
       - BGP ASN: ${azurerm_virtual_network_gateway.vpn.bgp_settings[0].asn}
    
    2. AWS VPN Connection 생성 후 다음 정보를 variables.tf에 업데이트:
       - aws_vpn_gateway_ip: AWS VPN Tunnel 1 Public IP
       - aws_bgp_peering_address: AWS BGP Peering Address
       - vpn_shared_key: AWS VPN Connection Shared Key
    
    3. Terraform 재적용:
       terraform apply -var="aws_vpn_gateway_ip=<AWS_VPN_IP>" \
                       -var="aws_bgp_peering_address=<AWS_BGP_IP>" \
                       -var="vpn_shared_key=<SHARED_KEY>"
    
    4. VPN 연결 상태 확인:
       Azure Portal > Virtual Network Gateway > Connections
       AWS Console > VPC > VPN Connections
    
    =======================================
  EOT
}
