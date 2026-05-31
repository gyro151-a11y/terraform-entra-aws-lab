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
	terraform plan -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

# Run static application security testing (SAST) compliance scans
lint:
	@echo "=== Running Trivy Security Linting ==="
	trivy config .

# Deploy the entire live production infrastructure stack to AWS
deploy:
	terraform fmt
	terraform validate
	terraform apply -auto-approve -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

# Execute the actual image baking pipeline in the cloud
build:
	packer init ubuntu.pkr.hcl
	packer build ubuntu.pkr.hcl

# Completely destroy all deployed cloud resources to protect your budget
destroy:
	terraform destroy -auto-approve -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

# Chaos engineering test to view running tasks
ecs-list:
	aws ecs list-tasks --cluster devops-lab-ecs-cluster --region us-east-1

# Chaos engineering test to kill a specific task (Usage: make ecs-kill task=ID)
ecs-kill:
	aws ecs stop-task --cluster devops-lab-ecs-cluster --task $(task) --reason "Simulated crash" --region us-east-1