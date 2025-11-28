terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/tokyo/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# Import VPC from global VPC module
data "terraform_remote_state" "global_vpc" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  tokyo_idc_cidr = "30.0.0.0/16"
  tokyo_vpc_cidr = data.terraform_remote_state.global_vpc.outputs.tokyo_vpc_cidr
  seoul_vpc_cidr = data.terraform_remote_state.global_vpc.outputs.seoul_vpc_cidr
  seoul_idc_cidr = data.terraform_remote_state.global_vpc.outputs.seoul_idc_vpc_cidr
}

# IDC Module (도쿄 리전에 배치, VPN으로만 연결)
module "idc" {
  source = "./modules/idc"

  providers = {
    aws = aws.tokyo
  }

  environment            = "idc"
  vpc_id                 = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_vpc_id
  cgw_subnet_id          = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_subnet_id
  db_subnet_id           = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_subnet_id  # CGW와 같은 서브넷에 배치
  cgw_security_group_id  = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_cgw_security_group_id
  db_security_group_id   = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_db_security_group_id
  ami_id                 = var.tokyo_ami_id
  instance_type          = "t3.micro"
  key_name               = var.tokyo_key_name
  eip_id                 = aws_eip.idc_cgw.id
  vpn_config_script      = templatefile("${path.module}/scripts/vpn-setup.sh", {
    tunnel1_address = aws_vpn_connection.tokyo_to_idc.tunnel1_address
    tunnel2_address = aws_vpn_connection.tokyo_to_idc.tunnel2_address
    tunnel1_psk     = aws_vpn_connection.tokyo_to_idc.tunnel1_preshared_key
    tunnel2_psk     = aws_vpn_connection.tokyo_to_idc.tunnel2_preshared_key
    local_cidr      = local.tokyo_idc_cidr      # Tokyo IDC CIDR: 30.0.0.0/16
    remote_cidr     = local.tokyo_vpc_cidr      # Tokyo AWS CIDR: 40.0.0.0/16
    seoul_aws_cidr  = local.seoul_vpc_cidr      # Seoul AWS CIDR: 20.0.0.0/16
    seoul_idc_cidr  = local.seoul_idc_cidr      # Seoul IDC CIDR: 10.0.0.0/16
  })
  db_config_script = file("${path.module}/scripts/db-setup.sh")

  depends_on = [aws_vpn_connection.tokyo_to_idc]
}

# IDC Public 서브넷 라우팅 테이블에 AWS VPC CIDR를 CGW ENI로 향하도록 설정
resource "aws_route" "idc_to_tokyo_vpc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_route_table_id
  destination_cidr_block = "40.0.0.0/16"
  network_interface_id   = module.idc.cgw_network_interface_id

  depends_on = [module.idc]
}

resource "aws_route" "idc_to_seoul_vpc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_route_table_id
  destination_cidr_block = "20.0.0.0/16"
  network_interface_id   = module.idc.cgw_network_interface_id

  depends_on = [module.idc]
}

resource "aws_route" "idc_to_seoul_idc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_idc_route_table_id
  destination_cidr_block = "10.0.0.0/16"
  network_interface_id   = module.idc.cgw_network_interface_id

  depends_on = [module.idc]
}

# AWS Private 서브넷 라우팅 테이블에 TGW 경로 추가
resource "aws_route" "tokyo_private_to_idc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_private_route_table_id
  destination_cidr_block = "30.0.0.0/16"  # Tokyo IDC VPC
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tokyo]
}

resource "aws_route" "tokyo_private_to_seoul_vpc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_private_route_table_id
  destination_cidr_block = "20.0.0.0/16"  # Seoul VPC
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tokyo]
}

resource "aws_route" "tokyo_private_to_seoul_idc" {
  provider               = aws.tokyo
  route_table_id         = data.terraform_remote_state.global_vpc.outputs.tokyo_private_route_table_id
  destination_cidr_block = "10.0.0.0/16"  # Seoul IDC VPC
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tokyo]
}

# Transit Gateway (도쿄 리전)
resource "aws_ec2_transit_gateway" "main" {
  provider                        = aws.tokyo
  description                     = "Tokyo Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "tokyo-tgw"
  }
}

# Transit Gateway Attachment - Tokyo VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "tokyo" {
  provider           = aws.tokyo
  subnet_ids         = [data.terraform_remote_state.global_vpc.outputs.tokyo_tgw_subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = data.terraform_remote_state.global_vpc.outputs.tokyo_vpc_id

  tags = {
    Name = "tokyo-vpc-tgw-attachment"
  }
}

