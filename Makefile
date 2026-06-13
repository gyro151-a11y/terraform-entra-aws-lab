# ==============================================================================
# LOCAL DEVELOPMENT AUTOMATION CONTROL PANEL
# ==============================================================================

.PHONY: init validate plan lint deploy build destroy ecs-list ecs-kill


VARS_FLAG = -var="admin_ssh_cidr=$$$$((curl -s http://checkip.amazonaws.com))/32" -var="ssh_public_key=\$$(cat ~/.ssh/devops_lab_key.pub)"
DESTROY_VARS = -var="allow_db_destruction=true" -var="ssh_public_key=\$$(cat ~/.ssh/devops_lab_key.pub)"

# Initialize both Terraform and Packer working plugins
init:
#	packer init ubuntu.pkr.hcl
	cd 00-bootstrap && terraform init
	cd 01-network && terraform init
	cd 03-application && terraform init

# Validate that your code formatting and syntax contain zero errors
validate-all:
#	packer validate ubuntu.pkr.hcl
	cd 01-network && terraform validate
	cd 03-application && terraform validate

	# Runs formatting command against all tf files
format-all:
	cd 01-network && terraform fmt -check
	cd 03-application && terraform fmt -check


# Run static application security testing (SAST) compliance scans
lint:
	@echo "=== Running Trivy Security Linting ==="
	trivy config .

show-alb-status:
	aws cloudformation describe-stacks \
		--stack-name devops-lab-alb-tier \
  		--region us-east-1 \
  		--query "Stacks[0].StackStatus"

show-alb-log:
	aws cloudformation describe-stack-events \
  		--stack-name devops-lab-alb-tier \
  		--region us-east-1 \
 		--query "StackEvents[?ResourceStatus=='CREATE_FAILED'].{Resource:LogicalResourceId,Type:ResourceType,Reason:ResourceStatusReason}" \
  		--output table

deploy-all:
	@echo "🌐 Phase 1: Deploying Network Foundation and Base Firewalls..."
	cd 01-network && terraform init -reconfigure && terraform apply $(VARS_FLAG) --auto-approve

	@if aws cloudformation describe-stacks --stack-name devops-lab-alb-tier --region us-east-1 >/dev/null 2>&1; then \
		echo "ℹ️ CloudFormation stack 'devops-lab-alb-tier' already exists. Skipping creation."; \
	else \
		echo "🚀 Stack not found. Provisioning CloudFormation Ingress Tier..."; \
		aws cloudformation create-stack \
		  --stack-name devops-lab-alb-tier \
		  --template-body file://02-ingress/alb.yaml \
		  --region us-east-1; \
		echo "⏳ Waiting for Application Load Balancer to finish provisioning..."; \
		aws cloudformation wait stack-create-complete --stack-name devops-lab-alb-tier --region us-east-1; \
	fi

	@echo "🚀 Phase 3: Launching Decoupled Application and Database Tiers..."
	cd 03-application && terraform init -reconfigure && terraform apply $(VARS_FLAG) --auto-approve
	@echo "✅ Deployment completely finalized! Your sandbox is live."

# Execute the actual image baking pipeline in the cloud
# build:
#	packer init ubuntu.pkr.hcl
#	packer build ubuntu.pkr.hcl

# Completely destroy all deployed cloud resources to protect your budget
destroy-all:
	@echo "🔓 Phase 1: Disabling Database Deletion Protection..."
	@if aws rds describe-db-instances --db-instance-identifier devops-lab-postgres --region us-east-1 >/dev/null 2>&1; then \
		cd 03-application && terraform init -reconfigure && terraform apply -target=aws_db_instance.postgres_db -var="allow_db_destruction=true" -var-file="../terraform.tfvars" --auto-approve; \
	fi

	@echo "🛑 Phase 2: Sweeping Application Resources (While Ingress Still Exists)..."
	cd 03-application && terraform init -reconfigure && terraform destroy $(DESTROY_VARS) --auto-approve

	@echo "🧹 Phase 3: Terminating CloudFormation Ingress Tier..."
	-aws cloudformation delete-stack --stack-name devops-lab-alb-tier --region us-east-1
	@echo "⏳ Waiting for Ingress resources to fully detach from network fabric..."
	aws cloudformation wait stack-delete-complete --stack-name devops-lab-alb-tier --region us-east-1

	@echo "📉 Phase 4: Sweeping Core Network Ring..."
	cd 01-network && terraform init -reconfigure && terraform destroy $(DESTROY_VARS) --auto-approve
	@echo "✅ Account completely zeroed out!"

	@echo "=== CHECKING ACTIVE VPCS ==="
	aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=devops-lab-vpc" --query "Vpcs[].VpcId" --output table

	@echo "=== CHECKING SYSTEMS MANAGER (SSM) PARAMETERS ==="
	aws ssm describe-parameters --region us-east-1 --query "Parameters[?starts_with(Name, '/devops-lab/')].Name" --output table


# Chaos Engineering: View running compute tasks
ecs-list:
	aws ecs list-tasks --cluster devops-lab-ecs-cluster --region us-east-1

# Chaos Engineering: Kill a specific running task (Usage: make ecs-kill task=ID)
ecs-kill:
	aws ecs stop-task --cluster devops-lab-ecs-cluster --task $(task) --reason "Simulated crash" --region us-east-1