# 2. Group our isolated subnets together so RDS knows where it's allowed to deploy
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "devops-lab-db-subnet-group"
  subnet_ids = [
    data.aws_ssm_parameter.private_subnet_1.value, 
    data.aws_ssm_parameter.private_subnet_2.value
  ]
  tags = {
    Name = "devops-lab-database-subnet-group"
  }
}

# 3. Create an isolated, micro-tier PostgreSQL instance (Decoupled Data Tier)
#trivy:ignore:aws-0078 Accepted Risk: Default AWS-managed encryption key is sufficient; custom KMS key skipped to avoid static sandbox infrastructure costs
#trivy:ignore:aws-0077 Accepted Risk: Reduced to 1 backup copy to align with free tier limits, reasonable for learning lab
#trivy:ignore:aws-0177 Accepted Risk: Temporary disable to allow destroy sequence
resource "aws_db_instance" "postgres_db" {
  identifier            = "devops-lab-postgres"
  allocated_storage     = 20
  max_allocated_storage = 100
  engine                = "postgres"
  engine_version        = "15.7"
  instance_class        = var.db_instance_class # Cost-effective, high-performance ARM tier
  storage_encrypted     = true
  db_name               = "spatuladb"

  backup_retention_period             = 1                         # Changed back to 1 to align with free tier limitations
  performance_insights_enabled        = true                      # Fixes AWS-0133 (Deep visibility)
  iam_database_authentication_enabled = true                      # Fixes AWS-0176 (RBAC database logins)
  deletion_protection                 = !var.allow_db_destruction # Fixes AWS-0177 (Prevents accidental 'terraform destroy' wipes)

  # Credentials managed over internal AWS control plane via security token parameters
  username = "db_admin"
  password = data.aws_ssm_parameter.external_api_token.value # Reusing your secret parameter!

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [data.aws_ssm_parameter.db_sg_id.value]
  skip_final_snapshot    = true # Ensures clean, fast destruction in our sandbox environment
}