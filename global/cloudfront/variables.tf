variable "domain_name" {
  description = "Primary domain name (e.g., example.com)"
  type        = string
  default     = "pdwo610.shop"
}

variable "enable_custom_domain" {
  description = "Enable custom domain configuration (requires Route 53 module deployed)"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable AWS WAF for CloudFront"
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "geo_restriction_type" {
  description = "Geographic restriction type (whitelist, blacklist, none)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geographic restriction"
  type        = list(string)
  default     = []
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_All"
}
