output "source_endpoint_arn" {
  description = "Source endpoint ARN"
  value       = aws_dms_endpoint.source_aurora.endpoint_arn
}

output "target_endpoint_arn" {
  description = "Target endpoint ARN"
  value       = aws_dms_endpoint.target_azure.endpoint_arn
}

output "replication_task_arn" {
  description = "Replication task ARN"
  value       = aws_dms_replication_task.aurora_to_azure.replication_task_arn
}

output "replication_task_id" {
  description = "Replication task ID"
  value       = aws_dms_replication_task.aurora_to_azure.replication_task_id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.dms_migration.name
}

output "migration_status" {
  description = "Migration task status"
  value       = aws_dms_replication_task.aurora_to_azure.status
}
