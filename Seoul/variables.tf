variable "seoul_key_name" {
  description = "Key pair name for Seoul region EC2 instances"
  type        = string
  default     = ""
}

variable "seoul_ami_id" {
  description = "AMI ID for Seoul region EC2 instances"
  type        = string
  default     = "ami-0c1508b5372d244d7" # Amazon Linux 2023 in Seoul
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "idc_root_secret_arn" {
  description = "Secrets Manager ARN that stores the IDC root password"
  type        = string
}

variable "idc_app_secret_arn" {
  description = "Secrets Manager ARN that stores the IDC application user password"
  type        = string
}

variable "idc_secret_region" {
  description = "AWS region where the IDC database secrets are stored"
  type        = string
  default     = "ap-northeast-2"
}

variable "idc_app_username" {
  description = "Application username for the IDC database"
  type        = string
  default     = "idcuser"
}

