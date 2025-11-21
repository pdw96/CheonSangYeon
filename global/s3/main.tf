terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = var.bucket_name
    force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
      status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
    bucket = aws_s3_bucket.terraform_state.id

    rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
    }
}

resource "aws_s3_bucket_public_access_block" "this" {
    bucket = aws_s3_bucket.terraform_state.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "RootAccountPutObject"
                Effect = "Allow"
                Principal = {
                    AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
                }
                Action = [
                    "s3:PutObject",
                    "s3:PutObjectAcl"
                ]
                Resource = "${aws_s3_bucket.terraform_state.arn}/*"
            },
            {
                Sid = "AllIAMUsersGetObject"
                Effect = "Allow"
                Principal = {
                    AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
                }
                Action = [
                    "s3:GetObject",
                    "s3:ListBucket"
                ]
                Resource = [
                    "${aws_s3_bucket.terraform_state.arn}",
                    "${aws_s3_bucket.terraform_state.arn}/*"
                ]
            }
        ]
    })
}

resource "aws_dynamodb_table" "terraform_locks" {
    name = var.table_name
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"

    attribute {
      name = "LockID"
      type = "S"
    }
}