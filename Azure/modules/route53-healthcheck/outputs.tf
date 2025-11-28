output "health_check_id" {
  description = "Route53 Health Check ID"
  value       = aws_route53_health_check.azure_endpoint.id
}

output "health_check_arn" {
  description = "Route53 Health Check ARN"
  value       = aws_route53_health_check.azure_endpoint.arn
}

output "unhealthy_alarm_arn" {
  description = "CloudWatch unhealthy alarm ARN"
  value       = aws_cloudwatch_metric_alarm.endpoint_unhealthy.arn
}

output "unhealthy_alarm_name" {
  description = "CloudWatch unhealthy alarm name"
  value       = aws_cloudwatch_metric_alarm.endpoint_unhealthy.alarm_name
}

output "high_latency_alarm_arn" {
  description = "CloudWatch high latency alarm ARN (if enabled)"
  value       = var.enable_latency_alarm ? aws_cloudwatch_metric_alarm.endpoint_high_latency[0].arn : null
}

output "high_latency_alarm_name" {
  description = "CloudWatch high latency alarm name (if enabled)"
  value       = var.enable_latency_alarm ? aws_cloudwatch_metric_alarm.endpoint_high_latency[0].alarm_name : null
}
