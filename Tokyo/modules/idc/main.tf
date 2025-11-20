# IDC Module - VPC and Network Resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Public Subnet for CGW
resource "aws_subnet" "public_cgw" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.cgw_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-cgw"
  }
}

# Private Subnet for DB
resource "aws_subnet" "private_db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-private-db"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public_cgw" {
  subnet_id      = aws_subnet.public_cgw.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table for DB
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.cgw.primary_network_interface_id
  }

  tags = {
    Name = "${var.environment}-private-rt"
  }

  depends_on = [aws_instance.cgw]
}

resource "aws_route_table_association" "private_db" {
  subnet_id      = aws_subnet.private_db.id
  route_table_id = aws_route_table.private.id
}

# Security Group for CGW Instance
resource "aws_security_group" "cgw" {
  name        = "${var.environment}-cgw-sg"
  description = "Security group for CGW instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.cgw_ssh_cidrs
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.cgw_icmp_cidrs
  }

  # IPsec VPN - IKE
  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = var.vpn_peer_cidrs
  }

  # IPsec VPN - NAT-T
  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = var.vpn_peer_cidrs
  }

  # ESP Protocol
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = var.vpn_peer_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-cgw-sg"
  }
}

# Security Group for DB Instance
resource "aws_security_group" "db" {
  name        = "${var.environment}-db-sg"
  description = "Security group for DB instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.db_ssh_cidrs
    description = "SSH from VPC"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.db_mysql_cidrs
    description = "MySQL from VPC and AWS VPC"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.db_icmp_cidrs
    description = "ICMP from VPC and AWS VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-db-sg"
  }
}

# CGW Instance with VPN auto-configuration
resource "aws_instance" "cgw" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_cgw.id
  vpc_security_group_ids = [aws_security_group.cgw.id]
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

# DB Instance with MySQL 8.0
resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name
  user_data              = var.db_config_script != "" ? var.db_config_script : null

  tags = {
    Name = "${var.environment}-db-instance"
  }
}

