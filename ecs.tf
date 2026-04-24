# IAM角色（让ECS可以拉取ECR镜像和写CloudWatch日志）
resource "aws_iam_role" "ecs_task_execution"{
    name = "${var.app_name}-ecs-execution-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "ecs-tasks.amazonaws.com"
        }
    }]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM读取权限（让ECS可以读取Parameter Store里的密钥）
resource "aws_iam_role_policy" "ecs_ssm"{
    name = "${var.app_name}-ecs-ssm-policy"
    role = aws_iam_role.ecs_task_execution.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "ssm:GetParameters",
                "ssm:GetParameter"
            ]
            Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.app_name}/*"
        }]
    })
}

# SSM Parameter Store存密钥
resource "aws_ssm_parameter" "db_url" {
  name  = "/${var.app_name}/db-url"
  type  = "SecureString"
  value = "jdbc:mysql://${aws_db_instance.mysql.endpoint}/${aws_db_instance.mysql.db_name}"
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.app_name}/db-username"
  type  = "SecureString"
  value = aws_db_instance.mysql.username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.app_name}/db-password"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "stripe_secret_key" {
  name  = "/${var.app_name}/stripe-secret-key"
  type  = "SecureString"
  value = var.stripe_secret_key
}

resource "aws_ssm_parameter" "stripe_webhook_secret" {
  name  = "/${var.app_name}/stripe-webhook-secret"
  type  = "SecureString"
  value = var.stripe_webhook_secret
}

# ECS集群
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# CloudWatch日志组
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.app_name}-backend"
  retention_in_days = 30
}


#ECS Task Definition
resource "aws_ecs_task_definition" "backend" {
    family = "${var.app_name}-backend"
    requires_compatibilities = ["FARGATE"]
    network_mode = "awsvpc"
    cpu = 512
    memory = 1024
    execution_role_arn = aws_iam_role.ecs_task_execution.arn
    task_role_arn      = aws_iam_role.ecs_task_role.arn 

    container_definitions = jsonencode([{
        name = "backend"
        image = "${aws_ecr_repository.backend.repository_url}:latest"

        portMappings = [{
            containerPort = 8080
            protocol = "tcp"
        }]

        environment = [
            { name = "SPRING_PROFILES_ACTIVE", value = "prod" }
        ]

        secrets = [
            { name = "DB_URL",           valueFrom = aws_ssm_parameter.db_url.arn },
            { name = "DB_USERNAME",             valueFrom = aws_ssm_parameter.db_username.arn },
            { name = "DB_PASSWORD",             valueFrom = aws_ssm_parameter.db_password.arn },
            { name = "STRIPE_SECRET_KEY",       valueFrom = aws_ssm_parameter.stripe_secret_key.arn },
            { name = "STRIPE_WEBHOOK_SECRET",   valueFrom = aws_ssm_parameter.stripe_webhook_secret.arn }
        ]

        logConfiguration = {
            logDriver = "awslogs"
            options = {
            "awslogs-group"         = aws_cloudwatch_log_group.backend.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "ecs"
            }
        }

        healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 60
        }
    }])
}

# ECS Service
resource "aws_ecs_service" "backend" {
  name            = "${var.app_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # network_configuration {
  #   subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  #   security_groups  = [aws_security_group.ecs.id]
  #   assign_public_ip = false
  # }

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
  
  depends_on = [aws_lb_listener.https]
}


# Task Role（容器运行时调用AWS服务用）
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_ses" {
  name = "${var.app_name}-ecs-ses-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = "*"
    }]
  })
}

