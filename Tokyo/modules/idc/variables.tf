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

variable "db_root_secret_arn" {
  description = "Secrets Manager ARN for the IDC root password"
  type        = string
}

variable "db_app_secret_arn" {
  description = "Secrets Manager ARN for the IDC application password"
  type        = string
}

