output "mysql_server_id" {
  description = "MySQL Flexible Server ID"
  value       = azurerm_mysql_flexible_server.dms_target.id
}

output "mysql_server_fqdn" {
  description = "MySQL Flexible Server FQDN"
  value       = azurerm_mysql_flexible_server.dms_target.fqdn
}

output "mysql_server_name" {
  description = "MySQL Flexible Server name"
  value       = azurerm_mysql_flexible_server.dms_target.name
}

output "database_name" {
  description = "Database name"
  value       = azurerm_mysql_flexible_database.app_db.name
}

output "private_dns_zone_id" {
  description = "Private DNS Zone ID"
  value       = azurerm_private_dns_zone.mysql.id
}

output "connection_string" {
  description = "MySQL connection string (without password)"
  value       = "Server=${azurerm_mysql_flexible_server.dms_target.fqdn};Database=${azurerm_mysql_flexible_database.app_db.name};Uid=${var.mysql_admin_username}"
  sensitive   = false
}
