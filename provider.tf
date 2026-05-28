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
    bucket         = "devops-lab-state-bucket-629897139637"
    key            = "global/s3/terraform.tfstate" # The file directory path inside the bucket
    region         = "us-east-1"
    # dynamodb_table = "devops-lab-state-locks"       # Activates concurrent execution locking
    encrypt        = true                           # Encrypts the state file at rest
  }
}



## Configure the AWS Provider targeting your development region
provider "aws" {
  region = "us-east-1"
}