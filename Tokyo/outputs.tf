output "tokyo_vpc_id" {
  description = "Tokyo VPC ID"
  value       = data.terraform_remote_state.global_vpc.outputs.tokyo_vpc_id
}

output "idc_vpc_id" {
  description = "IDC VPC ID"
  value       = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_vpc_id
}

output "idc_cgw_instance_id" {
  description = "IDC CGW Instance ID"
  value       = module.idc.cgw_instance_id
}

output "idc_cgw_instance_public_ip" {
  description = "IDC CGW Instance Public IP"
  value       = module.idc.cgw_instance_public_ip
}

output "idc_db_instance_id" {
  description = "IDC DB Instance ID"
  value       = module.idc.db_instance_id
}

output "idc_db_instance_private_ip" {
  description = "IDC DB Instance Private IP"
  value       = module.idc.db_instance_private_ip
}

output "idc_db_instance_public_ip" {
  description = "IDC DB Instance Public IP (임시)"
  value       = module.idc.db_instance_public_ip
}

output "customer_gateway_id" {
  description = "Customer Gateway ID"
  value       = aws_customer_gateway.idc.id
}

output "vpn_connection_id" {
  description = "VPN Connection ID"
  value       = aws_vpn_connection.tokyo_to_idc.id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "tokyo_beanstalk_subnet_ids" {
  description = "Tokyo Elastic Beanstalk Subnet IDs"
  value       = data.terraform_remote_state.global_vpc.outputs.tokyo_private_beanstalk_subnet_ids
}

output "aws_managed_vpn_status" {
  description = "AWS Managed VPN Status"
  value       = "AWS Managed VPN Connection established between Tokyo Transit Gateway and IDC Customer Gateway"
}

output "vpn_tunnel_addresses" {
  description = "VPN Tunnel IP Addresses"
  value = {
    tunnel_1_address = aws_vpn_connection.tokyo_to_idc.tunnel1_address
    tunnel_2_address = aws_vpn_connection.tokyo_to_idc.tunnel2_address
    idc_cgw_ip       = module.idc.cgw_instance_public_ip
  }
}

output "beanstalk_application_name" {
  description = "Elastic Beanstalk Application Name"
  value       = aws_elastic_beanstalk_application.tokyo_app.name
}

output "beanstalk_environment_name" {
  description = "Elastic Beanstalk Environment Name"
  value       = aws_elastic_beanstalk_environment.tokyo_env.name
}

output "beanstalk_environment_url" {
  description = "Elastic Beanstalk Environment URL"
  value       = aws_elastic_beanstalk_environment.tokyo_env.endpoint_url
}

output "beanstalk_cname" {
  description = "Elastic Beanstalk CNAME"
  value       = aws_elastic_beanstalk_environment.tokyo_env.cname
}
