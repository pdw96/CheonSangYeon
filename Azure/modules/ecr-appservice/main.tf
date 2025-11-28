# ===== ECR Integration with Azure App Service Module =====
# Deploys Azure App Service configured to pull container images from AWS ECR

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# App Service Plan
resource "azurerm_service_plan" "ecr_app" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = var.tags
}

# Linux Web App with ECR Container
resource "azurerm_linux_web_app" "ecr_app" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.ecr_app.id

  site_config {
    always_on         = var.always_on
    health_check_path = var.health_check_path
    
    # ECR 컨테이너 이미지 구성
    application_stack {
      docker_registry_url      = "https://${var.ecr_registry_url}"
      docker_image_name        = var.ecr_image_name
      docker_registry_username = var.ecr_username
      docker_registry_password = var.ecr_password
    }

    vnet_route_all_enabled = var.vnet_integration_enabled
  }

  app_settings = merge(
    {
      # Docker 관련 설정
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
      "WEBSITE_DNS_SERVER"                  = "168.63.129.16"
      "DOCKER_ENABLE_CI"                    = "true"
      
      # ECR Registry 인증
      "DOCKER_REGISTRY_SERVER_URL"      = "https://${var.ecr_registry_url}"
      "DOCKER_REGISTRY_SERVER_USERNAME" = var.ecr_username
      "DOCKER_REGISTRY_SERVER_PASSWORD" = var.ecr_password
      
      # 애플리케이션 환경 변수
      "NODE_ENV"         = var.app_environment
      "DR_MODE"          = "true"
      "PRIMARY_REGION"   = "AWS"
      "FAILOVER_ENABLED" = "true"
    },
    var.database_connection_enabled ? {
      # Database 연결 설정
      "DB_HOST"     = var.db_host
      "DB_NAME"     = var.db_name
      "DB_USER"     = var.db_user
      "DB_PASSWORD" = var.db_password
      "DB_PORT"     = var.db_port
    } : {},
    var.additional_app_settings
  )

  virtual_network_subnet_id = var.vnet_integration_enabled ? var.app_subnet_id : null

  https_only = var.https_only

  tags = merge(
    var.tags,
    {
      Purpose = "DR Web Application with ECR Integration"
    }
  )

  depends_on = [
    azurerm_service_plan.ecr_app
  ]
}

# Custom Domain (선택사항)
resource "azurerm_app_service_custom_hostname_binding" "custom_domain" {
  count               = var.custom_domain != null ? 1 : 0
  hostname            = var.custom_domain
  app_service_name    = azurerm_linux_web_app.ecr_app.name
  resource_group_name = var.resource_group_name

  depends_on = [
    azurerm_linux_web_app.ecr_app
  ]
}
