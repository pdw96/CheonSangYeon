# IDC Module - VPC and Network Resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for EC2 instances to access AWS services
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"

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

  tags = {
    Name = "${var.environment}-ec2-role"
  }
}

# Attach EC2 describe policy
resource "aws_iam_role_policy" "ec2_describe" {
  name = "${var.environment}-ec2-describe-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${var.environment}-ec2-profile"
  }
}

# CGW Instance with VPN auto-configuration
resource "aws_instance" "cgw" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.cgw_subnet_id
  vpc_security_group_ids = [var.cgw_security_group_id]
  key_name               = var.key_name
  source_dest_check      = false  # VPN을 위해 비활성화
  user_data              = var.vpn_config_script != "" ? var.vpn_config_script : null

  tags = {
    Name = "${var.environment}-cgw-instance"
  }
}

# EIP Association
resource "aws_eip_association" "cgw" {
  instance_id   = aws_instance.cgw.id
  allocation_id = var.eip_id
}

# DB Instance
resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.db_instance_type
  subnet_id              = var.db_subnet_id
  vpc_security_group_ids = [var.db_security_group_id]
  key_name               = var.key_name
  user_data              = var.db_config_script != "" ? var.db_config_script : null

  tags = {
    Name = "${var.environment}-db-instance"
  }
}

