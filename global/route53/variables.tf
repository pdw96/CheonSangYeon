variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "pdwo610.shop"
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks for Beanstalk environments"
  type        = bool
  default     = true
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for the hosted zone"
  type        = bool
  default     = false
}

variable "subdomain_ttl" {
  description = "TTL for subdomain records"
  type        = number
  default     = 300
}
