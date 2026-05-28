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