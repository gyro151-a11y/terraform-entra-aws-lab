variable "ssh_public_key" {
  type        = string
  description = "The raw public cryptographic string used to clear the instance login gate"
}

variable "aws_region" {
  type        = string
  description = "The target AWS Region for all deployment landing zones"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment naming token used for resource tagging tracking"
  default     = "sandbox"
}

variable "vpc_cidr" {
  type        = string
  description = "The primary IP routing block allocated for the core VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block allocation for the public subnet zone"
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  type        = string
  description = "CIDR block allocation for private subnet A (Compute/ECS)"
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  type        = string
  description = "CIDR block allocation for private subnet B (High-Availability Database)"
  default     = "10.0.3.0/24"
}

variable "db_instance_class" {
  type        = string
  description = "Compute hardware tier sizing allocation for the managed RDS engine"
  default     = "db.t4g.micro"
}

variable "instance_type" {
  type        = string
  description = "The virtual hardware sizing allocation for baseline compute EC2 instances"
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "The target Amazon Machine Image (AMI) ID used to boot virtual machine nodes"
  default     = "ami-0f3f80eef773db04e" # Baseline Ubuntu/AL2 depending on your region template
}

variable "admin_ssh_cidr" {
  type        = string
  description = "The specific public IP or corporate CIDR block allowed to initiate SSH administrative connections"
}