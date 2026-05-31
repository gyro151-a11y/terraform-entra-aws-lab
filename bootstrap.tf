# 1. Secure Remote State Storage Bucket
resource "aws_s3_bucket" "state_bucket" {
  bucket        = "devops-lab-state-bucket-629897139637" # S3 names must be globally unique
  force_destroy = true                                   # Allows easy clean up via 'make destroy' later

  tags = {
    Name = "devops-lab-terraform-state"
  }
}

# Hardens the S3 State Bucket by completely blocking all public avenues
resource "aws_s3_bucket_public_access_block" "state_bucket_acl_block" {
  bucket                  = aws_s3_bucket.state_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Object Versioning to track changes and prevent corruption
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
