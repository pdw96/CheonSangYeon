variable "tokyo_key_name" {
  description = "Key pair name for Tokyo region EC2 instances"
  type        = string
  default     = ""
}

variable "tokyo_ami_id" {
  description = "AMI ID for Tokyo region EC2 instances"
  type        = string
  default     = "ami-0e68e34976bb4db93" # Amazon Linux 2023 in Tokyo
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "idc_root_secret_arn" {
  description = "Secrets Manager ARN that stores the Tokyo IDC root password"
  type        = string
}

variable "idc_app_secret_arn" {
  description = "Secrets Manager ARN that stores the Tokyo IDC application password"
  type        = string
}

variable "idc_secret_region" {
  description = "AWS region where the Tokyo IDC secrets are stored"
  type        = string
  default     = "ap-northeast-1"
}

variable "idc_app_username" {
  description = "Application username for the IDC database"
  type        = string
  default     = "idcuser"
}

