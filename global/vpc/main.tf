terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for Terraform State
  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-vpc/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# ===== Seoul AWS VPC =====

resource "aws_vpc" "seoul" {
  provider             = aws.seoul
  cidr_block           = var.seoul_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "seoul-vpc"
  }
}

resource "aws_internet_gateway" "seoul" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul.id

  tags = {
    Name = "seoul-igw"
  }
}

resource "aws_subnet" "seoul_public_nat" {
  provider                = aws.seoul
  count                   = length(var.seoul_public_nat_subnet_cidrs)
  vpc_id                  = aws_vpc.seoul.id
  cidr_block              = var.seoul_public_nat_subnet_cidrs[count.index]
  availability_zone       = var.seoul_availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "seoul-public-nat-${count.index + 1}"
  }
}

resource "aws_subnet" "seoul_private_beanstalk" {
  provider          = aws.seoul
  count             = length(var.seoul_beanstalk_subnet_cidrs)
  vpc_id            = aws_vpc.seoul.id
  cidr_block        = var.seoul_beanstalk_subnet_cidrs[count.index]
  availability_zone = var.seoul_availability_zones[count.index]

  tags = {
    Name = "seoul-private-beanstalk-${count.index + 1}"
  }
}

resource "aws_subnet" "seoul_tgw" {
  provider          = aws.seoul
  vpc_id            = aws_vpc.seoul.id
  cidr_block        = var.seoul_tgw_subnet_cidr
  availability_zone = var.seoul_availability_zones[0]

  tags = {
    Name = "seoul-tgw-subnet"
  }
}

resource "aws_eip" "seoul" {
  provider = aws.seoul
  count    = length(var.seoul_public_nat_subnet_cidrs)
  domain   = "vpc"

  tags = {
    Name = "seoul-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.seoul]
}

resource "aws_nat_gateway" "seoul" {
  provider      = aws.seoul
  count         = length(var.seoul_public_nat_subnet_cidrs)
  allocation_id = aws_eip.seoul[count.index].id
  subnet_id     = aws_subnet.seoul_public_nat[count.index].id

  tags = {
    Name = "seoul-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.seoul]
}

resource "aws_route_table" "seoul_public" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.seoul.id
  }

  tags = {
    Name = "seoul-public-rt"
  }
}

resource "aws_route_table_association" "seoul_public_nat" {
  provider       = aws.seoul
  count          = length(var.seoul_public_nat_subnet_cidrs)
  subnet_id      = aws_subnet.seoul_public_nat[count.index].id
  route_table_id = aws_route_table.seoul_public.id
}

resource "aws_route_table" "seoul_private" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.seoul[0].id
  }

  tags = {
    Name = "seoul-private-rt"
  }
}

resource "aws_route" "seoul_private_to_idc" {
  count                  = var.seoul_transit_gateway_id != "" ? 1 : 0
  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_private.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = var.seoul_transit_gateway_id
}

resource "aws_route_table_association" "seoul_private_beanstalk" {
  provider       = aws.seoul
  count          = length(var.seoul_beanstalk_subnet_cidrs)
  subnet_id      = aws_subnet.seoul_private_beanstalk[count.index].id
  route_table_id = aws_route_table.seoul_private.id
}

resource "aws_route_table" "seoul_tgw" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul.id

  tags = {
    Name = "seoul-tgw-rt"
  }
}

resource "aws_route_table_association" "seoul_tgw" {
  provider       = aws.seoul
  subnet_id      = aws_subnet.seoul_tgw.id
  route_table_id = aws_route_table.seoul_tgw.id
}

resource "aws_security_group" "seoul_beanstalk" {
  provider    = aws.seoul
  name        = "seoul-beanstalk-sg"
  description = "Security group for Seoul Elastic Beanstalk instances"
  vpc_id      = aws_vpc.seoul.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "seoul-beanstalk-sg"
  }
}

# Security Group for Aurora (Seoul)
resource "aws_security_group" "aurora_seoul" {
  provider    = aws.seoul
  name        = "aurora-global-seoul-sg"
  description = "Security group for Aurora Global Database"
  vpc_id      = aws_vpc.seoul.id

  # MySQL/Aurora 포트 - Beanstalk에서 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["20.0.0.0/16"]
    description = "MySQL from Seoul VPC"
  }

  # IDC에서 마이그레이션을 위한 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MySQL from IDC for migration"
  }

  # Tokyo 리전에서 접근 (향후 글로벌 클러스터 확장용)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["40.0.0.0/16", "30.0.0.0/16"]
    description = "MySQL from Tokyo regions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-global-seoul-sg"
  }
}

# ===== Tokyo AWS VPC =====

resource "aws_vpc" "tokyo" {
  provider             = aws.tokyo
  cidr_block           = var.tokyo_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tokyo-vpc"
  }
}

