terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for Terraform State
  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-aurora/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
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

# Import VPC from global/vpc module
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Use VPC outputs from remote state
locals {
  seoul_vpc_id     = data.terraform_remote_state.vpc.outputs.seoul_vpc_id
  seoul_subnet_ids = data.terraform_remote_state.vpc.outputs.seoul_private_beanstalk_subnet_ids
  tokyo_vpc_id     = data.terraform_remote_state.vpc.outputs.tokyo_vpc_id
  tokyo_subnet_ids = data.terraform_remote_state.vpc.outputs.tokyo_private_beanstalk_subnet_ids
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
          "arn:aws:s3:::terraform-s3-cheonsangyeon",
          "arn:aws:s3:::terraform-s3-cheonsangyeon/*"
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
  vpc_security_group_ids          = [data.terraform_remote_state.vpc.outputs.seoul_aurora_security_group_id]
  
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
  instance_class               = "db.r5.large"
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
  instance_class               = "db.r5.large"
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

# =======================
# Tokyo Region Resources
# =======================

# KMS Key for Tokyo Aurora Encryption
resource "aws_kms_key" "aurora_tokyo" {
  provider                = aws.tokyo
  description             = "KMS key for Aurora Global Database Tokyo encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "aurora-global-tokyo-kms"
  }
}

resource "aws_kms_alias" "aurora_tokyo" {
  provider      = aws.tokyo
  name          = "alias/aurora-global-tokyo"
  target_key_id = aws_kms_key.aurora_tokyo.key_id
}

# DB Subnet Group for Aurora (Tokyo Private Subnets)
resource "aws_db_subnet_group" "aurora_tokyo" {
  provider   = aws.tokyo
  name       = "aurora-global-tokyo-subnet-group"
  subnet_ids = local.tokyo_subnet_ids

  tags = {
    Name = "aurora-global-tokyo-subnet-group"
  }
}

# RDS Cluster Parameter Group for Tokyo
resource "aws_rds_cluster_parameter_group" "aurora_tokyo" {
  provider    = aws.tokyo
  name        = "aurora-global-tokyo-mysql80-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL 8.0 cluster parameter group for Tokyo"

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
    value = "Asia/Tokyo"
  }

  tags = {
    Name = "aurora-global-tokyo-mysql80-params"
  }
}

# DB Parameter Group for Tokyo
resource "aws_db_parameter_group" "aurora_tokyo" {
  provider    = aws.tokyo
  name        = "aurora-global-tokyo-mysql80-db-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL 8.0 DB parameter group for Tokyo"

  parameter {
    name  = "max_connections"
    value = "1000"
  }

  tags = {
    Name = "aurora-global-tokyo-mysql80-db-params"
  }
}

# Secondary Cluster (Tokyo) - Global Database 멤버
resource "aws_rds_cluster" "aurora_tokyo" {
  provider                        = aws.tokyo
  cluster_identifier              = "aurora-global-tokyo-cluster"
  engine                          = aws_rds_global_cluster.aurora_global.engine
  engine_version                  = aws_rds_global_cluster.aurora_global.engine_version
  global_cluster_identifier       = aws_rds_global_cluster.aurora_global.id
  db_subnet_group_name            = aws_db_subnet_group.aurora_tokyo.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_tokyo.name
  vpc_security_group_ids          = [data.terraform_remote_state.vpc.outputs.tokyo_aurora_security_group_id]
  kms_key_id                      = aws_kms_key.aurora_tokyo.arn
  
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  
  skip_final_snapshot       = false
  final_snapshot_identifier = "aurora-global-tokyo-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "aurora-global-tokyo-cluster"
    Environment = "production"
    Region      = "secondary"
  }

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      replication_source_identifier
    ]
  }

  depends_on = [aws_rds_cluster_instance.aurora_seoul_writer]
}

# Tokyo Reader Instance 1
resource "aws_rds_cluster_instance" "aurora_tokyo_reader1" {
  provider                     = aws.tokyo
  identifier                   = "aurora-global-tokyo-reader1"
  cluster_identifier           = aws_rds_cluster.aurora_tokyo.id
  instance_class               = "db.r5.large"
  engine                       = aws_rds_cluster.aurora_tokyo.engine
  engine_version               = aws_rds_cluster.aurora_tokyo.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_tokyo.name
  auto_minor_version_upgrade   = false
  performance_insights_enabled = true

  tags = {
    Name = "aurora-global-tokyo-reader1"
    Role = "reader"
  }
}

# =======================
# RDS Proxy for Seoul
# =======================

