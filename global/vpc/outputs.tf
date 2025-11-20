# Seoul AWS VPC Outputs
output "seoul_vpc_id" {
  description = "Seoul VPC ID"
  value       = aws_vpc.seoul.id
}

output "seoul_vpc_cidr" {
  description = "Seoul VPC CIDR block"
  value       = aws_vpc.seoul.cidr_block
}

output "seoul_public_nat_subnet_ids" {
  description = "Seoul public NAT subnet IDs"
  value       = aws_subnet.seoul_public_nat[*].id
}

output "seoul_private_beanstalk_subnet_ids" {
  description = "Seoul private Beanstalk subnet IDs"
  value       = aws_subnet.seoul_private_beanstalk[*].id
}

output "seoul_tgw_subnet_id" {
  description = "Seoul Transit Gateway subnet ID"
  value       = aws_subnet.seoul_tgw.id
}

output "seoul_public_route_table_id" {
  description = "Seoul public route table ID"
  value       = aws_route_table.seoul_public.id
}

output "seoul_private_route_table_id" {
  description = "Seoul private route table ID"
  value       = aws_route_table.seoul_private.id
}

output "seoul_tgw_route_table_id" {
  description = "Seoul TGW route table ID"
  value       = aws_route_table.seoul_tgw.id
}

output "seoul_beanstalk_security_group_id" {
  description = "Seoul Beanstalk security group ID"
  value       = aws_security_group.seoul_beanstalk.id
}

output "seoul_aurora_security_group_id" {
  description = "Seoul Aurora security group ID"
  value       = aws_security_group.aurora_seoul.id
}

output "seoul_nat_gateway_ids" {
  description = "Seoul NAT Gateway IDs"
  value       = aws_nat_gateway.seoul[*].id
}

output "seoul_internet_gateway_id" {
  description = "Seoul Internet Gateway ID"
  value       = aws_internet_gateway.seoul.id
}

# Seoul IDC VPC Outputs
output "seoul_idc_vpc_id" {
  description = "Seoul IDC VPC ID"
  value       = aws_vpc.seoul_idc.id
}

output "seoul_idc_vpc_cidr" {
  description = "Seoul IDC VPC CIDR block"
  value       = aws_vpc.seoul_idc.cidr_block
}

output "seoul_idc_subnet_id" {
  description = "Seoul IDC public subnet ID"
  value       = aws_subnet.seoul_idc_public.id
}

output "seoul_idc_route_table_id" {
  description = "Seoul IDC route table ID"
  value       = aws_route_table.seoul_idc.id
}

output "seoul_idc_cgw_security_group_id" {
  description = "Seoul IDC CGW security group ID"
  value       = aws_security_group.seoul_idc_cgw.id
}

output "seoul_idc_db_security_group_id" {
  description = "Seoul IDC DB security group ID"
  value       = aws_security_group.seoul_idc_db.id
}

output "seoul_idc_internet_gateway_id" {
  description = "Seoul IDC Internet Gateway ID"
  value       = aws_internet_gateway.seoul_idc.id
}

# Tokyo AWS VPC Outputs
output "tokyo_vpc_id" {
  description = "Tokyo VPC ID"
  value       = aws_vpc.tokyo.id
}

output "tokyo_vpc_cidr" {
  description = "Tokyo VPC CIDR block"
  value       = aws_vpc.tokyo.cidr_block
}

output "tokyo_public_nat_subnet_ids" {
  description = "Tokyo public NAT subnet IDs"
  value       = aws_subnet.tokyo_public_nat[*].id
}

output "tokyo_private_beanstalk_subnet_ids" {
  description = "Tokyo private Beanstalk subnet IDs"
  value       = aws_subnet.tokyo_private_beanstalk[*].id
}

output "tokyo_tgw_subnet_id" {
  description = "Tokyo Transit Gateway subnet ID"
  value       = aws_subnet.tokyo_tgw.id
}

output "tokyo_public_route_table_id" {
  description = "Tokyo public route table ID"
  value       = aws_route_table.tokyo_public.id
}

output "tokyo_private_route_table_id" {
  description = "Tokyo private route table ID"
  value       = aws_route_table.tokyo_private.id
}

output "tokyo_tgw_route_table_id" {
  description = "Tokyo TGW route table ID"
  value       = aws_route_table.tokyo_tgw.id
}

output "tokyo_beanstalk_security_group_id" {
  description = "Tokyo Beanstalk security group ID"
  value       = aws_security_group.tokyo_beanstalk.id
}

output "tokyo_aurora_security_group_id" {
  description = "Tokyo Aurora security group ID"
  value       = aws_security_group.aurora_tokyo.id
}

output "tokyo_nat_gateway_ids" {
  description = "Tokyo NAT Gateway IDs"
  value       = aws_nat_gateway.tokyo[*].id
}

output "tokyo_internet_gateway_id" {
  description = "Tokyo Internet Gateway ID"
  value       = aws_internet_gateway.tokyo.id
}

# Tokyo IDC VPC Outputs
output "tokyo_idc_vpc_id" {
  description = "Tokyo IDC VPC ID"
  value       = aws_vpc.tokyo_idc.id
}

output "tokyo_idc_vpc_cidr" {
  description = "Tokyo IDC VPC CIDR block"
  value       = aws_vpc.tokyo_idc.cidr_block
}

output "tokyo_idc_subnet_id" {
  description = "Tokyo IDC public subnet ID"
  value       = aws_subnet.tokyo_idc_public.id
}

output "tokyo_idc_route_table_id" {
  description = "Tokyo IDC route table ID"
  value       = aws_route_table.tokyo_idc.id
}

output "tokyo_idc_cgw_security_group_id" {
  description = "Tokyo IDC CGW security group ID"
  value       = aws_security_group.tokyo_idc_cgw.id
}

output "tokyo_idc_db_security_group_id" {
  description = "Tokyo IDC DB security group ID"
  value       = aws_security_group.tokyo_idc_db.id
}

output "tokyo_idc_internet_gateway_id" {
  description = "Tokyo IDC Internet Gateway ID"
  value       = aws_internet_gateway.tokyo_idc.id
}