resource "aws_internet_gateway" "tokyo" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo.id

  tags = {
    Name = "tokyo-igw"
  }
}

resource "aws_subnet" "tokyo_public_nat" {
  provider                = aws.tokyo
  count                   = length(var.tokyo_public_nat_subnet_cidrs)
  vpc_id                  = aws_vpc.tokyo.id
  cidr_block              = var.tokyo_public_nat_subnet_cidrs[count.index]
  availability_zone       = var.tokyo_availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "tokyo-public-nat-${count.index + 1}"
  }
}

resource "aws_subnet" "tokyo_private_beanstalk" {
  provider          = aws.tokyo
  count             = length(var.tokyo_beanstalk_subnet_cidrs)
  vpc_id            = aws_vpc.tokyo.id
  cidr_block        = var.tokyo_beanstalk_subnet_cidrs[count.index]
  availability_zone = var.tokyo_availability_zones[count.index]

  tags = {
    Name = "tokyo-private-beanstalk-${count.index + 1}"
  }
}

resource "aws_subnet" "tokyo_tgw" {
  provider          = aws.tokyo
  vpc_id            = aws_vpc.tokyo.id
  cidr_block        = var.tokyo_tgw_subnet_cidr
  availability_zone = var.tokyo_availability_zones[0]

  tags = {
    Name = "tokyo-tgw-subnet"
  }
}

resource "aws_eip" "tokyo" {
  provider = aws.tokyo
  count    = length(var.tokyo_public_nat_subnet_cidrs)
  domain   = "vpc"

  tags = {
    Name = "tokyo-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.tokyo]
}

resource "aws_nat_gateway" "tokyo" {
  provider      = aws.tokyo
  count         = length(var.tokyo_public_nat_subnet_cidrs)
  allocation_id = aws_eip.tokyo[count.index].id
  subnet_id     = aws_subnet.tokyo_public_nat[count.index].id

  tags = {
    Name = "tokyo-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.tokyo]
}

resource "aws_route_table" "tokyo_public" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tokyo.id
  }

  tags = {
    Name = "tokyo-public-rt"
  }
}

resource "aws_route_table_association" "tokyo_public_nat" {
  provider       = aws.tokyo
  count          = length(var.tokyo_public_nat_subnet_cidrs)
  subnet_id      = aws_subnet.tokyo_public_nat[count.index].id
  route_table_id = aws_route_table.tokyo_public.id
}

resource "aws_route_table" "tokyo_private" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tokyo[0].id
  }

  tags = {
    Name = "tokyo-private-rt"
  }
}

resource "aws_route_table_association" "tokyo_private_beanstalk" {
  provider       = aws.tokyo
  count          = length(var.tokyo_beanstalk_subnet_cidrs)
  subnet_id      = aws_subnet.tokyo_private_beanstalk[count.index].id
  route_table_id = aws_route_table.tokyo_private.id
}

resource "aws_route_table" "tokyo_tgw" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo.id

  tags = {
    Name = "tokyo-tgw-rt"
  }
}

resource "aws_route_table_association" "tokyo_tgw" {
  provider       = aws.tokyo
  subnet_id      = aws_subnet.tokyo_tgw.id
  route_table_id = aws_route_table.tokyo_tgw.id
}

resource "aws_security_group" "tokyo_beanstalk" {
  provider    = aws.tokyo
  name        = "tokyo-beanstalk-sg"
  description = "Security group for Tokyo Elastic Beanstalk instances"
  vpc_id      = aws_vpc.tokyo.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tokyo-beanstalk-sg"
  }
}

# Security Group for Aurora (Tokyo)
resource "aws_security_group" "aurora_tokyo" {
  provider    = aws.tokyo
  name        = "aurora-global-tokyo-sg"
  description = "Security group for Aurora Global Database Tokyo"
  vpc_id      = aws_vpc.tokyo.id

  # MySQL/Aurora 포트 - Beanstalk에서 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["40.0.0.0/16"]
    description = "MySQL from Tokyo VPC"
  }

  # Tokyo IDC에서 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["30.0.0.0/16"]
    description = "MySQL from Tokyo IDC"
  }

  # Seoul 리전에서 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["20.0.0.0/16", "10.0.0.0/16"]
    description = "MySQL from Seoul regions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-global-tokyo-sg"
  }
}

# ===== Seoul IDC VPC =====

resource "aws_vpc" "seoul_idc" {
  provider             = aws.seoul
  cidr_block           = var.seoul_idc_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "seoul-idc-vpc"
  }
}

resource "aws_internet_gateway" "seoul_idc" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul_idc.id

  tags = {
    Name = "seoul-idc-igw"
  }
}

