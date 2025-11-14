# Tokyo Module - VPC and Network Resources

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Public Subnets for NAT Gateway
resource "aws_subnet" "public_nat" {
  count                   = length(var.public_nat_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_nat_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-nat-${count.index + 1}"
  }
}

# Subnet for VPN Gateway (변경: CGW → VPN Gateway용)
resource "aws_subnet" "vpn_gateway" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.cgw_subnet_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-vpn-gateway-subnet"
  }
}

# Private Subnets for Elastic Beanstalk
resource "aws_subnet" "private_beanstalk" {
  count             = length(var.beanstalk_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.beanstalk_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-private-beanstalk-${count.index + 1}"
  }
}

# Subnet for Transit Gateway
resource "aws_subnet" "tgw" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.tgw_subnet_cidr
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.environment}-tgw"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.public_nat_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_nat_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_nat[count.index].id

  tags = {
    Name = "${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
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

resource "aws_route_table_association" "public_nat" {
  count          = length(aws_subnet.public_nat)
  subnet_id      = aws_subnet.public_nat[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "vpn_gateway" {
  subnet_id      = aws_subnet.vpn_gateway.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table for Beanstalk
resource "aws_route_table" "private_beanstalk" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.environment}-private-beanstalk-rt"
  }
}

# Route to IDC via TGW
resource "aws_route" "private_to_idc" {
  route_table_id         = aws_route_table.private_beanstalk.id
  destination_cidr_block = "30.0.0.0/16"
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "private_beanstalk" {
  count          = length(aws_subnet.private_beanstalk)
  subnet_id      = aws_subnet.private_beanstalk[count.index].id
  route_table_id = aws_route_table.private_beanstalk.id
}

# TGW Route Table
resource "aws_route_table" "tgw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-tgw-rt"
  }
}

resource "aws_route_table_association" "tgw" {
  subnet_id      = aws_subnet.tgw.id
  route_table_id = aws_route_table.tgw.id
}


