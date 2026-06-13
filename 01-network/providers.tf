terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Route state files to remote cloud storage
  backend "s3" {
    bucket       = "jeff-edgar-devops-lab-state"
    key          = "state/network.tfstate" # The file directory path inside the bucket
    region       = "us-east-1"
    encrypt      = true # Encrypts the state file at rest
    use_lockfile = true
  }
}



## Configure the AWS Provider targeting your development region
provider "aws" {
  region = "us-east-1"
}