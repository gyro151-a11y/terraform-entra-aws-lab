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

# 1. Register your local public key via a dynamic input variable
resource "aws_key_pair" "lab_ssh_key" {
  key_name   = "devops-lab-wsl-key"
  public_key = var.ssh_public_key # <--- Swapped to a standard variable reference
}

# Temporary public jump box for zero-trust network verification
resource "aws_instance" "jump_box" {
  ami                    = var.ami_id # Same custom baseline image
  instance_type          = var.instance_type
  subnet_id              = data.aws_ssm_parameter.public_subnet_1.value
  vpc_security_group_ids = [data.aws_ssm_parameter.web_sg_id.value]
  # 🔒 Mount the SSM identity profile to the hardware
  iam_instance_profile = aws_iam_instance_profile.jumpbox_profile.name
  # key_name               = aws_key_pair.lab_ssh_key.key_name

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

# 🆔 Create an IAM Role for the EC2 Instance
resource "aws_iam_role" "jumpbox_ssm_role" {
  name = "devops-lab-jumpbox-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# 🔐 Add a scoped read policy for SSM Parameter Store
resource "aws_iam_role_policy" "jumpbox_ssm_readonly" {
  name = "devops-lab-jumpbox-ssm-readonly"
  role = aws_iam_role.jumpbox_ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowDescribeAllParameters"
        Effect   = "Allow"
        Action   = "ssm:DescribeParameters"
        Resource = "*" # DescribeParameters requires "*" because it scans the entire regional inventory
      },
      {
        Sid    = "AllowReadScopedParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ],
        # 🔒 Hardened: Can only read configurations belonging to your lab namespace
        Resource = "arn:aws:ssm:us-east-1:629897139637:parameter/devops-lab/*"
      }
    ]
  })
}

# 📑 Attach the standard AWS Managed SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.jumpbox_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 📑 Attach the standard CloudWatch Agent Server policy to the role
resource "aws_iam_role_policy_attachment" "cw_agent_attach" {
  role       = aws_iam_role.jumpbox_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 🎟️ Package the role into an Instance Profile that EC2 can consume
resource "aws_iam_instance_profile" "jumpbox_profile" {
  name = "devops-lab-jumpbox-ssm-profile"
  role = aws_iam_role.jumpbox_ssm_role.name
}


# 2. Launch the Virtual Server using your Custom Golden Image
resource "aws_instance" "web_server" {
  ami           = var.ami_id                                    # <--- Verified baseline AMI from Phase 2!
  instance_type = var.instance_type                             # Aligns with modern free-tier accounts
  subnet_id     = data.aws_ssm_parameter.private_subnet_1.value # Places the server inside your private room

  # Attach the Firewall Guard rules we defined right above
  vpc_security_group_ids = [data.aws_ssm_parameter.web_sg_id.value]

  # Inject the key pair configuration
  # key_name = aws_key_pair.lab_ssh_key.key_name

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