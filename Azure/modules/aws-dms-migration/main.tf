# ===== AWS DMS Migration to Azure Module =====
# Creates AWS DMS endpoints and migration tasks for Aurora → Azure MySQL replication

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get DMS Replication Instance from remote state
data "terraform_remote_state" "dms" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = var.dms_state_key
    region = var.aws_region
  }
}

# Get Aurora cluster endpoint from remote state
data "terraform_remote_state" "aurora" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = var.aurora_state_key
    region = var.aws_region
  }
}

# Source Endpoint (Aurora MySQL)
resource "aws_dms_endpoint" "source_aurora" {
  endpoint_id   = var.source_endpoint_id
  endpoint_type = "source"
  engine_name   = "aurora"
  server_name   = data.terraform_remote_state.aurora.outputs.seoul_cluster_endpoint
  port          = 3306
  database_name = var.source_database_name
  username      = var.source_username
  password      = var.source_password
  ssl_mode      = var.ssl_mode

  tags = merge(
    var.tags,
    {
      Name = var.source_endpoint_id
    }
  )
}

# Target Endpoint (Azure MySQL via VPN)
resource "aws_dms_endpoint" "target_azure" {
  endpoint_id   = var.target_endpoint_id
  endpoint_type = "target"
  engine_name   = "mysql"
  server_name   = var.azure_mysql_endpoint
  port          = 3306
  database_name = var.target_database_name
  username      = var.target_username
  password      = var.target_password
  ssl_mode      = var.ssl_mode
  
  extra_connection_attributes = var.extra_connection_attributes

  tags = merge(
    var.tags,
    {
      Name = var.target_endpoint_id
    }
  )
}

# DMS Replication Task (Aurora → Azure MySQL)
resource "aws_dms_replication_task" "aurora_to_azure" {
  replication_task_id      = var.replication_task_id
  migration_type           = var.migration_type
  replication_instance_arn = data.terraform_remote_state.dms.outputs.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_aurora.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_azure.endpoint_arn
  
  table_mappings = jsonencode({
    rules = concat(
      [
        {
          rule-type = "selection"
          rule-id   = "1"
          rule-name = "select-all-tables"
          object-locator = {
            schema-name = var.source_database_name
            table-name  = "%"
          }
          rule-action = "include"
        }
      ],
      var.transform_schema ? [
        {
          rule-type = "transformation"
          rule-id   = "2"
          rule-name = "rename-schema"
          rule-target = "schema"
          object-locator = {
            schema-name = var.source_database_name
          }
          rule-action = "rename"
          value       = var.target_database_name
        }
      ] : []
    )
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema       = ""
      SupportLobs        = true
      FullLobMode        = false
      LobChunkSize       = 64
      LimitedSizeLobMode = true
      LobMaxSize         = 32
    }
    FullLoadSettings = {
      TargetTablePrepMode             = var.target_table_prep_mode
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 8
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 10000
    }
    Logging = {
      EnableLogging = var.enable_logging
    }
    ErrorBehavior = {
      DataErrorPolicy           = "LOG_ERROR"
      EventErrorPolicy          = "IGNORE"
      DataTruncationErrorPolicy = "LOG_ERROR"
      FullLoadIgnoreConflicts   = true
    }
  })

  tags = merge(
    var.tags,
    {
      Name = var.replication_task_id
    }
  )

  lifecycle {
    ignore_changes = [
      replication_task_settings
    ]
  }
}

# CloudWatch Log Group for Migration
resource "aws_cloudwatch_log_group" "dms_migration" {
  name              = "/aws/dms/tasks/${var.replication_task_id}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.replication_task_id}-logs"
    }
  )
}

# Start migration task automatically if enabled
resource "null_resource" "start_migration" {
  count = var.auto_start_migration ? 1 : 0

  provisioner "local-exec" {
    command = "aws dms start-replication-task --replication-task-arn ${aws_dms_replication_task.aurora_to_azure.replication_task_arn} --start-replication-task-type start-replication --region ${var.aws_region}"
  }

  depends_on = [
    aws_dms_replication_task.aurora_to_azure
  ]
}
