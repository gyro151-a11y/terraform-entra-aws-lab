# Local Development Automation Control Panel

.PHONY: init validate build

# Initialize both Terraform and Packer working plugins
init:
	packer init ubuntu.pkr.hcl
	terraform init

# Validate that your code formatting and syntax contain zero errors
validate:
	packer validate ubuntu.pkr.hcl
	terraform validate

# Plan and preview what changes Terraform will make to your AWS account
plan:
	terraform plan

# Deploy the entire live production infrastructure stack to AWS
deploy:
	terraform apply -auto-approve

# Execute the actual image baking pipeline in the cloud
build:
	packer init ubuntu.pkr.hcl
	packer build ubuntu.pkr.hcl

# Completely destroy all deployed cloud resources to protect your budget
destroy:
	terraform destroy -auto-approve