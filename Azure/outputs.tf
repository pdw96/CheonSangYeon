# ===== Module Outputs =====

# DMS Integration Module
output "mysql_server_fqdn" {
  description = "MySQL Flexible Server FQDN"
  value       = module.dms_integration.mysql_server_fqdn
}

output "mysql_database_name" {
  description = "MySQL database name"
  value       = module.dms_integration.database_name
}

# ECR App Service Module (별도 배포)
# output "web_app_url" {
#   description = "Web App URL"
#   value       = module.ecr_appservice.web_app_url
# }

# output "web_app_default_hostname" {
#   description = "Web App default hostname"
#   value       = module.ecr_appservice.web_app_default_hostname
# }

# output "web_app_outbound_ips" {
#   description = "Web App outbound IP addresses"
#   value       = module.ecr_appservice.outbound_ip_addresses
# }

# Route53 Health Check Module (ECR App Service 배포 후 활성화)
# output "route53_health_check_id" {
#   description = "Route53 Health Check ID"
#   value       = module.route53_healthcheck.health_check_id
# }

# output "cloudwatch_alarm_arn" {
#   description = "CloudWatch alarm ARN"
#   value       = module.route53_healthcheck.unhealthy_alarm_arn
# }

# AWS DMS Migration Module
output "dms_migration_task_arn" {
  description = "DMS migration task ARN"
  value       = module.aws_dms_migration.replication_task_arn
}

output "dms_migration_status" {
  description = "DMS migration task status"
  value       = module.aws_dms_migration.migration_status
}

output "dms_migration_log_group" {
  description = "DMS migration CloudWatch log group"
  value       = module.aws_dms_migration.log_group_name
}

# Route53 Records Module
output "azure_dns_record" {
  description = "Azure DNS record FQDN"
  value       = module.route53_records.dns_record_fqdn
}

output "failover_primary_record" {
  description = "Failover primary record name"
  value       = module.route53_records.failover_primary_name
}

output "failover_secondary_record" {
  description = "Failover secondary record name"
  value       = module.route53_records.failover_secondary_name
}

# ===== Infrastructure Outputs =====

output "resource_group_name" {
  description = "Azure Resource Group name"
  value       = azurerm_resource_group.dr.name
}

output "resource_group_location" {
  description = "Azure Resource Group location"
  value       = azurerm_resource_group.dr.location
}

output "vnet_id" {
  description = "Azure VNet ID"
  value       = azurerm_virtual_network.dr.id
}

output "app_subnet_id" {
  description = "App Subnet ID"
  value       = azurerm_subnet.app.id
}

output "vpn_gateway_public_ip" {
  description = "Azure VPN Gateway public IP"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "storage_account_name" {
  description = "Azure Storage Account name"
  value       = azurerm_storage_account.dr.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage Account primary blob endpoint"
  value       = azurerm_storage_account.dr.primary_blob_endpoint
}

# ===== Connection Information =====

output "mysql_connection_info" {
  description = "MySQL connection information"
  value = {
    host     = module.dms_integration.mysql_server_fqdn
    database = module.dms_integration.database_name
    port     = 3306
    username = var.mysql_admin_username
  }
  sensitive = true
}

# output "app_service_info" {
#   description = "App Service information"
#   value = {
#     name     = "webapp-dr-multicloud"
#     url      = "https://webapp-dr-multicloud.azurewebsites.net"
#     hostname = "webapp-dr-multicloud.azurewebsites.net"
#   }
# }

# ===== DR Status =====

output "dr_endpoints" {
  description = "DR endpoints for failover"
  value = {
    web_app     = "https://webapp-dr-multicloud.azurewebsites.net"  # ECR App Service 배포 후 업데이트
    health_check = "https://webapp-dr-multicloud.azurewebsites.net/health"
    database     = module.dms_integration.mysql_server_fqdn
  }
}
