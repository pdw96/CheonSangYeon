terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for Terraform State
  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/azure-dr/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

provider "azurerm" {
  skip_provider_registration = true
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# ===== Data Sources =====

data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "aurora" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-aurora/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-route53/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ===== Azure Resource Group =====

resource "azurerm_resource_group" "dr" {
  name     = var.resource_group_name
  location = var.azure_location

  tags = {
    Environment = "DR"
    Purpose     = "Disaster Recovery for AWS"
    Region      = var.azure_location
  }
}

# ===== Azure Virtual Network =====

resource "azurerm_virtual_network" "dr" {
  name                = var.vnet_name
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  address_space       = var.vnet_address_space

  tags = {
    Environment = "DR"
    Purpose     = "DR VNet"
  }
}

# Subnet for App Services
resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.dr.name
  virtual_network_name = azurerm_virtual_network.dr.name
  address_prefixes     = [var.app_subnet_cidr]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Database
resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.dr.name
  virtual_network_name = azurerm_virtual_network.dr.name
  address_prefixes     = [var.db_subnet_cidr]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Subnet for VPN Gateway
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.dr.name
  virtual_network_name = azurerm_virtual_network.dr.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# ===== Network Security Groups =====

resource "azurerm_network_security_group" "app" {
  name                = "app-nsg"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "DR"
  }
}

