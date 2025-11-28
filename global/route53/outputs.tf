output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID (alias for compatibility)"
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Route 53 Name Servers (configure these at your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "The domain name"
  value       = var.domain_name
}

output "acm_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "acm_certificate_status" {
  description = "ACM Certificate Validation Status"
  value       = aws_acm_certificate.cloudfront.status
}

output "cloudfront_url" {
  description = "CloudFront URL"
  value       = "https://${var.domain_name}"
}

output "www_url" {
  description = "WWW URL"
  value       = "https://www.${var.domain_name}"
}

output "seoul_url" {
  description = "Seoul region direct URL"
  value       = "https://seoul.${var.domain_name}"
}

output "tokyo_url" {
  description = "Tokyo region direct URL"
  value       = "https://tokyo.${var.domain_name}"
}

output "dns_records" {
  description = "Summary of DNS Records"
  value = {
    root_domain = {
      A    = "${var.domain_name} → CloudFront"
      AAAA = "${var.domain_name} → CloudFront (IPv6)"
    }
    www = {
      A    = "www.${var.domain_name} → CloudFront"
      AAAA = "www.${var.domain_name} → CloudFront (IPv6)"
    }
    seoul = "seoul.${var.domain_name} → Seoul Beanstalk"
    tokyo = "tokyo.${var.domain_name} → Tokyo Beanstalk"
  }
}

output "health_checks" {
  description = "Health Check IDs"
  value = {
    seoul = aws_route53_health_check.seoul_beanstalk.id
    tokyo = aws_route53_health_check.tokyo_beanstalk.id
  }
}
