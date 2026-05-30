# 1. Provision a secondary private subnet in a separate Availability Zone for database high-availability
resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "devops-lab-private-subnet-b"
  }
}

# 2. Group our isolated subnets together so RDS knows where it's allowed to deploy
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "devops-lab-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "devops-lab-database-subnet-group"
  }
}

# 3. Create an isolated, micro-tier PostgreSQL instance (Decoupled Data Tier)
resource "aws_db_instance" "postgres_db" {
  identifier             = "devops-lab-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.db_instance_class # Cost-effective, high-performance ARM tier
  db_name                = "spatuladb"
  
  # Credentials managed over internal AWS control plane via security token parameters
  username               = "db_admin"
  password               = data.aws_ssm_parameter.external_api_token.value # Reusing your secret parameter!
  
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true # Ensures clean, fast destruction in our sandbox environment
}