resource "azurerm_network_security_group" "db" {
  name                = "db-nsg"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name

  security_rule {
    name                       = "Allow-MySQL-from-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = var.app_subnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-MySQL-from-AWS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefixes    = ["20.0.0.0/16", "40.0.0.0/16"]
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "DR"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

# ===== Module: DMS Integration (MySQL for AWS DMS) =====

module "dms_integration" {
  source = "./modules/dms-integration"

  resource_group_name = azurerm_resource_group.dr.name
  location            = azurerm_resource_group.dr.location

  mysql_server_name      = var.mysql_server_name
  mysql_admin_username   = var.mysql_admin_username
  mysql_admin_password   = var.mysql_admin_password
  mysql_sku_name         = var.mysql_sku_name
  mysql_storage_gb       = var.mysql_storage_gb
  database_name          = var.mysql_database_name

  db_subnet_id = azurerm_subnet.db.id
  vnet_id      = azurerm_virtual_network.dr.id

  private_dns_zone_name = "mysql-dr-multicloud.private.mysql.database.azure.com"
  aws_vpc_cidr_start    = "20.0.0.0"
  aws_vpc_cidr_end      = "20.255.255.255"

  tags = {
    Environment = "DR"
    Purpose     = "DMS Target Database"
  }

  depends_on = [
    azurerm_subnet.db,
    azurerm_virtual_network.dr
  ]
}

# ===== AWS Route53 Private Hosted Zone for Azure MySQL =====
# AWS에서 Azure MySQL Private DNS를 해석하기 위한 Private Hosted Zone

resource "aws_route53_zone" "azure_mysql_private" {
  provider = aws.seoul
  name     = "private.mysql.database.azure.com"
  comment  = "Private Hosted Zone for Azure MySQL resolution from AWS"

  vpc {
    vpc_id     = data.terraform_remote_state.seoul.outputs.seoul_vpc_id
    vpc_region = "ap-northeast-2"
  }

  tags = {
    Name        = "azure-mysql-private-zone"
    Environment = "DR"
    Purpose     = "Azure MySQL DNS Resolution"
    ManagedBy   = "Terraform-Azure-Module"
  }
}

# Azure MySQL Private IP를 위한 A 레코드
resource "aws_route53_record" "azure_mysql" {
  provider = aws.seoul
  zone_id  = aws_route53_zone.azure_mysql_private.zone_id
  name     = "mysql-dr-multicloud"
  type     = "A"
  ttl      = 300
  records  = ["50.0.2.4"]  # Azure MySQL Private IP

  depends_on = [
    module.dms_integration
  ]
}

# ===== Module: ECR App Service =====
# ECR 이미지가 준비된 후 deploy_app_service = true로 설정하여 배포
# 프론트엔드 CI/CD 담당자가 ECR에 이미지 푸시 후 진행

module "ecr_appservice" {
  source = "./modules/ecr-appservice"
  count  = var.deploy_app_service ? 1 : 0

  resource_group_name   = azurerm_resource_group.dr.name
  location              = azurerm_resource_group.dr.location
  app_service_plan_name = var.app_service_plan_name
  app_service_sku       = var.app_service_sku
  web_app_name          = var.web_app_name

  # ECR 설정 (AWS Beanstalk와 동일한 이미지 사용)
  ecr_registry_url = var.ecr_registry_url
  ecr_image_name   = var.ecr_image_name
  ecr_username     = var.ecr_username
  ecr_password     = var.ecr_password

  # VNet 통합
  vnet_integration_enabled = true
  app_subnet_id            = azurerm_subnet.app.id

  # 데이터베이스 연결 (Azure MySQL)
  database_connection_enabled = true
  db_host                     = module.dms_integration.mysql_server_fqdn
  db_name                     = module.dms_integration.database_name
  db_user                     = var.mysql_admin_username
  db_password                 = var.mysql_admin_password
  db_port                     = "3306"

  tags = {
    Environment = "DR"
    Purpose     = "DR Web Application with ECR"
  }

  depends_on = [
    module.dms_integration,
    azurerm_subnet.app
  ]
}

# ===== Module: Route53 Health Check =====
# App Service 배포 후 자동으로 Health Check 생성

module "route53_healthcheck" {
  source = "./modules/route53-healthcheck"
  count  = var.deploy_app_service ? 1 : 0

  providers = {
    aws = aws.seoul
  }

  endpoint_fqdn      = module.ecr_appservice[0].web_app_default_hostname
  endpoint_port      = 443
  health_check_type  = "HTTPS"
  health_check_path  = "/health"
  health_check_name  = "azure-dr-health-check"

  alarm_name        = "azure-dr-endpoint-unhealthy"
  alarm_description = "Alert when Azure DR endpoint is unhealthy"

  enable_latency_alarm = true
  latency_threshold_ms = 1000

  tags = {
    Environment = "DR"
    Target      = "Azure"
  }

  depends_on = [
    module.ecr_appservice
  ]
}

# ===== Module: AWS DMS Migration (Aurora → Azure MySQL) =====

module "aws_dms_migration" {
  source = "./modules/aws-dms-migration"

  providers = {
    aws = aws.seoul
  }

  terraform_state_bucket = "terraform-s3-cheonsangyeon"
  aws_region             = "ap-northeast-2"

  # Source (Aurora)
  source_database_name = "globaldb"  # Aurora target 엔드포인트에 설정된 DB
  source_username      = "admin"
  source_password      = "AdminPassword123!"

  # Target (Azure MySQL)
  azure_mysql_endpoint = module.dms_integration.mysql_server_fqdn
  target_database_name = "globaldb"  # Azure MySQL 대상 DB
  target_username      = var.mysql_admin_username
  target_password      = var.mysql_admin_password

  # Migration settings
  migration_type       = "full-load"
  transform_schema     = false  # 스키마 변환 없이 그대로 복제
  auto_start_migration = var.enable_auto_dms_migration

  tags = {
    Environment = "DR"
    Purpose     = "Aurora to Azure MySQL Migration"
  }

  depends_on = [
    module.dms_integration
  ]
}

# ===== Module: AWS VPN Connection (Azure → Seoul Transit Gateway) =====

module "aws_vpn_connection" {
  source = "./modules/aws-vpn-connection"

  providers = {
    aws = aws.seoul
  }

  # Seoul State 정보
  seoul_state_bucket = "terraform-s3-cheonsangyeon"
  seoul_state_key    = "terraform/seoul/terraform.tfstate"

  # Azure VPN Gateway 정보
  azure_vpn_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
  azure_bgp_asn        = 65515
  azure_vnet_cidr      = var.vnet_address_space[0]
  azure_vpn_shared_key = var.vpn_shared_key

  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

# ===== Module: Route53 DNS Records for Azure =====

module "route53_records" {
  source = "./modules/route53-records"

  providers = {
    aws = aws.seoul
  }

  terraform_state_bucket = "terraform-s3-cheonsangyeon"

  # DNS 레코드 설정
  create_dns_record   = var.create_azure_dns_record
  subdomain_name      = "azure.${data.terraform_remote_state.route53.outputs.domain_name}"
  azure_endpoint_fqdn = "webapp-dr-multicloud.azurewebsites.net"  # ECR App Service 배포 후 업데이트
  ttl                 = 300

  # Failover 라우팅 (선택사항)
  enable_failover_routing  = var.enable_failover_routing
  failover_subdomain       = "app.${data.terraform_remote_state.route53.outputs.domain_name}"
  primary_endpoint_fqdn    = data.terraform_remote_state.route53.outputs.cloudfront_url
  primary_health_check_id  = data.terraform_remote_state.route53.outputs.health_checks.seoul
  # ECR App Service 별도 배포로 인해 주석 처리
  # secondary_health_check_id = module.route53_healthcheck.health_check_id

  tags = {
    Environment = "DR"
    Purpose     = "Azure DR DNS Records"
  }

  depends_on = [
    azurerm_subnet.app
  ]
}

# ===== Azure Storage Account =====

resource "azurerm_storage_account" "dr" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dr.name
  location                 = azurerm_resource_group.dr.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"

  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Environment = "DR"
    Purpose     = "DR Storage and Backups"
  }
}

resource "azurerm_storage_container" "backups" {
  name                  = "database-backups"
  storage_account_name  = azurerm_storage_account.dr.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "assets" {
  name                  = "static-assets"
  storage_account_name  = azurerm_storage_account.dr.name
  container_access_type = "blob"
}

# ===== Azure VPN Gateway =====

resource "azurerm_public_ip" "vpn_gateway" {
  name                = "vpn-gateway-pip"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "DR"
    Purpose     = "VPN Gateway Public IP"
  }
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vpn_gateway_name
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.vpn_gateway_sku

  depends_on = [
    azurerm_subnet.gateway,
    azurerm_virtual_network.dr,
    azurerm_public_ip.vpn_gateway
  ]

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = {
    Environment = "DR"
    Purpose     = "AWS-Azure VPN Connection"
  }
}

resource "azurerm_local_network_gateway" "aws_seoul" {
  name                = "aws-seoul-lng"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  
  # AWS VPN Tunnel 1 IP (from VPN module)
  gateway_address = module.aws_vpn_connection.tunnel_1_address
  
  # Seoul VPC CIDR
  address_space = ["20.0.0.0/16"]

  tags = {
    Environment = "DR"
    ManagedBy   = "Terraform-Azure-Module"
  }

  depends_on = [
    module.aws_vpn_connection
  ]
}

resource "azurerm_virtual_network_gateway_connection" "aws_azure" {
  name                = "aws-azure-vpn-connection"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_seoul.id

  shared_key = var.vpn_shared_key
  enable_bgp = false

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_lifetime      = 3600
  }

  tags = {
    Environment = "DR"
    Purpose     = "Hybrid Cloud Connectivity"
  }

  depends_on = [
    azurerm_virtual_network_gateway.vpn,
    azurerm_local_network_gateway.aws_seoul
  ]

  lifecycle {
    replace_triggered_by = [
      azurerm_local_network_gateway.aws_seoul.gateway_address
    ]
  }
}

