terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Seoul Provider
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws.seoul
}

data "aws_secretsmanager_secret_version" "idc_app_password" {
  provider  = aws.seoul
  secret_id = var.idc_app_secret_arn
}

data "aws_secretsmanager_secret_version" "aurora_admin_password" {
  provider  = aws.seoul
  secret_id = var.aurora_admin_secret_arn
}

# Import Aurora outputs from S3 backend
data "terraform_remote_state" "aurora" {
  backend = "s3"
  config = {
    bucket = "aurora-global-db-backup-299145660695"
    key    = "terraform/aurora-global/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Get Seoul VPC for DMS
data "aws_vpc" "seoul" {
  provider = aws.seoul
  filter {
    name   = "tag:Name"
    values = ["seoul-vpc"]
  }
}

# Get Seoul Beanstalk subnets for DMS Replication Instance
data "aws_subnets" "seoul_private" {
  provider = aws.seoul
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.seoul.id]
  }
  filter {
    name   = "tag:Name"
    values = ["seoul-beanstalk-subnet-*"]
  }
}

locals {
  dms_subnet_ids = length(data.aws_subnets.seoul_private.ids) > 0 ? data.aws_subnets.seoul_private.ids : [
    "subnet-09ca5bf59eab4a46d",
    "subnet-0f79754b4cc788b26"
  ]
}

# Get IDC VPC
data "aws_vpc" "idc" {
  provider = aws.seoul
  filter {
    name   = "tag:Name"
    values = ["idc-vpc"]
  }
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

# IAM Role for DMS
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

# IAM Role for DMS CloudWatch Logs
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
  vpc_id      = data.aws_vpc.seoul.id

  # Allow access to IDC MySQL
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MySQL to IDC"
  }

  # Allow access to Aurora
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["20.0.0.0/16"]
    description = "MySQL to Aurora"
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

# Source Endpoint (IDC MySQL)
resource "aws_dms_endpoint" "source_idc_mysql" {
  provider      = aws.seoul
  endpoint_id   = "source-idc-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"
  server_name   = data.aws_instance.idc_db.private_ip
  port          = 3306
  database_name = "idcdb"
  username      = var.idc_app_username
  password      = data.aws_secretsmanager_secret_version.idc_app_password.secret_string
  ssl_mode      = "require"

  tags = {
    Name = "source-idc-mysql"
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
  username      = var.aurora_admin_username
  password      = data.aws_secretsmanager_secret_version.aurora_admin_password.secret_string
  ssl_mode      = "require"

  tags = {
    Name = "target-aurora-mysql"
  }
}

# DMS Replication Task (Full Load + CDC)
resource "aws_dms_replication_task" "migration_task" {
  provider                  = aws.seoul
  replication_task_id       = "idc-to-aurora-migration-task"
  migration_type            = "full-load-and-cdc"
  replication_instance_arn  = aws_dms_replication_instance.migration.replication_instance_arn
  source_endpoint_arn       = aws_dms_endpoint.source_idc_mysql.endpoint_arn
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
