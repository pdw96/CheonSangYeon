# ===== DMS Integration Module =====
# Azure MySQL Flexible Server configured for AWS DMS replication

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Private DNS Zone for MySQL Flexible Server
resource "azurerm_private_dns_zone" "mysql" {
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.mysql_server_name}-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Azure MySQL Flexible Server (DMS Target)
resource "azurerm_mysql_flexible_server" "dms_target" {
  name                   = var.mysql_server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  backup_retention_days  = var.backup_retention_days
  delegated_subnet_id    = var.db_subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id
  sku_name               = var.mysql_sku_name
  version                = var.mysql_version

  storage {
    auto_grow_enabled = true
    size_gb           = var.mysql_storage_gb
    iops              = var.mysql_iops
  }

  maintenance_window {
    day_of_week  = var.maintenance_day
    start_hour   = var.maintenance_hour
    start_minute = 0
  }

  tags = merge(
    var.tags,
    {
      Purpose = "DMS Replication Target from AWS Aurora"
    }
  )

  lifecycle {
    ignore_changes = [
      zone  # Azure에서 자동으로 할당한 zone은 변경하지 않음
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]
}

# Database
resource "azurerm_mysql_flexible_database" "app_db" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.dms_target.name
  charset             = var.database_charset
  collation           = var.database_collation
}

# Global Database for DMS Migration
resource "azurerm_mysql_flexible_database" "globaldb" {
  name                = "globaldb"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.dms_target.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# IDC Database for DMS Migration (from Aurora)
resource "azurerm_mysql_flexible_database" "idcdb" {
  name                = "idcdb"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.dms_target.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Firewall Rules for AWS DMS
resource "azurerm_mysql_flexible_server_firewall_rule" "aws_vpn" {
  name                = "AllowAWSVPN"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.dms_target.name
  start_ip_address    = var.aws_vpc_cidr_start
  end_ip_address      = var.aws_vpc_cidr_end
}

# Azure Services 접근 허용 (관리 목적)
resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.dms_target.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}
