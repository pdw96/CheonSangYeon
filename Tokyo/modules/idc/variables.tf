variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "cgw_subnet_cidr" {
  description = "CIDR block for CGW subnet"
  type        = string
}

variable "db_subnet_cidr" {
  description = "CIDR block for DB subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
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

variable "db_instance_type" {
  description = "Instance type for DB EC2"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
}

variable "eip_id" {
  description = "Elastic IP allocation ID for CGW instance"
  type        = string
}

variable "vpn_config_script" {
  description = "User data script for VPN auto-configuration"
  type        = string
  default     = ""
}

variable "db_config_script" {
  description = "User data script for DB auto-configuration"
  type        = string
  default     = ""
}

variable "cgw_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the CGW instance"
  type        = list(string)
}

variable "cgw_icmp_cidrs" {
  description = "CIDR blocks allowed to send ICMP to the CGW instance"
  type        = list(string)
}

variable "vpn_peer_cidrs" {
  description = "CIDR blocks (typically /32 addresses) for VPN peer CGW endpoints"
  type        = list(string)
}

variable "db_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the DB instance"
  type        = list(string)
}

variable "db_mysql_cidrs" {
  description = "CIDR blocks allowed to access MySQL on the DB instance"
  type        = list(string)
}

variable "db_icmp_cidrs" {
  description = "CIDR blocks allowed to send ICMP to the DB instance"
  type        = list(string)
}

