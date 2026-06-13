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
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
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
    subnets          = [data.aws_ssm_parameter.private_subnet_1.value]
    security_groups  = [data.aws_ssm_parameter.web_sg_id.value]
    assign_public_ip = false # Pinned strictly in our isolated room away from the internet
  }


  # Automatically wire the container ENI straight to the ALB target loop
  load_balancer {
    # Dynamically inject the target group ARN extracted from your CloudFormation Outputs
    target_group_arn = data.aws_cloudformation_stack.alb_tier.outputs["ALBTargetGroupARN"]
    container_name   = "spatula-web-app"
    container_port   = 80
  }
}

# 🎯 1. Define the Scaling Target (The Guardrails)
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.lab_cluster.name}/${aws_ecs_service.app_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 📈 2. Define the Scaling Policy (The Brains)
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 50.0 # 🎯 Target 50% average CPU utilization
    scale_in_cooldown  = 60   # ⏳ Wait 60 seconds before scaling down
    scale_out_cooldown = 60   # ⚡ Scale up aggressively (60 seconds)
  }
}