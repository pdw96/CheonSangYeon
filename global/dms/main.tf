terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-dms/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

# Seoul Provider
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# Get VPC remote state
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws.seoul
}

# Get IDC DB Instance
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

locals {
  dms_subnet_ids = data.terraform_remote_state.vpc.outputs.seoul_private_beanstalk_subnet_ids
  azure_mysql_private_ip = "50.0.2.4"  # Azure MySQL Flexible Server Private IP
}

# DMS Subnet Group
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  provider                             = aws.seoul
  replication_subnet_group_id          = "dms-aurora-migration-subnet-group"
  replication_subnet_group_description = "DMS Subnet Group for Aurora Migration"
  subnet_ids                           = local.dms_subnet_ids

  tags = {
    Name = "dms-aurora-migration-subnet-group"
  }
}

# Route53 Private Hosted Zone for Azure MySQL DNS Resolution
resource "aws_route53_zone" "azure_mysql_private" {
  provider = aws.seoul
  name     = "mysql.database.azure.com"

  vpc {
    vpc_id = data.terraform_remote_state.vpc.outputs.seoul_vpc_id
  }

  tags = {
    Name = "azure-mysql-private-dns"
    Purpose = "Resolve Azure MySQL FQDN to Private IP via VPN"
  }
}

# Route53 A Record for Azure MySQL
resource "aws_route53_record" "azure_mysql" {
  provider = aws.seoul
  zone_id  = aws_route53_zone.azure_mysql_private.zone_id
  name     = "mysql-dr-multicloud.mysql.database.azure.com"
  type     = "A"
  ttl      = 300
  records  = [local.azure_mysql_private_ip]
}

# DMS IAM Roles
resource "aws_iam_role" "dms_vpc_role" {
  provider = aws.seoul
  name     = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "dms-vpc-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_policy" {
  provider   = aws.seoul
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  provider = aws.seoul
  name     = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "dms-cloudwatch-logs-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_policy" {
  provider   = aws.seoul
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# Security Group for DMS Replication Instance
resource "aws_security_group" "dms_replication" {
  provider    = aws.seoul
  name        = "dms-replication-sg"
  description = "Security group for DMS Replication Instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.seoul_vpc_id

  # Allow access to IDC MySQL
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MySQL to IDC"
  }

  # Allow access to Aurora via TGW
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["20.0.0.0/16", "40.0.0.0/16"]
    description = "MySQL to Aurora (Seoul and Tokyo)"
  }

  # Allow access to Azure MySQL via VPN (Azure VNet CIDR)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["50.0.0.0/16"]
    description = "MySQL to Azure DR via VPN"
  }

  # Allow HTTPS for AWS API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for AWS API"
  }

  tags = {
    Name = "dms-replication-sg"
  }
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "migration" {
  provider                     = aws.seoul
  replication_instance_id      = "aurora-migration-replication-instance"
  replication_instance_class   = "dms.t3.medium"
  allocated_storage            = 50
  engine_version               = "3.5.3"
  multi_az                     = false
  publicly_accessible          = false
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms_subnet_group.id
  vpc_security_group_ids       = [aws_security_group.dms_replication.id]
  auto_minor_version_upgrade   = false
  allow_major_version_upgrade  = false

  tags = {
    Name = "aurora-migration-replication-instance"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_policy,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs_policy
  ]
}

# Source Endpoint (IDC MariaDB via CGW)
resource "aws_dms_endpoint" "source_idc_mariadb" {
  provider      = aws.seoul
  endpoint_id   = "source-idc-mariadb"
  endpoint_type = "source"
  engine_name   = "mariadb"
  server_name   = data.aws_instance.idc_db.private_ip
  port          = 3306
  database_name = "idcdb"
  username      = "idcuser"
  password      = "Password123!"
  ssl_mode      = "none"
  
  extra_connection_attributes = "initstmt=SET FOREIGN_KEY_CHECKS=0"

  tags = {
    Name = "source-idc-mariadb"
  }
}

