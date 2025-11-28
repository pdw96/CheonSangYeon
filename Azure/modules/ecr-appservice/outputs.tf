output "app_service_plan_id" {
  description = "App Service Plan ID"
  value       = azurerm_service_plan.ecr_app.id
}

output "web_app_id" {
  description = "Web App ID"
  value       = azurerm_linux_web_app.ecr_app.id
}

output "web_app_name" {
  description = "Web App name"
  value       = azurerm_linux_web_app.ecr_app.name
}

output "web_app_default_hostname" {
  description = "Web App default hostname"
  value       = azurerm_linux_web_app.ecr_app.default_hostname
}

output "web_app_url" {
  description = "Web App URL"
  value       = "https://${azurerm_linux_web_app.ecr_app.default_hostname}"
}

output "outbound_ip_addresses" {
  description = "Web App outbound IP addresses"
  value       = azurerm_linux_web_app.ecr_app.outbound_ip_addresses
}

output "possible_outbound_ip_addresses" {
  description = "Web App possible outbound IP addresses"
  value       = azurerm_linux_web_app.ecr_app.possible_outbound_ip_addresses
}
