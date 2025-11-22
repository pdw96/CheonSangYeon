output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Route 53 Name Servers (configure these at your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "The domain name"
  value       = "pdwo610.shop"
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
  value       = "https://pdwo610.shop"
}

output "www_url" {
  description = "WWW URL"
  value       = "https://www.pdwo610.shop"
}

output "seoul_url" {
  description = "Seoul region direct URL"
  value       = "https://seoul.pdwo610.shop"
}

output "tokyo_url" {
  description = "Tokyo region direct URL"
  value       = "https://tokyo.pdwo610.shop"
}

output "dns_records" {
  description = "Summary of DNS Records"
  value = {
    root_domain = {
      A    = "pdwo610.shop → CloudFront"
      AAAA = "pdwo610.shop → CloudFront (IPv6)"
    }
    www = {
      A    = "www.pdwo610.shop → CloudFront"
      AAAA = "www.pdwo610.shop → CloudFront (IPv6)"
    }
    seoul = "seoul.pdwo610.shop → Seoul Beanstalk"
    tokyo = "tokyo.pdwo610.shop → Tokyo Beanstalk"
  }
}

output "health_checks" {
  description = "Health Check IDs"
  value = {
    seoul = aws_route53_health_check.seoul_beanstalk.id
    tokyo = aws_route53_health_check.tokyo_beanstalk.id
  }
}