resource "aws_subnet" "seoul_idc_public" {
  provider                = aws.seoul
  vpc_id                  = aws_vpc.seoul_idc.id
  cidr_block              = var.seoul_idc_subnet_cidr
  availability_zone       = var.seoul_idc_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "seoul-idc-public-subnet"
  }
}

resource "aws_route_table" "seoul_idc" {
  provider = aws.seoul
  vpc_id   = aws_vpc.seoul_idc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.seoul_idc.id
  }

  tags = {
    Name = "seoul-idc-route-table"
  }
}

resource "aws_route_table_association" "seoul_idc" {
  provider       = aws.seoul
  subnet_id      = aws_subnet.seoul_idc_public.id
  route_table_id = aws_route_table.seoul_idc.id
}

resource "aws_security_group" "seoul_idc_cgw" {
  provider    = aws.seoul
  name        = "seoul-idc-cgw-sg"
  description = "Security group for Seoul IDC Customer Gateway"
  vpc_id      = aws_vpc.seoul_idc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "IKE"
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "IPsec NAT-T"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ESP Protocol"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "seoul-idc-cgw-sg"
  }
}

resource "aws_security_group" "seoul_idc_db" {
  provider    = aws.seoul
  name        = "seoul-idc-db-sg"
  description = "Security group for Seoul IDC Database instance"
  vpc_id      = aws_vpc.seoul_idc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "MySQL from all VPCs"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "seoul-idc-db-sg"
  }
}

# ===== Tokyo IDC VPC =====

resource "aws_vpc" "tokyo_idc" {
  provider             = aws.tokyo
  cidr_block           = var.tokyo_idc_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tokyo-idc-vpc"
  }
}

resource "aws_internet_gateway" "tokyo_idc" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo_idc.id

  tags = {
    Name = "tokyo-idc-igw"
  }
}

resource "aws_subnet" "tokyo_idc_public" {
  provider                = aws.tokyo
  vpc_id                  = aws_vpc.tokyo_idc.id
  cidr_block              = var.tokyo_idc_subnet_cidr
  availability_zone       = var.tokyo_idc_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "tokyo-idc-public-subnet"
  }
}

resource "aws_route_table" "tokyo_idc" {
  provider = aws.tokyo
  vpc_id   = aws_vpc.tokyo_idc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tokyo_idc.id
  }

  tags = {
    Name = "tokyo-idc-route-table"
  }
}

resource "aws_route_table_association" "tokyo_idc" {
  provider       = aws.tokyo
  subnet_id      = aws_subnet.tokyo_idc_public.id
  route_table_id = aws_route_table.tokyo_idc.id
}

resource "aws_security_group" "tokyo_idc_cgw" {
  provider    = aws.tokyo
  name        = "tokyo-idc-cgw-sg"
  description = "Security group for Tokyo IDC Customer Gateway"
  vpc_id      = aws_vpc.tokyo_idc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "IKE"
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "IPsec NAT-T"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tokyo-idc-cgw-sg"
  }
}

resource "aws_security_group" "tokyo_idc_db" {
  provider    = aws.tokyo
  name        = "tokyo-idc-db-sg"
  description = "Security group for Tokyo IDC Database instance"
  vpc_id      = aws_vpc.tokyo_idc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "MySQL from all VPCs"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "20.0.0.0/16", "30.0.0.0/16", "40.0.0.0/16"]
    description = "ICMP from all VPCs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tokyo-idc-db-sg"
  }
}

# ===== Cross-Region Routing =====

# Seoul AWS Private RT에 Tokyo CIDR 추가 (Transit Gateway 사용 시)
resource "aws_route" "seoul_private_to_tokyo_aws" {
  count = var.seoul_transit_gateway_id != "" ? 1 : 0

  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_private.id
  destination_cidr_block = "40.0.0.0/16"
  transit_gateway_id     = var.seoul_transit_gateway_id
}

resource "aws_route" "seoul_private_to_tokyo_idc" {
  count = var.seoul_transit_gateway_id != "" ? 1 : 0

  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_private.id
  destination_cidr_block = "30.0.0.0/16"
  transit_gateway_id     = var.seoul_transit_gateway_id
}

# Tokyo AWS Private RT에 Seoul CIDR 추가 (Transit Gateway 사용 시)
resource "aws_route" "tokyo_private_to_seoul_aws" {
  count = var.tokyo_transit_gateway_id != "" ? 1 : 0

  provider               = aws.tokyo
  route_table_id         = aws_route_table.tokyo_private.id
  destination_cidr_block = "20.0.0.0/16"
  transit_gateway_id     = var.tokyo_transit_gateway_id
}

resource "aws_route" "tokyo_private_to_seoul_idc" {
  count = var.tokyo_transit_gateway_id != "" ? 1 : 0

  provider               = aws.tokyo
  route_table_id         = aws_route_table.tokyo_private.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = var.tokyo_transit_gateway_id
}
