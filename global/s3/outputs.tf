output "s3_bucket_name" {
  description = "Name of the primary S3 bucket for Aurora backups"
  value       = aws_s3_bucket.aurora_global.id
}

output "s3_bucket_arn" {
  description = "ARN of the primary S3 bucket"
  value       = aws_s3_bucket.aurora_global.arn
}

output "s3_bucket_replica_name" {
  description = "Name of the replica S3 bucket"
  value       = aws_s3_bucket.aurora_global_replica.id
}

output "s3_bucket_replica_arn" {
  description = "ARN of the replica S3 bucket"
  value       = aws_s3_bucket.aurora_global_replica.arn
}

output "replication_role_arn" {
  description = "ARN of the S3 replication IAM role"
  value       = aws_iam_role.s3_replication.arn
}
