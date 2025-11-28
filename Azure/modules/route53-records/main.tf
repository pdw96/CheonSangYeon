# ===== AWS Route53 Records for Azure DR Module =====
# Creates Route53 DNS records for Azure endpoints

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get Route53 Hosted Zone from remote state
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = var.route53_state_key
    region = var.aws_region
  }
}

# Azure DR subdomain (CNAME to Azure App Service)
resource "aws_route53_record" "azure_dr" {
  count = var.create_dns_record ? 1 : 0

  zone_id = data.terraform_remote_state.route53.outputs.route53_zone_id
  name    = var.subdomain_name
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.azure_endpoint_fqdn]
}

# Azure DR TXT record (for verification or metadata)
resource "aws_route53_record" "azure_dr_txt" {
  count = var.create_txt_record ? 1 : 0

  zone_id = data.terraform_remote_state.route53.outputs.route53_zone_id
  name    = var.subdomain_name
  type    = "TXT"
  ttl     = 3600
  records = var.txt_records
}

# Failover routing policy (Primary: Seoul/Tokyo, Secondary: Azure)
resource "aws_route53_record" "failover_primary" {
  count = var.enable_failover_routing ? 1 : 0

  zone_id = data.terraform_remote_state.route53.outputs.route53_zone_id
  name    = var.failover_subdomain
  type    = "CNAME"
  ttl     = var.ttl

  set_identifier = "primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = var.primary_health_check_id
  records         = [var.primary_endpoint_fqdn]
}

resource "aws_route53_record" "failover_secondary" {
  count = var.enable_failover_routing ? 1 : 0

  zone_id = data.terraform_remote_state.route53.outputs.route53_zone_id
  name    = var.failover_subdomain
  type    = "CNAME"
  ttl     = var.ttl

  set_identifier = "secondary"
  
  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = var.secondary_health_check_id
  records         = [var.azure_endpoint_fqdn]
}
