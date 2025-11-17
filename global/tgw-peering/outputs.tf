output "peering_attachment_id" {
  description = "Transit Gateway Peering Attachment ID"
  value       = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
}

output "peering_state" {
  description = "Transit Gateway Peering State"
  value       = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.state
}

output "seoul_tgw_id" {
  description = "Seoul Transit Gateway ID"
  value       = data.aws_ec2_transit_gateway.seoul.id
}

output "tokyo_tgw_id" {
  description = "Tokyo Transit Gateway ID"
  value       = data.aws_ec2_transit_gateway.tokyo.id
}
