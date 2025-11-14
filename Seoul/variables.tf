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

