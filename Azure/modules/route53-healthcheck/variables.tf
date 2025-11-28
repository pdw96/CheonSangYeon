variable "endpoint_fqdn" {
  description = "FQDN of the Azure endpoint to monitor"
  type        = string
}

variable "endpoint_port" {
  description = "Port to check (80, 443, etc.)"
  type        = number
  default     = 443
}

variable "health_check_type" {
  description = "Health check type (HTTP, HTTPS, TCP)"
  type        = string
  default     = "HTTPS"
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "health_check_name" {
  description = "Name for the health check"
  type        = string
}

variable "failure_threshold" {
  description = "Number of consecutive failures before unhealthy"
  type        = number
  default     = 3
}

variable "request_interval" {
  description = "Health check interval in seconds (10 or 30)"
  type        = number
  default     = 30
}

variable "measure_latency" {
  description = "Measure latency for the health check"
  type        = bool
  default     = true
}

variable "alarm_name" {
  description = "CloudWatch alarm name"
  type        = string
}

variable "alarm_description" {
  description = "CloudWatch alarm description"
  type        = string
  default     = "Alert when Azure DR endpoint is unhealthy"
}

variable "evaluation_periods" {
  description = "Number of periods to evaluate"
  type        = number
  default     = 2
}

variable "alarm_period" {
  description = "Alarm evaluation period in seconds"
  type        = number
  default     = 60
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when alarm recovers"
  type        = list(string)
  default     = []
}

variable "enable_latency_alarm" {
  description = "Enable high latency alarm"
  type        = bool
  default     = false
}

variable "latency_threshold_ms" {
  description = "Latency threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