# Secrets Manager Secret for RDS Proxy (Seoul)
resource "aws_secretsmanager_secret" "rds_proxy_seoul" {
  provider                = aws.seoul
  name                    = "rds-proxy-aurora-seoul-credentials"
  description             = "Aurora database credentials for RDS Proxy"
  recovery_window_in_days = 0

  tags = {
    Name = "rds-proxy-aurora-seoul-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_proxy_seoul" {
  provider      = aws.seoul
  secret_id     = aws_secretsmanager_secret.rds_proxy_seoul.id
  secret_string = jsonencode({
    username = "admin"
    password = "AdminPassword123!"
  })
}

# IAM Role for RDS Proxy (Seoul)
resource "aws_iam_role" "rds_proxy_seoul" {
  provider = aws.seoul
  name     = "aurora-rds-proxy-seoul-role"

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
    Name = "aurora-rds-proxy-seoul-role"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager (Seoul)
resource "aws_iam_role_policy" "rds_proxy_seoul" {
  provider = aws.seoul
  name     = "aurora-rds-proxy-seoul-policy"
  role     = aws_iam_role.rds_proxy_seoul.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_proxy_seoul.arn
      }
    ]
  })
}

# RDS Proxy for Seoul Cluster
resource "aws_db_proxy" "aurora_seoul" {
  provider               = aws.seoul
  name                   = "aurora-global-seoul-proxy"
  engine_family          = "MYSQL"
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.rds_proxy_seoul.arn
  }
  role_arn               = aws_iam_role.rds_proxy_seoul.arn
  vpc_subnet_ids         = local.seoul_subnet_ids
  require_tls            = false
  idle_client_timeout    = 1800

  tags = {
    Name = "aurora-global-seoul-proxy"
  }
}

# RDS Proxy Target Group (Seoul)
resource "aws_db_proxy_default_target_group" "aurora_seoul" {
  provider      = aws.seoul
  db_proxy_name = aws_db_proxy.aurora_seoul.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

# RDS Proxy Target (Seoul)
resource "aws_db_proxy_target" "aurora_seoul" {
  provider               = aws.seoul
  db_proxy_name          = aws_db_proxy.aurora_seoul.name
  target_group_name      = aws_db_proxy_default_target_group.aurora_seoul.name
  db_cluster_identifier  = aws_rds_cluster.aurora_seoul.id
}

# =======================
# RDS Proxy for Tokyo
# =======================

# Secrets Manager Secret for RDS Proxy (Tokyo)
resource "aws_secretsmanager_secret" "rds_proxy_tokyo" {
  provider                = aws.tokyo
  name                    = "rds-proxy-aurora-tokyo-credentials"
  description             = "Aurora database credentials for RDS Proxy Tokyo"
  recovery_window_in_days = 0

  tags = {
    Name = "rds-proxy-aurora-tokyo-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_proxy_tokyo" {
  provider      = aws.tokyo
  secret_id     = aws_secretsmanager_secret.rds_proxy_tokyo.id
  secret_string = jsonencode({
    username = "admin"
    password = "AdminPassword123!"
  })
}

# IAM Role for RDS Proxy (Tokyo)
resource "aws_iam_role" "rds_proxy_tokyo" {
  provider = aws.tokyo
  name     = "aurora-rds-proxy-tokyo-role"

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
    Name = "aurora-rds-proxy-tokyo-role"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager (Tokyo)
resource "aws_iam_role_policy" "rds_proxy_tokyo" {
  provider = aws.tokyo
  name     = "aurora-rds-proxy-tokyo-policy"
  role     = aws_iam_role.rds_proxy_tokyo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_proxy_tokyo.arn
      }
    ]
  })
}

# RDS Proxy for Tokyo Cluster
resource "aws_db_proxy" "aurora_tokyo" {
  provider               = aws.tokyo
  name                   = "aurora-global-tokyo-proxy"
  engine_family          = "MYSQL"
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.rds_proxy_tokyo.arn
  }
  role_arn               = aws_iam_role.rds_proxy_tokyo.arn
  vpc_subnet_ids         = local.tokyo_subnet_ids
  require_tls            = false
  idle_client_timeout    = 1800

  tags = {
    Name = "aurora-global-tokyo-proxy"
  }
}

# RDS Proxy Target Group (Tokyo)
resource "aws_db_proxy_default_target_group" "aurora_tokyo" {
  provider      = aws.tokyo
  db_proxy_name = aws_db_proxy.aurora_tokyo.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

# RDS Proxy Target (Tokyo)
resource "aws_db_proxy_target" "aurora_tokyo" {
  provider               = aws.tokyo
  db_proxy_name          = aws_db_proxy.aurora_tokyo.name
  target_group_name      = aws_db_proxy_default_target_group.aurora_tokyo.name
  db_cluster_identifier  = aws_rds_cluster.aurora_tokyo.id
}
