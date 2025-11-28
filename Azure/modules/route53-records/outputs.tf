output "dns_record_name" {
  description = "DNS record name"
  value       = var.create_dns_record ? aws_route53_record.azure_dr[0].name : null
}

output "dns_record_fqdn" {
  description = "DNS record FQDN"
  value       = var.create_dns_record ? aws_route53_record.azure_dr[0].fqdn : null
}

output "failover_primary_name" {
  description = "Failover primary record name"
  value       = var.enable_failover_routing ? aws_route53_record.failover_primary[0].name : null
}

output "failover_secondary_name" {
  description = "Failover secondary record name"
  value       = var.enable_failover_routing ? aws_route53_record.failover_secondary[0].name : null
}
