output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront Distribution Hosted Zone ID (for Route53)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "cloudfront_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_status" {
  description = "CloudFront Distribution Status"
  value       = aws_cloudfront_distribution.main.status
}

output "cloudfront_url" {
  description = "CloudFront Distribution HTTPS URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "origin_group_config" {
  description = "Origin Group Configuration"
  value = {
    primary_origin  = "seoul-beanstalk (ap-northeast-2)"
    failover_origin = "tokyo-beanstalk (ap-northeast-1)"
    failover_codes  = [500, 502, 503, 504, 404, 403]
  }
}

output "cache_policy_id" {
  description = "Custom Cache Policy ID"
  value       = aws_cloudfront_cache_policy.optimized.id
}

output "origin_request_policy_id" {
  description = "Custom Origin Request Policy ID"
  value       = aws_cloudfront_origin_request_policy.all_viewer.id
}

output "response_headers_policy_id" {
  description = "Custom Response Headers Policy ID"
  value       = aws_cloudfront_response_headers_policy.security_headers.id
}

output "cloudfront_function_arn" {
  description = "CloudFront Function ARN for URL Rewrite"
  value       = aws_cloudfront_function.url_rewrite.arn
}
