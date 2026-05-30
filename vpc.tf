# 1. Create the Isolated VPC Container
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "devops-lab-vpc"
    Environment = "sandbox"
  }
}

# 2. Build an Internet Gateway (The Cloud Router Door)
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "devops-lab-igw"
  }
}

# 3. Carve Out a Public Subnet for Public-Facing Systems
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-lab-public-subnet"
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

# 5. Bind the Subnet to the Traffic Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# ENTERPRISE ZERO-TRUST TIERS
# ==========================================

# 1. The Isolated Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.2.0/24" # Distinct CIDR room away from public space
  availability_zone = "us-east-1a"

  # Ensure instances spawned here never receive an automatic public IP
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-lab-private-subnet"
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

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "devops-lab-database-sg"
  }
}