# ===== AWS Managed VPN 설정 =====

# Elastic IP for IDC Customer Gateway
resource "aws_eip" "idc_cgw" {
  provider = aws.tokyo
  domain   = "vpc"

  tags = {
    Name = "tokyo-idc-cgw-eip"
  }
}

# Customer Gateway (Elastic IP 사용)
resource "aws_customer_gateway" "idc" {
  provider   = aws.tokyo
  bgp_asn    = 65000
  ip_address = aws_eip.idc_cgw.public_ip
  type       = "ipsec.1"

  tags = {
    Name = "idc-customer-gateway"
  }
}

# VPN Connection (Tokyo Transit Gateway ↔ IDC Customer Gateway)
resource "aws_vpn_connection" "tokyo_to_idc" {
  provider            = aws.tokyo
  transit_gateway_id  = aws_ec2_transit_gateway.main.id
  customer_gateway_id = aws_customer_gateway.idc.id
  type                = "ipsec.1"
  static_routes_only  = true

  # Tunnel 1 옵션 - Libreswan 호환 (DH Group 14)
  tunnel1_ike_versions                  = ["ikev2"]
  tunnel1_phase1_dh_group_numbers       = [14]
  tunnel1_phase1_encryption_algorithms  = ["AES128"]
  tunnel1_phase1_integrity_algorithms   = ["SHA1"]
  tunnel1_phase2_dh_group_numbers       = [14]
  tunnel1_phase2_encryption_algorithms  = ["AES128"]
  tunnel1_phase2_integrity_algorithms   = ["SHA1"]
  tunnel1_dpd_timeout_seconds           = 30

  # Tunnel 2 옵션 - Libreswan 호환 (DH Group 14)
  tunnel2_ike_versions                  = ["ikev2"]
  tunnel2_phase1_dh_group_numbers       = [14]
  tunnel2_phase1_encryption_algorithms  = ["AES128"]
  tunnel2_phase1_integrity_algorithms   = ["SHA1"]
  tunnel2_phase2_dh_group_numbers       = [14]
  tunnel2_phase2_encryption_algorithms  = ["AES128"]
  tunnel2_phase2_integrity_algorithms   = ["SHA1"]
  tunnel2_dpd_timeout_seconds           = 30

  tags = {
    Name = "tokyo-to-idc-vpn"
  }
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route" "idc_cidr" {
  provider                       = aws.tokyo
  destination_cidr_block         = "30.0.0.0/16"
  transit_gateway_attachment_id  = aws_vpn_connection.tokyo_to_idc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
}

# ===== Elastic Beanstalk 설정 =====

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "tokyo_app" {
  provider    = aws.tokyo
  name        = "tokyo-webapp"
  description = "Tokyo Web Application"
}

# IAM Role for Elastic Beanstalk Service
resource "aws_iam_role" "beanstalk_service" {
  provider = aws.tokyo
  name     = "tokyo-beanstalk-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_service_health" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "beanstalk_service_managed" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "beanstalk_ec2" {
  provider = aws.tokyo
  name     = "tokyo-beanstalk-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_web" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_worker" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_multicontainer" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_ecr_readonly" {
  provider   = aws.tokyo
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "beanstalk_ec2" {
  provider = aws.tokyo
  name     = "tokyo-beanstalk-ec2-profile"
  role     = aws_iam_role.beanstalk_ec2.name
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "tokyo_env" {
  provider            = aws.tokyo
  name                = "tokyo-webapp-env"
  application         = aws_elastic_beanstalk_application.tokyo_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.8.0 running Docker"
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = data.terraform_remote_state.global_vpc.outputs.tokyo_vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", data.terraform_remote_state.global_vpc.outputs.tokyo_private_beanstalk_subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", data.terraform_remote_state.global_vpc.outputs.tokyo_public_nat_subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.beanstalk_ec2.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = var.tokyo_key_name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = data.terraform_remote_state.global_vpc.outputs.tokyo_beanstalk_security_group_id
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.beanstalk_service.arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = data.terraform_remote_state.global_vpc.outputs.tokyo_beanstalk_security_group_id
  }

  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "ManagedSecurityGroup"
    value     = data.terraform_remote_state.global_vpc.outputs.tokyo_beanstalk_security_group_id
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  tags = {
    Name = "tokyo-webapp-environment"
  }
}
