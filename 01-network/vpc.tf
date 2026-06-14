# 1. Create the Isolated VPC Container
resource "aws_vpc" "lab_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "devops-lab-vpc"
    Environment = "var.environment"
  }
}


# 2. Build an Internet Gateway (The Cloud Router Door)
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "devops-lab-igw"
  }
}

# 3a. Carve Out a Public Subnet for Public-Facing Systems
# trivy:ignore:AVD-AWS-0164
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-lab-public-subnet-a"
  }
}

# 3b. Carve Out a secondary Public Subnet for Public-Facing Systems (Necessary for ALB)
# trivy:ignore:AVD-AWS-0164
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-lab-public-subnet-b"
  }
}

# 4. Create a Route Table (The Traffic Traffic Controller)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "devops-lab-public-rt"
  }
}

# 5a. Bind Subnet A to the Traffic Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 5b. Bind Subnet B to the Traffic Route Table
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# ENTERPRISE ZERO-TRUST TIERS
# ==========================================

# 1. The Isolated Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = var.private_subnet_a_cidr # Distinct CIDR room away from public space
  availability_zone = "${var.aws_region}a"

  # Ensure instances spawned here never receive an automatic public IP
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-lab-private-subnet"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.private_subnet_b_cidr # Ensure this variable or string is distinct!
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-lab-private-subnet-b"
  }
}

# 2. Allocate a Static IP (Elastic IP) dedicated for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.lab_igw] # Ensures clean ordering sequence

  tags = {
    Name = "devops-lab-nat-eip"
  }
}

# 3. Deploy the NAT Gateway inside the PUBLIC room so it can talk outward
resource "aws_nat_gateway" "lab_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id # MUST sit inside the public tier

  tags = {
    Name = "devops-lab-nat-gateway"
  }
}

# 4. Create a dedicated signpost Routing Table for the private space
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  # Outbound route: All internet traffic gets securely funneled through the NAT
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab_nat.id
  }

  tags = {
    Name = "devops-lab-private-rt"
  }
}

# 5. Bind the Private Subnet to its new Routing Table
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Bind the secondary private subnet to your private routing table
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# CloudWatch Log Group to capture standard out stream from our stateless container
#trivy:ignore:aws-0017 Accepted Risk: Native AWS encryption is active; custom KMS key skipped to avoid static hourly charges
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/devops-lab-app"
  retention_in_days = 3 # Automatically purges logs to keep storage costs zeroed out
}

# Strict firewall isolation for the private database tier
resource "aws_security_group" "db_sg" {
  name        = "devops-lab-db-sg"
  description = "Allow inbound PostgreSQL traffic strictly from the web server tier"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description     = "PostgreSQL access from web security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Tight source-mapping constraint
  }

  # FIXED: AWS-0104: Removed unnecessary open egress from db sg

  tags = {
    Name = "devops-lab-database-sg"
  }
}

# 🌐 1. Create a dedicated, isolated Log Group for Network Telemetry
resource "aws_cloudwatch_log_group" "vpc_network_logs" {
  name              = "/vpc/devops-lab-flowlogs"
  retention_in_days = 7 # 💰 Keeps lab storage costs low
}

# 🛰️ 2. Restructure the network traffic audit logger
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_network_logs.arn # 🎯 Point to the new dedicated group
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.lab_vpc.id
}

# The IAM Role allowing the VPC engine to write logs to CloudWatch
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "devops-lab-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "devops-lab-vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

# ==============================================================================
# SYSTEMS MANAGER (SSM) PARAMETER STORE BRIDGES FOR CLOUDFORMATION
# ==============================================================================

resource "aws_ssm_parameter" "public_subnet_one" {
  name  = "/devops-lab/vpc/public-subnet-1"
  type  = "String"
  value = aws_subnet.public_subnet.id
}

resource "aws_ssm_parameter" "public_subnet_two" {
  name  = "/devops-lab/vpc/public-subnet-2"
  type  = "String"
  value = aws_subnet.public_subnet_b.id
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/devops-lab/vpc/id"
  type  = "String"
  value = aws_vpc.lab_vpc.id
}

resource "aws_ssm_parameter" "private_subnet_one" {
  name  = "/devops-lab/vpc/private-subnet-1"
  type  = "String"
  value = aws_subnet.private_subnet.id
}

resource "aws_ssm_parameter" "private_subnet_two" {
  name  = "/devops-lab/vpc/private-subnet-2"
  type  = "String"
  value = aws_subnet.private_subnet_b.id
}


# ==========================================
# CORE LAYER 3 FIREWALLS (SECURITY GROUPS)
# ==========================================

resource "aws_security_group" "web_sg" {
  name        = "devops-lab-web-sg"
  description = "Allow inbound routing for administrative and container ingress traffic"
  vpc_id      = aws_vpc.lab_vpc.id

  # Container Routing Ingress 
  ingress {
    description = "Allow internal HTTP traffic from VPC loop"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow wide internal VPC loop communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Global Outbound
  egress {
    # trivy:ignore:aws-0104  # Approved: Web application clusters require outbound internet routing for system updates and package patching
    description = "Allow all outbound software update payloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-lab-firewall"
  }
}

/*
resource "aws_security_group" "db_sg" {
  name        = "devops-lab-db-sg"
  description = "Allow inbound PostgreSQL traffic strictly from the web server tier"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description     = "PostgreSQL access from web security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Native inline compilation block
  }

  tags = {
    Name = "devops-lab-database-sg"
  }
}
*/

# Expose Security Groups for the application layer to find later
resource "aws_ssm_parameter" "web_sg_id" {
  name  = "/devops-lab/network/web-sg-id"
  type  = "String"
  value = aws_security_group.web_sg.id
}

resource "aws_ssm_parameter" "db_sg_id" {
  name  = "/devops-lab/network/db-sg-id"
  type  = "String"
  value = aws_security_group.db_sg.id
}
