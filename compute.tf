# # 1. Create an IAM Assume Role Policy that allows EC2 to use this identity
# resource "aws_iam_role" "ssm_role" {
#   name = "devops-lab-ssm-instance-role"
# 
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }
# 
# # 2. Attach Amazon's Official Managed Core SSM Policy to the Role
# resource "aws_iam_role_policy_attachment" "ssm_attach" {
#   role       = aws_iam_role.ssm_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }
# 
# # 3. Wrap the Role inside an Instance Profile container so EC2 can physically wear it
# resource "aws_iam_instance_profile" "ssm_profile" {
#   name = "devops-lab-ssm-profile"
#   role = aws_iam_role.ssm_role.name
# }

# Dynamically fetch our secure API token from AWS Parameter Store at runtime
data "aws_ssm_parameter" "external_api_token" {
  name            = "/devops-lab/sandbox/api_token"
  with_decryption = true
}

# 1. Register your local public key via a dynamic input variable
resource "aws_key_pair" "lab_ssh_key" {
  key_name   = "devops-lab-wsl-key"
  public_key = var.ssh_public_key # <--- Swapped to a standard variable reference
}

# 1. Define an Isolated Firewall Guard (Security Group)
resource "aws_security_group" "web_sg" {
  name        = "devops-lab-web-sg"
  description = "Allow baseline administrative traffic into our instance"
  vpc_id      = aws_vpc.lab_vpc.id # Links directly to your live network container

  # Inbound Rule 1: Allow secure SSH terminal connections
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
    description = "Allow baseline inbound SSH"
  }

  # Inbound Rule 2: Allow all resources INSIDE the VPC to talk to each other
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"] # Maps the entire scope of your local network
    description = "Allow open internal VPC communication"
  }

  # Outbound Rule: Let the server download internal software packages freely
  egress {
    # tfsec:ignore:aws-ec2-no-public-egress
    # trivy:ignore:AVD-AWS-0104
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound for update/software download"
  }

  tags = {
    Name = "devops-lab-firewall"
  }
}

# Temporary public jump box for zero-trust network verification
resource "aws_instance" "jump_box" {
  ami                    = var.ami_id # Same custom baseline image
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id # <--- Placed in PUBLIC tier
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.lab_ssh_key.key_name

  # FIXES AWS-0028: Enforce IMDSv2 tokens
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Explicitly mandate session tokens
  }

  # FIXES AWS-0131: Encrypt hard drive
  root_block_device {
    encrypted   = true # FIXED: Encrypts the OS drive using the free default AWS managed key
    volume_type = "gp3"
  }

  tags = {
    Name = "devops-lab-public-jump-box"
  }
}

# 2. Launch the Virtual Server using your Custom Golden Image
resource "aws_instance" "web_server" {
  ami           = var.ami_id                   # <--- Verified baseline AMI from Phase 2!
  instance_type = var.instance_type            # Aligns with modern free-tier accounts
  subnet_id     = aws_subnet.private_subnet.id # Places the server inside your private room

  # Attach the Firewall Guard rules we defined right above
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Inject the key pair configuration
  key_name = aws_key_pair.lab_ssh_key.key_name

  # FIXES AWS-0028: Enforce IMDSv2 tokens
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Explicitly mandate session tokens
  }

  # FIXES AWS-0131: Encrypt hard drive
  root_block_device {
    encrypted   = true # FIXED: Encrypts the OS drive using the free default AWS managed key
    volume_type = "gp3"
  }

  # # Equip the instance with its security badge
  # iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "=== SYSTEM INITIALIZATION ==="
              
              # Ingest the cloud secret into a local system environment variable
              export API_TOKEN="${data.aws_ssm_parameter.external_api_token.value}"
              
              # Masking the secret in the console log for strict security hygiene
              echo "Secret Token successfully ingested with length: $${#API_TOKEN} characters"
              EOF

  tags = {
    Name        = "devops-lab-web-instance"
    Environment = "sandbox"
  }
}