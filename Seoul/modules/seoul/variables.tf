variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_nat_subnet_cidrs" {
  description = "CIDR blocks for public NAT subnets"
  type        = list(string)
}

variable "cgw_subnet_cidr" {
  description = "CIDR block for CGW subnet"
  type        = string
}

variable "beanstalk_subnet_cidrs" {
  description = "CIDR blocks for Beanstalk private subnets"
  type        = list(string)
}

variable "tgw_subnet_cidr" {
  description = "CIDR block for Transit Gateway subnet"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID for routing"
  type        = string
}
