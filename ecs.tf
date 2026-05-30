# ==========================================
# 1. THE CORE CONTAINER MANAGEMENT CLUSTER
# ==========================================
resource "aws_ecs_cluster" "lab_cluster" {
  name = "devops-lab-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Enables enterprise performance metrics tracking
  }
}

# ==========================================
# 2. IAM EXECUTION ROLES (Security Gates)
# ==========================================
# Role that allows the ECS engine to pull images and push logs to CloudWatch
resource "aws_iam_role" "ecs_execution_role" {
  name = "devops-lab-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

# Attach the standard AWS policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom inline policy allowing our container to read your specific SSM Parameter Store secret
resource "aws_iam_role_policy" "ecs_ssm_policy" {
  name = "devops-lab-ecs-ssm-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue"
        ]
        # Restrict access strictly to our lab's parameter hierarchy
        Resource = "arn:aws:ssm:*:*:parameter/devops-lab/*"
      }
    ]
  })
}

# ==========================================
# 3. THE TASK DEFINITION (The App Blueprint)
# ==========================================
resource "aws_ecs_task_definition" "app_task" {
  family                   = "devops-lab-app"
  network_mode             = "awsvpc" # Required for Fargate (gives every pod its own unique network interface)
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU (cost-effective)
  memory                   = "512" # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "spatula-web-app"
      image     = "nginx:alpine" # Bootstrapping a clean, stateless web engine proxy
      essential = true
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      # Dynamic Runtime Secret Ingestion! 
      # Maps the SSM token string directly into an internal OS Environment Variable inside the container
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = data.aws_ssm_parameter.external_api_token.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/devops-lab-app"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

# CloudWatch Log Group to capture standard out stream from our stateless container
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/devops-lab-app"
  retention_in_days = 3 # Automatically purges logs to keep storage costs zeroed out
}

# ==========================================
# 4. THE SERVICE ENGINE (The Orchestrator)
# ==========================================
resource "aws_ecs_service" "app_service" {
  name            = "devops-lab-service"
  cluster         = aws_ecs_cluster.lab_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1 # Keep exactly 1 copy alive. Kubernetes style self-healing.
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_subnet.id]
    security_groups = [aws_security_group.web_sg.id] # Shares firewall policies with web tier
    assign_public_ip = false # Pinned strictly in our isolated room away from the internet
  }
}