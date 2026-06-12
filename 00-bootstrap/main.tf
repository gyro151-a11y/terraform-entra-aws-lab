# =====================================================================
# THE CENTRAL GITOPS STATE STORAGE (S3)
# =====================================================================

resource "aws_s3_bucket" "state_bucket" {
  bucket        = "jeff-edgar-devops-lab-state"
  force_destroy = false # 🔒 Prevents accidental pipeline deletion of state history

  tags = {
    Name        = "devops-lab-state-storage"
    Environment = "Management"
  }
}

# Enforce encryption at rest for sensitive state strings
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all accidental public exposure to the state map
resource "aws_s3_bucket_public_access_block" "state_security_shield" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}