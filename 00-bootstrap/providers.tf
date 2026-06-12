terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # 🔒 STAYS LOCAL: This tracks the bootstrap state right inside this directory
  backend "local" {}
}

provider "aws" {
  region = "us-east-1"
}