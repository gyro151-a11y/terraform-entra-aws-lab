packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# 1. Define where to build the image (AWS)
source "amazon-ebs" "ubuntu-baseline" {
  ami_name      = "devops-lab-ubuntu-golden-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  instance_type = "t3.micro"
  region        = "us-east-1" # Ensure this matches your AWS console region

  # Find the latest official Ubuntu 22.04 Minimal image dynamically
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Official Canonical Owner ID
  }
  
  ssh_username = "ubuntu"
}

# 2. Define what actions to run on the machine while it's live
build {
  name    = "aws-golden-image"
  sources = ["source.amazon-ebs.ubuntu-baseline"]

  # Run our local script inside the temporary AWS instance
  provisioner "shell" {
    # This environment flag tells apt/debconf to stay completely silent
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "./scripts/setup.sh"
  }
}