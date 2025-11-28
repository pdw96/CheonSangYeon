# ===== App Service Outputs =====

output "app_service_plan_id" {
  description = "App Service Plan ID"
  value       = module.ecr_appservice.app_service_plan_id
}

output "web_app_id" {
  description = "Web App ID"
  value       = module.ecr_appservice.web_app_id
}

output "web_app_name" {
  description = "Web App name"
  value       = module.ecr_appservice.web_app_name
}

output "web_app_url" {
  description = "Web App URL"
  value       = module.ecr_appservice.web_app_url
}

output "web_app_default_hostname" {
  description = "Web App default hostname"
  value       = module.ecr_appservice.web_app_default_hostname
}

output "outbound_ip_addresses" {
  description = "Web App outbound IP addresses"
  value       = module.ecr_appservice.outbound_ip_addresses
}

output "possible_outbound_ip_addresses" {
  description = "Possible outbound IP addresses"
  value       = module.ecr_appservice.possible_outbound_ip_addresses
}

# ===== Route53 Outputs =====

output "azure_dns_record" {
  description = "Azure DNS record FQDN"
  value       = module.route53_records.dns_record_fqdn
}

output "azure_dns_record_name" {
  description = "Azure DNS record name"
  value       = "azure-app.cloudupcon.cloud"
}
