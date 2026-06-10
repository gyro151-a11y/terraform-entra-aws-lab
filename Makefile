# ==============================================================================
# LOCAL DEVELOPMENT AUTOMATION CONTROL PANEL
# ==============================================================================

.PHONY: init validate plan lint deploy build destroy ecs-list ecs-kill

# Initialize both Terraform and Packer working plugins
init:
	packer init ubuntu.pkr.hcl
	cd core-identity && terraform init
	cd app-sandbox && terraform init

# Validate that your code formatting and syntax contain zero errors
validate:
	packer validate ubuntu.pkr.hcl
	cd core-identity && terraform validate
	cd app-sandbox && terraform validate

# Plan and preview what changes Terraform will make to your AWS account
plan-identity:
	cd core-identity && terraform plan -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

plan-app:
	cd app-sandbox && terraform plan -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

# Run static application security testing (SAST) compliance scans
lint:
	@echo "=== Running Trivy Security Linting ==="
	trivy config .

# Deploy the entire live production infrastructure stack to AWS
deploy-identity:
	cd core-identity && terraform apply -auto-approve -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

deploy-app:
	@echo "⚖️ Step 1: Deploying Ingress Tier via CloudFormation..."
	aws cloudformation deploy \
	  --template-file alb.yaml \
	  --stack-name devops-lab-alb-tier \
	  --region us-east-1
	@echo "🔄 Step 2: Running Syntax Standardization & Verification..."
	cd app-sandbox && terraform fmt
	cd app-sandbox && terraform validate
	@echo "🚀 Step 3: Provisioning Core Infrastructure Layers..."
	cd app-sandbox && terraform apply -auto-approve -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)"

# Execute the actual image baking pipeline in the cloud
build:
	packer init ubuntu.pkr.hcl
	packer build ubuntu.pkr.hcl

# Completely destroy all deployed cloud resources to protect your budget
destroy-app:
	@echo "🔓 Phase 1: Disabling Database Deletion Protection in the cloud..."
	cd app-sandbox && terraform apply \
	  -target=aws_db_instance.postgres_db \
	  -var="allow_db_destruction=true" \
	  -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)" \
	  --auto-approve

	@echo "🛑 Phase 2: Initiating Full Infrastructure Teardown..."
	cd app-sandbox && terraform destroy \
	  -var="allow_db_destruction=true" \
	  -var="ssh_public_key=$$(cat ~/.ssh/devops_lab_key.pub)" \
	  --auto-approve
	
	@echo "🧹 Phase 3: Cleaning up CloudFormation Ingress Tier..."
	aws cloudformation delete-stack --stack-name devops-lab-alb-tier --region us-east-1
	
	@echo "✅ All clean! The entire environment has been safely zeroed out."

# Chaos Engineering: View running compute tasks
ecs-list:
	aws ecs list-tasks --cluster devops-lab-ecs-cluster --region us-east-1

# Chaos Engineering: Kill a specific running task (Usage: make ecs-kill task=ID)
ecs-kill:
	aws ecs stop-task --cluster devops-lab-ecs-cluster --task $(task) --reason "Simulated crash" --region us-east-1