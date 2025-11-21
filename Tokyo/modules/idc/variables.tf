variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from global/vpc)"
  type        = string
}

variable "cgw_subnet_id" {
  description = "CGW subnet ID (from global/vpc)"
  type        = string
}

variable "db_subnet_id" {
  description = "DB subnet ID (from global/vpc)"
  type        = string
}

variable "cgw_security_group_id" {
  description = "CGW security group ID (from global/vpc)"
  type        = string
}

variable "db_security_group_id" {
  description = "DB security group ID (from global/vpc)"
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



