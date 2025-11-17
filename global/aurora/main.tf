terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for Terraform State
  backend "s3" {
    bucket  = ""  # terraform init 시 -backend-config로 지정
    key     = "terraform/aurora-global/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

# Seoul Provider (Primary Region)
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# Tokyo Provider (Secondary Region for future expansion)
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# Import S3 bucket from global/s3 module
data "terraform_remote_state" "s3" {
  backend = "local"
  config = {
    path = "../s3/terraform.tfstate"
  }
}

# Data source: Get Seoul VPC
data "aws_vpc" "seoul" {
  provider = aws.seoul
  filter {
    name   = "tag:Name"
    values = ["seoul-vpc"]
  }
}

# Data source: Get all private subnets in Seoul VPC for Aurora
data "aws_subnets" "seoul_private" {
  provider = aws.seoul
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.seoul.id]
  }
  filter {
    name   = "tag:Name"
    values = ["seoul-beanstalk-subnet-*", "seoul-private-subnet*"]
  }
}

# Fallback: Use specific subnet IDs if data source returns empty
locals {
  seoul_subnet_ids = length(data.aws_subnets.seoul_private.ids) > 0 ? data.aws_subnets.seoul_private.ids : [
    "subnet-09ca5bf59eab4a46d",
    "subnet-0f79754b4cc788b26"
  ]
}

# Data source: Get IDC VPC
data "aws_vpc" "idc" {
  provider = aws.seoul
  filter {
    name   = "tag:Name"
    values = ["idc-vpc"]
  }
}

# Data source: Get IDC DB instance for migration
data "aws_instance" "idc_db" {
  provider = aws.seoul
  filter {
    name   = "tag:Name"
    values = ["idc-db-instance"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# DB Subnet Group for Aurora (Seoul Private Subnets)
resource "aws_db_subnet_group" "aurora_seoul" {
  provider   = aws.seoul
  name       = "aurora-global-seoul-subnet-group"
  subnet_ids = local.seoul_subnet_ids

  tags = {
    Name = "aurora-global-seoul-subnet-group"
  }
}

# Security Group for Aurora
resource "aws_security_group" "aurora_seoul" {
  provider    = aws.seoul
  name        = "aurora-global-seoul-sg"
  description = "Security group for Aurora Global Database"
  vpc_id      = data.aws_vpc.seoul.id

  # MySQL/Aurora 포트 - Beanstalk에서 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["20.0.0.0/16"]
    description = "MySQL from Seoul VPC"
  }

  # IDC에서 마이그레이션을 위한 접근
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MySQL from IDC for migration"
  }

  # Tokyo 리전에서 접근 (향후 글로벌 클러스터 확장용)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["40.0.0.0/16", "30.0.0.0/16"]
    description = "MySQL from Tokyo regions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-global-seoul-sg"
  }
}

