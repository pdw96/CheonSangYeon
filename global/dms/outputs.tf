output "replication_instance_arn" {
  description = "ARN of the DMS Replication Instance"
  value       = aws_dms_replication_instance.migration.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS Replication Instance"
  value       = aws_dms_replication_instance.migration.replication_instance_id
}

output "source_endpoint_arn" {
  description = "ARN of the Source Endpoint (IDC MariaDB)"
  value       = aws_dms_endpoint.source_idc_mariadb.endpoint_arn
}

output "target_endpoint_arn" {
  description = "ARN of the Target Endpoint (Aurora MySQL)"
  value       = aws_dms_endpoint.target_aurora_mysql.endpoint_arn
}

output "migration_task_arn" {
  description = "ARN of the Migration Task"
  value       = aws_dms_replication_task.migration_task.replication_task_arn
}

output "migration_status" {
  description = "Status of the Migration Task"
  value       = aws_dms_replication_task.migration_task.status
}

output "migration_instructions" {
  description = "Instructions to monitor and manage the migration"
  value       = <<-EOT
    DMS Migration Task가 생성되었습니다.
    
    1. 마이그레이션 시작:
       aws dms start-replication-task \
         --replication-task-arn ${aws_dms_replication_task.migration_task.replication_task_arn} \
         --start-replication-task-type start-replication
    
    2. 마이그레이션 상태 확인:
       aws dms describe-replication-tasks \
         --filters Name=replication-task-arn,Values=${aws_dms_replication_task.migration_task.replication_task_arn}
    
    3. CloudWatch Logs 확인:
       aws logs tail /aws/dms/tasks/idc-to-aurora-migration-task --follow
    
    4. AWS Console에서 확인:
       https://ap-northeast-2.console.aws.amazon.com/dms/v2/home?region=ap-northeast-2#tasks
    
    마이그레이션 단계:
    - Full Load: IDC MySQL의 모든 데이터를 Aurora로 복사
    - CDC (Change Data Capture): 실시간 변경사항 동기화
    
    Source: ${data.aws_instance.idc_db.private_ip}:3306/idcdb
    Target: ${aws_dms_endpoint.target_aurora_mysql.server_name}:3306/globaldb
  EOT
}
