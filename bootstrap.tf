# 1. Secure Remote State Storage Bucket
resource "aws_s3_bucket" "state_bucket" {
  bucket        = "devops-lab-state-bucket-629897139637" # S3 names must be globally unique
  force_destroy = true # Allows easy clean up via 'make destroy' later

  tags = {
    Name = "devops-lab-terraform-state"
  }
}

# Enable Object Versioning to track changes and prevent corruption
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
