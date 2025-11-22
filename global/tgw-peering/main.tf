terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-tgw-peering/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
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

# 현재 계정 ID
data "aws_caller_identity" "current" {
  provider = aws.seoul
}

# Seoul Transit Gateway 데이터 소스
data "aws_ec2_transit_gateway" "seoul" {
  provider = aws.seoul

  filter {
    name   = "tag:Name"
    values = ["seoul-main-tgw"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Tokyo Transit Gateway 데이터 소스
data "aws_ec2_transit_gateway" "tokyo" {
  provider = aws.tokyo
  filter {
    name   = "tag:Name"
    values = ["tokyo-tgw"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Transit Gateway Peering Attachment (Seoul → Tokyo)
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

# Peering Attachment Accept (Tokyo)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tokyo_accept" {
  provider = aws.tokyo

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id

  tags = {
    Name = "tokyo-accept-seoul-peering"
    Side = "Accepter"
  }
}

# Seoul TGW Routes
resource "aws_ec2_transit_gateway_route" "seoul_to_tokyo_aws" {
  provider = aws.seoul

  destination_cidr_block         = "40.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.seoul.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

resource "aws_ec2_transit_gateway_route" "seoul_to_tokyo_idc" {
  provider = aws.seoul

  destination_cidr_block         = "30.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.seoul.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

# Tokyo TGW Routes
resource "aws_ec2_transit_gateway_route" "tokyo_to_seoul_aws" {
  provider = aws.tokyo

  destination_cidr_block         = "20.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.tokyo.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}

resource "aws_ec2_transit_gateway_route" "tokyo_to_seoul_idc" {
  provider = aws.tokyo

  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.tokyo.association_default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept]
}
