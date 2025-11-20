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

output "seoul_aurora_security_group_id" {
  description = "Seoul Aurora Security Group ID (from VPC module)"
  value       = data.terraform_remote_state.vpc.outputs.seoul_aurora_security_group_id
}

output "tokyo_aurora_security_group_id" {
  description = "Tokyo Aurora Security Group ID (from VPC module)"
  value       = data.terraform_remote_state.vpc.outputs.tokyo_aurora_security_group_id
}

output "s3_access_role_arn" {
  description = "IAM Role ARN for Aurora S3 Access"
  value       = aws_iam_role.aurora_s3_access.arn
}

output "migration_command" {
  description = "Command to migrate data from IDC MySQL to Aurora"
  value       = <<-EOT
    # IDC DB 인스턴스에서 실행:
    mysqldump -h localhost -u idcuser -p'Password123!' idcdb > /tmp/idcdb_backup.sql
    
    # IDC에서 S3로 업로드:
    aws s3 cp /tmp/idcdb_backup.sql s3://terraform-s3-cheonsangyeon/migration/idcdb_backup.sql
    
    # Aurora에서 복원:
    mysql -h ${aws_rds_cluster.aurora_seoul.endpoint} -u admin -p'AdminPassword123!' globaldb < /tmp/idcdb_backup.sql
    
    # 또는 S3에서 직접 로드 (Aurora 클러스터에서 실행):
    LOAD DATA FROM S3 's3://terraform-s3-cheonsangyeon/migration/idcdb_backup.sql'
    INTO TABLE your_table
    FIELDS TERMINATED BY ','
    LINES TERMINATED BY '\n';
  EOT
}

# Tokyo Outputs
output "tokyo_cluster_endpoint" {
  description = "Tokyo Aurora Cluster Reader Endpoint"
  value       = aws_rds_cluster.aurora_tokyo.endpoint
}

output "tokyo_cluster_reader_endpoint" {
  description = "Tokyo Aurora Cluster Reader Endpoint"
  value       = aws_rds_cluster.aurora_tokyo.reader_endpoint
}

output "tokyo_cluster_id" {
  description = "Tokyo Aurora Cluster ID"
  value       = aws_rds_cluster.aurora_tokyo.id
}

output "tokyo_reader1_endpoint" {
  description = "Tokyo Reader Instance 1 Endpoint"
  value       = aws_rds_cluster_instance.aurora_tokyo_reader1.endpoint
}

# RDS Proxy Outputs
output "seoul_proxy_endpoint" {
  description = "Seoul RDS Proxy Endpoint"
  value       = aws_db_proxy.aurora_seoul.endpoint
}

output "seoul_proxy_arn" {
  description = "Seoul RDS Proxy ARN"
  value       = aws_db_proxy.aurora_seoul.arn
}

output "tokyo_proxy_endpoint" {
  description = "Tokyo RDS Proxy Endpoint"
  value       = aws_db_proxy.aurora_tokyo.endpoint
}

output "tokyo_proxy_arn" {
  description = "Tokyo RDS Proxy ARN"
  value       = aws_db_proxy.aurora_tokyo.arn
}

output "connection_info" {
  description = "Database connection information"
  value = <<-EOT
    ===== Seoul Region =====
    Direct Writer Endpoint: ${aws_rds_cluster.aurora_seoul.endpoint}
    Direct Reader Endpoint: ${aws_rds_cluster.aurora_seoul.reader_endpoint}
    RDS Proxy Endpoint: ${aws_db_proxy.aurora_seoul.endpoint}
    
    ===== Tokyo Region =====
    Direct Reader Endpoint: ${aws_rds_cluster.aurora_tokyo.reader_endpoint}
    RDS Proxy Endpoint: ${aws_db_proxy.aurora_tokyo.endpoint}
    
    ===== Connection String Examples =====
    # Seoul - via Proxy (권장)
    mysql -h ${aws_db_proxy.aurora_seoul.endpoint} -u admin -p globaldb
    
    # Tokyo - via Proxy (권장)
    mysql -h ${aws_db_proxy.aurora_tokyo.endpoint} -u admin -p globaldb
    
    Note: RDS Proxy는 연결 풀링을 제공하여 성능과 안정성을 향상시킵니다.
  EOT
}
