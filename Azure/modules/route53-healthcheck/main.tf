# ===== AWS Route53 Health Check for Azure DR Module =====
# Creates Route53 health checks and CloudWatch alarms for Azure endpoints

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Route53 Health Check for Azure endpoint
resource "aws_route53_health_check" "azure_endpoint" {
  fqdn              = var.endpoint_fqdn
  port              = var.endpoint_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval
  measure_latency   = var.measure_latency

  tags = merge(
    var.tags,
    {
      Name        = var.health_check_name
      Environment = "DR"
      Target      = "Azure"
    }
  )
}

# CloudWatch Alarm for Health Check
resource "aws_cloudwatch_metric_alarm" "endpoint_unhealthy" {
  alarm_name          = var.alarm_name
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = var.alarm_period
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = var.alarm_description
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.azure_endpoint.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.tags,
    {
      Environment = "DR"
      Target      = "Azure"
    }
  )
}

# CloudWatch Alarm for High Latency (선택사항)
resource "aws_cloudwatch_metric_alarm" "endpoint_high_latency" {
  count = var.enable_latency_alarm ? 1 : 0

  alarm_name          = "${var.alarm_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "TimeToFirstByte"
  namespace           = "AWS/Route53"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.latency_threshold_ms
  alarm_description   = "Alert when Azure DR endpoint has high latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.azure_endpoint.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.tags,
    {
      Environment = "DR"
      Target      = "Azure"
      Type        = "Latency"
    }
  )
}