# Get Aurora cluster endpoint from remote state
data "terraform_remote_state" "aurora" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-aurora/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Get Azure DR infrastructure state
data "terraform_remote_state" "azure_dr" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/azure-dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Target Endpoint (Aurora MySQL)
resource "aws_dms_endpoint" "target_aurora_mysql" {
  provider      = aws.seoul
  endpoint_id   = "target-aurora-mysql"
  endpoint_type = "target"
  engine_name   = "aurora"
  server_name   = data.terraform_remote_state.aurora.outputs.seoul_cluster_endpoint
  port          = 3306
  database_name = "globaldb"
  username      = "admin"
  password      = "AdminPassword123!"
  ssl_mode      = "none"

  tags = {
    Name = "target-aurora-mysql"
  }
}

# Target Endpoint (Azure MySQL Flexible Server via VPN)
resource "aws_dms_endpoint" "target_azure_mysql" {
  provider      = aws.seoul
  endpoint_id   = "target-azure-mysql"
  endpoint_type = "target"
  engine_name   = "mysql"
  server_name   = data.terraform_remote_state.azure_dr.outputs.mysql_server_fqdn
  port          = 3306
  database_name = "globaldb"
  username      = var.azure_mysql_username
  password      = var.azure_mysql_password
  ssl_mode      = "none"

  extra_connection_attributes = "initstmt=SET FOREIGN_KEY_CHECKS=0"

  tags = {
    Name = "target-azure-mysql-dr"
  }
}

# DMS Replication Task (Full Load + CDC)
resource "aws_dms_replication_task" "migration_task" {
  provider                  = aws.seoul
  replication_task_id       = "idc-to-aurora-migration-task"
  migration_type            = "full-load"
  replication_instance_arn  = aws_dms_replication_instance.migration.replication_instance_arn
  source_endpoint_arn       = aws_dms_endpoint.source_idc_mariadb.endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.target_aurora_mysql.endpoint_arn
  table_mappings            = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "select-all-tables"
        object-locator = {
          schema-name = "idcdb"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema                 = ""
      SupportLobs                  = true
      FullLobMode                  = false
      LobChunkSize                 = 64
      LimitedSizeLobMode           = true
      LobMaxSize                   = 32
    }
    FullLoadSettings = {
      TargetTablePrepMode          = "DROP_AND_CREATE"
      CreatePkAfterFullLoad        = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks          = 8
      TransactionConsistencyTimeout = 600
      CommitRate                   = 10000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        {
          Id       = "TRANSFORMATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_UNLOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "IO"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_LOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "PERFORMANCE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_CAPTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SORTER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "REST_SERVER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "VALIDATOR_EXT"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_APPLY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TASK_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TABLES_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "METADATA_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_FACTORY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMON"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "ADDONS"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "DATA_STRUCTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMUNICATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_TRANSFER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    }
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
      HandleSourceTableAltered   = true
    }
    ErrorBehavior = {
      DataErrorPolicy      = "LOG_ERROR"
      EventErrorPolicy     = "IGNORE"
      DataTruncationErrorPolicy = "LOG_ERROR"
      DataErrorEscalationPolicy = "SUSPEND_TABLE"
      DataErrorEscalationCount  = 1000
      TableErrorPolicy     = "SUSPEND_TABLE"
      TableErrorEscalationPolicy = "STOP_TASK"
      TableErrorEscalationCount  = 1000
      RecoverableErrorCount      = -1
      RecoverableErrorInterval   = 5
      RecoverableErrorThrottling = true
      RecoverableErrorThrottlingMax = 1800
      ApplyErrorDeletePolicy     = "IGNORE_RECORD"
      ApplyErrorInsertPolicy     = "LOG_ERROR"
      ApplyErrorUpdatePolicy     = "LOG_ERROR"
      ApplyErrorEscalationPolicy = "LOG_ERROR"
      ApplyErrorEscalationCount  = 0
      FullLoadIgnoreConflicts    = true
    }
  })

  tags = {
    Name = "idc-to-aurora-migration-task"
  }

  lifecycle {
    ignore_changes = [
      replication_task_settings
    ]
  }
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms_migration" {
  provider          = aws.seoul
  name              = "/aws/dms/tasks/idc-to-aurora-migration-task"
  retention_in_days = 7

  tags = {
    Name = "dms-migration-logs"
  }
}