# ===== Azure Monitor & Alerts =====

resource "azurerm_monitor_action_group" "dr_alerts" {
  name                = "dr-action-group"
  resource_group_name = azurerm_resource_group.dr.name
  short_name          = "dralerts"

  email_receiver {
    name          = "sendtoadmin"
    email_address = var.alert_email
  }

  tags = {
    Environment = "DR"
  }
}

# NOTE: ECR App Service 배포 후 활성화
# resource "azurerm_monitor_metric_alert" "app_down" {
#   name                = "app-service-down-alert"
#   resource_group_name = azurerm_resource_group.dr.name
#   scopes              = ["/subscriptions/92248bea-a019-4629-92b9-4db0e2ecab1b/resourceGroups/rg-dr-multicloud/providers/Microsoft.Web/sites/webapp-dr-multicloud"]
#   description         = "Alert when DR app service is down"
#   severity            = 0
#
#   criteria {
#     metric_namespace = "Microsoft.Web/sites"
#     metric_name      = "HealthCheckStatus"
#     aggregation      = "Average"
#     operator         = "LessThan"
#     threshold        = 50
#   }
#
#   frequency   = "PT1M"
#   window_size = "PT5M"
#
#   action {
#     action_group_id = azurerm_monitor_action_group.dr_alerts.id
#   }
#
#   tags = {
#     Environment = "DR"
#   }
# }
