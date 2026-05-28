# 1. Register your local WSL public key with the AWS Region
resource "aws_key_pair" "lab_ssh_key" {
  key_name   = "devops-lab-wsl-key"
  public_key = file("~/.ssh/devops_lab_key.pub") # Dynamically reads your local file
}

# 1. Define an Isolated Firewall Guard (Security Group)
resource "aws_security_group" "web_sg" {
  name        = "devops-lab-web-sg"
  description = "Allow baseline administrative traffic into our instance"
  vpc_id      = aws_vpc.lab_vpc.id # Links directly to your live network container

  # Inbound Rule: Allow secure SSH terminal connections
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open universally for lab validation mapping
  }

  # Outbound Rule: Let the server download internal software packages freely
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-lab-firewall"
  }
}

# 2. Launch the Virtual Server using your Custom Golden Image
resource "aws_instance" "web_server" {
  ami           = "ami-0f3f80eef773db04e" # <--- Verified baseline AMI from Phase 2!
  instance_type = "t3.micro"               # Aligns with modern free-tier accounts
  subnet_id     = aws_subnet.public_subnet.id # Places the server inside your public room
  
  # Attach the Firewall Guard rules we defined right above
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Inject the key pair configuration
  key_name               = aws_key_pair.lab_ssh_key.key_name

  tags = {
    Name        = "devops-lab-web-instance"
    Environment = "sandbox"
  }
}