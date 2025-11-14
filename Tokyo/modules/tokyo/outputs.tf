output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_nat_subnet_ids" {
  description = "Public NAT subnet IDs"
  value       = aws_subnet.public_nat[*].id
}

output "vpn_gateway_subnet_id" {
  description = "VPN Gateway subnet ID"
  value       = aws_subnet.vpn_gateway.id
}

output "beanstalk_subnet_ids" {
  description = "Beanstalk subnet IDs"
  value       = aws_subnet.private_beanstalk[*].id
}

output "tgw_subnet_id" {
  description = "Transit Gateway subnet ID"
  value       = aws_subnet.tgw.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "private_route_table_id" {
  description = "Private route table ID for Beanstalk"
  value       = aws_route_table.private_beanstalk.id
}

