resource "aws_ecs_cluster" "whisper_app_cluster" {
  name = "whisper-app-cluster"
}

resource "aws_ecs_service" "whisper_app_service" {
  name                               = "whisper-service"
  cluster                            = aws_ecs_cluster.whisper_app_cluster.id
  task_definition                    = aws_ecs_task_definition.whisper_app_task.arn
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = var.ecs_task_deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.ecs_task_deployment_maximum_percent
  desired_count                      = var.ecs_task_desired_count


  network_configuration {
    security_groups  = [aws_security_group.whisper_app_sg.id]
    subnets          = [aws_subnet.whisper_subnet_1.id, aws_subnet.whisper_subnet_2.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_cloudwatch_log_group" "whisper_log_group" {
  name = "whisper-log-group"

  // Optional: Specify the number of days you want to retain log events in the log group.
  retention_in_days = 30

}


resource "aws_ecs_task_definition" "whisper_app_task" {
  family                   = "whiper-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_units
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_iam_role.arn

  # volume {
  #   name = "efs-volume"

  #   efs_volume_configuration {
  #     file_system_id     = aws_efs_file_system.whisper_efs.id
  #     transit_encryption = "ENABLED"
  #     authorization_config {
  #       access_point_id = aws_efs_access_point.whisper_efs_access_point.id
  #       iam             = "ENABLED"
  #     }
  #   }
  # }

  container_definitions = jsonencode([
    {
      name  = "whisper-app",
      image = "${var.ecr_repository_url}:${var.ecr_repository_tag}",
      # essential = true, # check passed health check is important
      environment = [
        { "name" : "HF_HOME", "value" : "/tmp/.cache/huggingface" }
      ]
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "whisper-log-group",
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "wkhisper-log-stream"
        }
      }
    }
  ])
}

resource "aws_security_group" "whisper_app_sg" {
  name        = "whisper-app-sg"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.whisper_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

