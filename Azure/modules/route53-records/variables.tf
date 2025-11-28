variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "route53_state_key" {
  description = "State key for Route53 remote state"
  type        = string
  default     = "terraform/global-route53/terraform.tfstate"
}

variable "create_dns_record" {
  description = "Create DNS record for Azure endpoint"
  type        = bool
  default     = true
}

variable "subdomain_name" {
  description = "Subdomain name for Azure DR (e.g., azure.example.com)"
  type        = string
}

variable "azure_endpoint_fqdn" {
  description = "Azure App Service FQDN"
  type        = string
}

variable "ttl" {
  description = "DNS TTL in seconds"
  type        = number
  default     = 300
}

variable "create_txt_record" {
  description = "Create TXT record for verification"
  type        = bool
  default     = false
}

variable "txt_records" {
  description = "TXT record values"
  type        = list(string)
  default     = []
}

variable "enable_failover_routing" {
  description = "Enable failover routing policy"
  type        = bool
  default     = false
}

variable "failover_subdomain" {
  description = "Subdomain for failover routing (e.g., app.example.com)"
  type        = string
  default     = ""
}

variable "primary_endpoint_fqdn" {
  description = "Primary endpoint FQDN (e.g., CloudFront or Seoul Beanstalk)"
  type        = string
  default     = ""
}

variable "primary_health_check_id" {
  description = "Health check ID for primary endpoint"
  type        = string
  default     = ""
}

variable "secondary_health_check_id" {
  description = "Health check ID for secondary (Azure) endpoint"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
