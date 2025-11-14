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

