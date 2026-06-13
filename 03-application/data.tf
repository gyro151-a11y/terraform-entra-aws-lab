# Dynamically fetch our secure API token from AWS Parameter Store at runtime
data "aws_ssm_parameter" "external_api_token" {
  name            = "/devops-lab/sandbox/api_token"
  with_decryption = true
}

# Read pre-existing network IDs written by the foundation tier
data "aws_ssm_parameter" "vpc_id" {
  name = "/devops-lab/vpc/id"
}

data "aws_ssm_parameter" "web_sg_id" {
  name = "/devops-lab/network/web-sg-id"
}

data "aws_ssm_parameter" "db_sg_id" {
  name = "/devops-lab/network/db-sg-id"
}

data "aws_ssm_parameter" "public_subnet_1" {
  name = "/devops-lab/vpc/public-subnet-1"
}

data "aws_ssm_parameter" "public_subnet_2" {
  name = "/devops-lab/vpc/public-subnet-2"
}

data "aws_ssm_parameter" "private_subnet_1" {
  name = "/devops-lab/vpc/private-subnet-1"
}

data "aws_ssm_parameter" "private_subnet_2" {
  name = "/devops-lab/vpc/private-subnet-2"
}

# Read the active output metadata from your CloudFormation ALB stack
data "aws_cloudformation_stack" "alb_tier" {
  name = "devops-lab-alb-tier"
}
