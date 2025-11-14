output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cgw_subnet_id" {
  description = "CGW subnet ID"
  value       = aws_subnet.public_cgw.id
}

output "cgw_instance_id" {
  description = "CGW instance ID"
  value       = aws_instance.cgw.id
}

output "cgw_instance_public_ip" {
  description = "CGW instance Elastic IP"
  value       = aws_eip_association.cgw.public_ip
}

output "db_instance_id" {
  description = "DB instance ID"
  value       = aws_instance.db.id
}

output "db_instance_private_ip" {
  description = "DB instance private IP"
  value       = aws_instance.db.private_ip
}

output "db_subnet_id" {
  description = "DB subnet ID"
  value       = aws_subnet.private_db.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "cgw_network_interface_id" {
  description = "CGW network interface ID"
  value       = aws_instance.cgw.primary_network_interface_id
}
