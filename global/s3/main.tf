terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Provider (Seoul)
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# Secondary Provider (Tokyo)
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# S3 Bucket for Aurora Global Database Backups
resource "aws_s3_bucket" "aurora_global" {
  provider = aws.seoul
  bucket   = "aurora-global-db-backup-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "aurora-global-db-backup"
    Environment = "production"
    Purpose     = "Aurora Global Database Backups and Replication"
  }
}

# Versioning for data protection
resource "aws_s3_bucket_versioning" "aurora_global" {
  provider = aws.seoul
  bucket   = aws_s3_bucket.aurora_global.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "aurora_global" {
  provider = aws.seoul
  bucket   = aws_s3_bucket.aurora_global.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "aurora_global" {
  provider = aws.seoul
  bucket   = aws_s3_bucket.aurora_global.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "aurora_global" {
  provider = aws.seoul
  bucket   = aws_s3_bucket.aurora_global.id

  rule {
    id     = "transition-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Cross-Region Replication to Tokyo (for disaster recovery)
resource "aws_s3_bucket" "aurora_global_replica" {
  provider = aws.tokyo
  bucket   = "aurora-global-db-backup-replica-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "aurora-global-db-backup-replica"
    Environment = "production"
    Purpose     = "Aurora Global Database Backups Replica"
  }
}

resource "aws_s3_bucket_versioning" "aurora_global_replica" {
  provider = aws.tokyo
  bucket   = aws_s3_bucket.aurora_global_replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aurora_global_replica" {
  provider = aws.tokyo
  bucket   = aws_s3_bucket.aurora_global_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "aurora_global_replica" {
  provider = aws.tokyo
  bucket   = aws_s3_bucket.aurora_global_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for S3 Replication
resource "aws_iam_role" "s3_replication" {
  provider = aws.seoul
  name     = "s3-aurora-backup-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_replication" {
  provider = aws.seoul
  name     = "s3-aurora-backup-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.aurora_global.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.aurora_global.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.aurora_global_replica.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_replication" {
  provider   = aws.seoul
  role       = aws_iam_role.s3_replication.name
  policy_arn = aws_iam_policy.s3_replication.arn
}

# S3 Replication Configuration
resource "aws_s3_bucket_replication_configuration" "aurora_global" {
  provider = aws.seoul
  bucket   = aws_s3_bucket.aurora_global.id
  role     = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.aurora_global_replica.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.aurora_global,
    aws_s3_bucket_versioning.aurora_global_replica
  ]
}

# Get current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws.seoul
}
