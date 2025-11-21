

output "cgw_instance_id" {
  description = "CGW instance ID"
  value       = aws_instance.cgw.id
}

output "cgw_instance_public_ip" {
  description = "CGW instance Elastic IP"
  value       = aws_eip_association.cgw.public_ip
}

output "cgw_network_interface_id" {
  description = "CGW network interface ID"
  value       = aws_instance.cgw.primary_network_interface_id
}

output "db_instance_id" {
  description = "DB instance ID"
  value       = aws_instance.db.id
}

output "db_instance_private_ip" {
  description = "DB instance private IP"
  value       = aws_instance.db.private_ip
}
