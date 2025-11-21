# Seoul AWS VPC Variables
variable "seoul_vpc_cidr" {
  description = "CIDR block for Seoul VPC"
  type        = string
  default     = "20.0.0.0/16"
}

variable "seoul_public_nat_subnet_cidrs" {
  description = "CIDR blocks for Seoul public NAT subnets"
  type        = list(string)
  default     = ["20.0.1.0/24", "20.0.2.0/24"]
}

variable "seoul_beanstalk_subnet_cidrs" {
  description = "CIDR blocks for Seoul private Beanstalk subnets"
  type        = list(string)
  default     = ["20.0.10.0/24", "20.0.11.0/24"]
}

variable "seoul_tgw_subnet_cidr" {
  description = "CIDR block for Seoul Transit Gateway subnet"
  type        = string
  default     = "20.0.20.0/24"
}

variable "seoul_availability_zones" {
  description = "Seoul availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# Seoul IDC VPC Variables
variable "seoul_idc_vpc_cidr" {
  description = "CIDR block for Seoul IDC VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "seoul_idc_subnet_cidr" {
  description = "CIDR block for Seoul IDC public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "seoul_idc_db_subnet_cidr" {
  description = "CIDR block for Seoul IDC private DB subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "seoul_idc_availability_zone" {
  description = "Availability zone for Seoul IDC"
  type        = string
  default     = "ap-northeast-2d"
}

# Tokyo AWS VPC Variables
variable "tokyo_vpc_cidr" {
  description = "CIDR block for Tokyo VPC"
  type        = string
  default     = "40.0.0.0/16"
}

variable "tokyo_public_nat_subnet_cidrs" {
  description = "CIDR blocks for Tokyo public NAT subnets"
  type        = list(string)
  default     = ["40.0.1.0/24", "40.0.2.0/24"]
}

variable "tokyo_beanstalk_subnet_cidrs" {
  description = "CIDR blocks for Tokyo private Beanstalk subnets"
  type        = list(string)
  default     = ["40.0.10.0/24", "40.0.11.0/24"]
}

variable "tokyo_tgw_subnet_cidr" {
  description = "CIDR block for Tokyo Transit Gateway subnet"
  type        = string
  default     = "40.0.20.0/24"
}

variable "tokyo_availability_zones" {
  description = "Tokyo availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

# Tokyo IDC VPC Variables
variable "tokyo_idc_vpc_cidr" {
  description = "CIDR block for Tokyo IDC VPC"
  type        = string
  default     = "30.0.0.0/16"
}

variable "tokyo_idc_subnet_cidr" {
  description = "CIDR block for Tokyo IDC public subnet"
  type        = string
  default     = "30.0.1.0/24"
}

variable "tokyo_idc_db_subnet_cidr" {
  description = "CIDR block for Tokyo IDC private DB subnet"
  type        = string
  default     = "30.0.2.0/24"
}

variable "tokyo_idc_availability_zone" {
  description = "Availability zone for Tokyo IDC"
  type        = string
  default     = "ap-northeast-1d"
}

# Transit Gateway Variables
variable "seoul_transit_gateway_id" {
  description = "Transit Gateway ID for Seoul region (optional)"
  type        = string
  default     = ""
}

variable "tokyo_transit_gateway_id" {
  description = "Transit Gateway ID for Tokyo region (optional)"
  type        = string
  default     = ""
}

# CGW Network Interface Variables
variable "seoul_cgw_network_interface_id" {
  description = "Network interface ID of Seoul IDC CGW instance"
  type        = string
  default     = ""
}

variable "tokyo_cgw_network_interface_id" {
  description = "Network interface ID of Tokyo IDC CGW instance"
  type        = string
  default     = ""
}
