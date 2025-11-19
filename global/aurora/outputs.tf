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

output "idc_app_password_secret_arn" {
  description = "Secrets Manager ARN that stores the IDC application database password"
  value       = var.idc_app_secret_arn
}

output "aurora_admin_password_secret_arn" {
  description = "Secrets Manager ARN that stores the Aurora administrator password"
  value       = var.aurora_admin_secret_arn
}
