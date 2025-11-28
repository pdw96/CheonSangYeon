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
    key            = "terraform/azure-ecr-appservice/terraform.tfstate"
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
  }
}

# Azure DR 인프라 상태 참조
data "terraform_remote_state" "azure_dr" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/azure-dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AWS Provider 설정 (ECR 조회용)
provider "aws" {
  region = "ap-northeast-2"
}

# ECR Repository 조회
data "aws_ecr_repository" "seoul_frontend" {
  name = "seoul-portal-seoul-frontend"
}

# AWS Caller Identity (Account ID 조회)
data "aws_caller_identity" "current" {}

# ===== ECR App Service 배포 =====

module "ecr_appservice" {
  source = "../../modules/ecr-appservice"

  resource_group_name    = data.terraform_remote_state.azure_dr.outputs.resource_group_name
  location               = data.terraform_remote_state.azure_dr.outputs.resource_group_location
  app_service_plan_name  = var.app_service_plan_name
  app_service_sku        = var.app_service_sku
  web_app_name           = var.web_app_name

  # ECR 설정 (동적으로 조회)
  ecr_registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com"
  ecr_image_name   = "${data.aws_ecr_repository.seoul_frontend.name}:latest"
  ecr_username     = var.ecr_username
  ecr_password     = var.ecr_password

  # VNet 통합
  vnet_integration_enabled = true
  app_subnet_id            = data.terraform_remote_state.azure_dr.outputs.app_subnet_id

  # 데이터베이스 연결
  database_connection_enabled = true
  db_host                     = data.terraform_remote_state.azure_dr.outputs.mysql_server_fqdn
  db_name                     = data.terraform_remote_state.azure_dr.outputs.mysql_database_name
  db_user                     = var.mysql_admin_username
  db_password                 = var.mysql_admin_password
  db_port                     = "3306"

  tags = {
    Environment = "DR"
    Purpose     = "DR Web Application with ECR"
  }
}

# ===== Route53 DNS Records =====

module "route53_records" {
  source = "../../modules/route53-records"

  # Terraform State 설정
  terraform_state_bucket = "terraform-s3-cheonsangyeon"
  route53_state_key      = "terraform/global-route53/terraform.tfstate"
  aws_region             = "ap-northeast-2"

  # Azure DR Subdomain
  create_dns_record   = true
  subdomain_name      = "azure-app"
  azure_endpoint_fqdn = module.ecr_appservice.web_app_default_hostname
  ttl                 = 300

  # Failover Routing (추후 Health Check 추가 시 활성화)
  enable_failover_routing = false
  # failover_subdomain      = "app"
  # primary_endpoint_fqdn   = "seoul-app.cloudupcon.cloud"
  # primary_health_check_id = "health-check-id"
  # secondary_health_check_id = "health-check-id"
}
