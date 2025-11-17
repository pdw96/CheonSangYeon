output "global_cluster_id" {
  description = "Aurora Global Cluster ID"
  value       = aws_rds_global_cluster.aurora_global.id
}

output "global_cluster_arn" {
  description = "Aurora Global Cluster ARN"
  value       = aws_rds_global_cluster.aurora_global.arn
}

output "seoul_cluster_endpoint" {
  description = "Seoul Aurora Cluster Writer Endpoint"
  value       = aws_rds_cluster.aurora_seoul.endpoint
}

output "seoul_cluster_reader_endpoint" {
  description = "Seoul Aurora Cluster Reader Endpoint"
  value       = aws_rds_cluster.aurora_seoul.reader_endpoint
}

output "seoul_cluster_id" {
  description = "Seoul Aurora Cluster ID"
  value       = aws_rds_cluster.aurora_seoul.id
}

output "seoul_writer_endpoint" {
  description = "Seoul Writer Instance Endpoint"
  value       = aws_rds_cluster_instance.aurora_seoul_writer.endpoint
}

output "seoul_reader1_endpoint" {
  description = "Seoul Reader Instance 1 Endpoint"
  value       = aws_rds_cluster_instance.aurora_seoul_reader1.endpoint
}

output "seoul_reader2_endpoint" {
  description = "Seoul Reader Instance 2 Endpoint"
  value       = aws_rds_cluster_instance.aurora_seoul_reader2.endpoint
}

output "aurora_security_group_id" {
  description = "Aurora Security Group ID"
  value       = aws_security_group.aurora_seoul.id
}

output "s3_access_role_arn" {
  description = "IAM Role ARN for Aurora S3 Access"
  value       = aws_iam_role.aurora_s3_access.arn
}

output "s3_bucket_name" {
  description = "S3 Bucket name for Aurora backups"
  value       = data.terraform_remote_state.s3.outputs.s3_bucket_name
}

output "s3_bucket_replica_name" {
  description = "S3 Replica Bucket name"
  value       = data.terraform_remote_state.s3.outputs.s3_bucket_replica_name
}

output "migration_command" {
  description = "Command to migrate data from IDC MySQL to Aurora"
  value       = <<-EOT
    # IDC DB 인스턴스에서 실행:
    mysqldump -h localhost -u idcuser -p'Password123!' idcdb > /tmp/idcdb_backup.sql
    
    # IDC에서 S3로 업로드:
    aws s3 cp /tmp/idcdb_backup.sql s3://${data.terraform_remote_state.s3.outputs.s3_bucket_name}/migration/idcdb_backup.sql
    
    # Aurora에서 복원:
    mysql -h ${aws_rds_cluster.aurora_seoul.endpoint} -u admin -p'AdminPassword123!' globaldb < /tmp/idcdb_backup.sql
    
    # 또는 S3에서 직접 로드 (Aurora 클러스터에서 실행):
    LOAD DATA FROM S3 's3://${data.terraform_remote_state.s3.outputs.s3_bucket_name}/migration/idcdb_backup.sql'
    INTO TABLE your_table
    FIELDS TERMINATED BY ','
    LINES TERMINATED BY '\n';
  EOT
}
