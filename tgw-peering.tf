terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Seoul Provider
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# Tokyo Provider
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# Seoul Transit Gateway 데이터 소스
data "aws_ec2_transit_gateway" "seoul" {
  provider = aws.seoul

  filter {
    name   = "tag:Name"
    values = ["seoul-main-tgw"]
  }
}

# Tokyo Transit Gateway 데이터 소스
data "aws_ec2_transit_gateway" "tokyo" {
  provider = aws.tokyo

  filter {
    name   = "tag:Name"
    values = ["tokyo-main-tgw"]
  }
}

# Transit Gateway Peering Attachment (Seoul에서 Tokyo로 요청)
resource "aws_ec2_transit_gateway_peering_attachment" "seoul_to_tokyo" {
  provider = aws.seoul

  peer_account_id         = data.aws_caller_identity.current.account_id
  peer_region             = "ap-northeast-1"
  peer_transit_gateway_id = data.aws_ec2_transit_gateway.tokyo.id
  transit_gateway_id      = data.aws_ec2_transit_gateway.seoul.id

  tags = {
    Name = "seoul-to-tokyo-peering"
    Side = "Creator"
  }
}

# Peering Attachment Accept (Tokyo에서 수락)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tokyo_accept" {
  provider = aws.tokyo

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id

  tags = {
    Name = "tokyo-accept-seoul-peering"
    Side = "Accepter"
  }
}

# 현재 계정 ID 가져오기
data "aws_caller_identity" "current" {
  provider = aws.seoul
}

# Seoul Transit Gateway Route Table - Tokyo CIDR
resource "aws_ec2_transit_gateway_route" "seoul_to_tokyo_cidr" {
  provider = aws.seoul

  destination_cidr_block         = "40.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.seoul.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

# Tokyo Transit Gateway Route Table - Seoul CIDR
resource "aws_ec2_transit_gateway_route" "tokyo_to_seoul_cidr" {
  provider = aws.tokyo

  destination_cidr_block         = "20.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.tokyo.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

# Seoul Transit Gateway Route Table - Tokyo IDC CIDR
resource "aws_ec2_transit_gateway_route" "seoul_to_tokyo_idc_cidr" {
  provider = aws.seoul

  destination_cidr_block         = "30.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.seoul.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

# Tokyo Transit Gateway Route Table - Seoul IDC CIDR
resource "aws_ec2_transit_gateway_route" "tokyo_to_seoul_idc_cidr" {
  provider = aws.tokyo

  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.tokyo.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}