# IAM Role for Aurora to access S3
resource "aws_iam_role" "aurora_s3_access" {
  provider = aws.seoul
  name     = "aurora-global-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "aurora-global-s3-access-role"
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "aurora_s3_policy" {
  provider = aws.seoul
  name     = "aurora-global-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.terraform_remote_state.s3.outputs.s3_bucket_arn,
          "${data.terraform_remote_state.s3.outputs.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.terraform_remote_state.s3.outputs.s3_bucket_replica_arn,
          "${data.terraform_remote_state.s3.outputs.s3_bucket_replica_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aurora_s3_attach" {
  provider   = aws.seoul
  role       = aws_iam_role.aurora_s3_access.name
  policy_arn = aws_iam_policy.aurora_s3_policy.arn
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora_global" {
  provider    = aws.seoul
  name        = "aurora-global-mysql80-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL 8.0 cluster parameter group for global database"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }

  tags = {
    Name = "aurora-global-mysql80-params"
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "aurora_global" {
  provider    = aws.seoul
  name        = "aurora-global-mysql80-db-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL 8.0 DB parameter group"

  parameter {
    name  = "max_connections"
    value = "1000"
  }

  tags = {
    Name = "aurora-global-mysql80-db-params"
  }
}

# Aurora Global Database Cluster
resource "aws_rds_global_cluster" "aurora_global" {
  provider                  = aws.seoul
  global_cluster_identifier = "aurora-global-mysql-cluster"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.0"
  database_name             = "globaldb"
  storage_encrypted         = true

  # 글로벌 클러스터는 자동 백업이 비활성화되어야 함 (리전 클러스터에서 관리)
}

# Primary Cluster (Seoul)
resource "aws_rds_cluster" "aurora_seoul" {
  provider                        = aws.seoul
  cluster_identifier              = "aurora-global-seoul-cluster"
  engine                          = aws_rds_global_cluster.aurora_global.engine
  engine_version                  = aws_rds_global_cluster.aurora_global.engine_version
  global_cluster_identifier       = aws_rds_global_cluster.aurora_global.id
  database_name                   = "globaldb"
  master_username                 = "admin"
  master_password                 = "AdminPassword123!"
  db_subnet_group_name            = aws_db_subnet_group.aurora_seoul.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_global.name
  vpc_security_group_ids          = [aws_security_group.aurora_seoul.id]
  
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  
  skip_final_snapshot       = false
  final_snapshot_identifier = "aurora-global-seoul-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # S3 Import/Export 활성화
  iam_roles = [aws_iam_role.aurora_s3_access.arn]

  tags = {
    Name        = "aurora-global-seoul-cluster"
    Environment = "production"
    Region      = "primary"
  }

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      master_password
    ]
  }
}

# Primary Instance (Writer)
resource "aws_rds_cluster_instance" "aurora_seoul_writer" {
  provider                     = aws.seoul
  identifier                   = "aurora-global-seoul-writer"
  cluster_identifier           = aws_rds_cluster.aurora_seoul.id
  instance_class               = "db.r6g.large"  # 글로벌 DB 지원 인스턴스 유형
  engine                       = aws_rds_cluster.aurora_seoul.engine
  engine_version               = aws_rds_cluster.aurora_seoul.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_global.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = true

  tags = {
    Name = "aurora-global-seoul-writer"
    Role = "writer"
  }
}

# Reader Instance 1 (Read Replica)
resource "aws_rds_cluster_instance" "aurora_seoul_reader1" {
  provider                     = aws.seoul
  identifier                   = "aurora-global-seoul-reader1"
  cluster_identifier           = aws_rds_cluster.aurora_seoul.id
  instance_class               = "db.r6g.large"
  engine                       = aws_rds_cluster.aurora_seoul.engine
  engine_version               = aws_rds_cluster.aurora_seoul.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_global.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = true

  tags = {
    Name = "aurora-global-seoul-reader1"
    Role = "reader"
  }
}

# Reader Instance 2 (Read Replica for HA)
resource "aws_rds_cluster_instance" "aurora_seoul_reader2" {
  provider                     = aws.seoul
  identifier                   = "aurora-global-seoul-reader2"
  cluster_identifier           = aws_rds_cluster.aurora_seoul.id
  instance_class               = "db.r6g.large"
  engine                       = aws_rds_cluster.aurora_seoul.engine
  engine_version               = aws_rds_cluster.aurora_seoul.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_global.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = true

  tags = {
    Name = "aurora-global-seoul-reader2"
    Role = "reader"
  }
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  provider            = aws.seoul
  alarm_name          = "aurora-global-seoul-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU utilization is too high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora_seoul.id
  }
}

resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  provider            = aws.seoul
  alarm_name          = "aurora-global-seoul-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 800
  alarm_description   = "Aurora database connections are too high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora_seoul.id
  }
}

# Get AWS Account ID
data "aws_caller_identity" "current" {
  provider = aws.seoul
}
